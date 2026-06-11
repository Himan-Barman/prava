import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";

import { requireAuth } from "../../lib/auth.js";
import { query, queryMany, queryOne, withTransaction } from "../../lib/pg.js";
import {
  HttpError,
  ensure,
  generateId,
  generateOtpCode,
  generateRefreshToken,
  getRefreshTtlSeconds,
  hashPassword,
  isValidEmail,
  isValidPassword,
  isValidUsername,
  issueAccessToken,
  normalizeEmail,
  normalizeUsername,
  now,
  sha256,
  toIso,
  verifyPassword,
} from "../../lib/security.js";
import { bridgeToLegacy } from "../../shared/http/legacy-bridge.js";
import { registerApiV1Envelope } from "../../shared/http/envelope.js";
import { enqueueOutboxEvent } from "../../shared/outbox/index.js";
import { canFollow, canModerate, canViewPost, canViewProfile } from "../../shared/policies/index.js";

type BridgeRoute = {
  method: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  path: string;
  legacyPath: string | ((request: FastifyRequest) => string);
  legacyMethod?: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  payload?: (request: FastifyRequest) => unknown;
  query?: (request: FastifyRequest) => Record<string, unknown>;
};

function param(request: FastifyRequest, key: string): string {
  return String((request.params as Record<string, unknown> | undefined)?.[key] || "").trim();
}

function body(request: FastifyRequest): Record<string, unknown> {
  return (request.body && typeof request.body === "object" ? request.body : {}) as Record<string, unknown>;
}

function queryParams(request: FastifyRequest): Record<string, unknown> {
  return (request.query && typeof request.query === "object" ? request.query : {}) as Record<string, unknown>;
}

function addSeconds(date: Date, seconds: number): Date {
  return new Date(date.getTime() + seconds * 1000);
}

function addMinutes(date: Date, minutes: number): Date {
  return new Date(date.getTime() + minutes * 60 * 1000);
}

function sanitizeDevice(value: unknown): string {
  return String(value || "").trim().slice(0, 128) || "unknown-device";
}

function normalizePostBody(value: unknown): string {
  const text = String(value || "").replace(/\s+\n/g, "\n").replace(/\n{3,}/g, "\n\n").trim();
  ensure(text.length > 0 && text.length <= 1600, 400, "Invalid post body");
  return text;
}

function extractTokens(text: string, marker: "@" | "#"): string[] {
  const pattern = marker === "@"
    ? /(?:^|\s)@([a-zA-Z0-9_.]{2,32})/g
    : /(?:^|\s)#([a-zA-Z0-9_]{2,32})/g;
  return [...new Set([...text.matchAll(pattern)].map((match) => String(match[1] || "").toLowerCase()))];
}

async function resolveUserByHandleOrId(value: string): Promise<any> {
  const normalized = normalizeUsername(value.replace(/^@/, ""));
  return queryOne(
    `SELECT *
     FROM users
     WHERE deleted_at IS NULL
       AND (user_id = $1 OR username_lower = $2 OR handle_normalized = $2)
     LIMIT 1`,
    [value, normalized]
  );
}

async function resolveUserUuid(userId: string): Promise<string | null> {
  let row = await queryOne(`SELECT id::text AS id FROM users WHERE user_id = $1`, [userId]);
  if (!row) {
    return null;
  }
  if (!row.id) {
    const nextId = generateId();
    row = await queryOne(
      `UPDATE users
       SET id = $2
       WHERE user_id = $1 AND id IS NULL
       RETURNING id::text AS id`,
      [userId, nextId]
    );
    if (!row) {
      row = await queryOne(`SELECT id::text AS id FROM users WHERE user_id = $1`, [userId]);
    }
  }
  return row?.id || null;
}

async function resolvePostUuid(postId: string): Promise<string | null> {
  let row = await queryOne(`SELECT id::text AS id FROM posts WHERE post_id = $1`, [postId]);
  if (!row) {
    return null;
  }
  if (!row.id) {
    const nextId = generateId();
    row = await queryOne(
      `UPDATE posts
       SET id = $2
       WHERE post_id = $1 AND id IS NULL
       RETURNING id::text AS id`,
      [postId, nextId]
    );
    if (!row) {
      row = await queryOne(`SELECT id::text AS id FROM posts WHERE post_id = $1`, [postId]);
    }
  }
  return row?.id || null;
}

async function loadV1UserByIdentifier(identifier: string): Promise<any> {
  const normalized = normalizeEmail(identifier);
  let user: any | null = null;
  if (normalized.includes("@")) {
    user = await queryOne(
      `SELECT *, id::text AS id
       FROM users
       WHERE email_lower = $1
       LIMIT 1`,
      [normalized]
    );
    if (!user) {
      const email = await queryOne<{ user_id: string }>(
        `SELECT user_id::text AS user_id
         FROM user_emails
         WHERE email_normalized = $1 AND deleted_at IS NULL
         ORDER BY is_primary DESC, created_at DESC
         LIMIT 1`,
        [normalized]
      );
      if (email?.user_id) {
        user = await queryOne(
          `SELECT *, id::text AS id
           FROM users
           WHERE id = $1
           LIMIT 1`,
          [email.user_id]
        );
      }
    }
  } else {
    const handle = normalizeUsername(identifier);
    user = await queryOne(
      `SELECT *, id::text AS id
       FROM users
       WHERE username_lower = $1 OR handle_normalized = $1
       LIMIT 1`,
      [handle]
    );
  }

  if (!user?.id) {
    return user;
  }

  const credential = await queryOne<{ password_hash: string }>(
    `SELECT password_hash FROM user_credentials WHERE user_id = $1 LIMIT 1`,
    [user.id]
  );
  return {
    ...user,
    credential_password_hash: credential?.password_hash,
  };
}

async function createAuthChallenge(
  userUuid: string,
  target: string,
  purpose: string,
  ttlMinutes: number,
  client?: { query: (text: string, params?: unknown[]) => Promise<any> }
): Promise<{ code: string; expiresAt: Date }> {
  const code = generateOtpCode();
  const expiresAt = addMinutes(now(), ttlMinutes);
  const runner = client || { query };
  await runner.query(
    `INSERT INTO auth_challenges (
       id, user_id, channel, target, purpose, code_hash,
       attempts, max_attempts, expires_at, created_at
     )
     VALUES ($1, $2, 'email', $3, $4, $5, 0, 5, $6, NOW())`,
    [generateId(), userUuid, target, purpose, sha256(code), expiresAt]
  );
  return { code, expiresAt };
}

async function createV1Session(
  user: any,
  context: { deviceId?: unknown; deviceName?: unknown; platform?: unknown; ipAddress?: string; userAgent?: string }
): Promise<{ accessToken: string; refreshToken: string; sessionId: string; expiresAt: Date }> {
  const userUuid = await resolveUserUuid(user.user_id);
  if (!userUuid) throw new HttpError(404, "User not found");

  const deviceFingerprint = sanitizeDevice(context.deviceId);
  const sessionId = generateId();
  const refreshId = generateId();
  const refreshToken = generateRefreshToken();
  const issuedAt = now();
  const expiresAt = addSeconds(issuedAt, getRefreshTtlSeconds());

  await withTransaction(async (client) => {
    let device = await client.query(
      `SELECT id
       FROM user_devices
       WHERE user_id = $1 AND device_fingerprint = $2 AND revoked_at IS NULL
       LIMIT 1`,
      [userUuid, deviceFingerprint]
    );
    if ((device.rowCount || 0) > 0) {
      device = await client.query(
        `UPDATE user_devices
         SET last_seen_at = $3,
             platform = $4,
             device_name = $5,
             updated_at = $3
         WHERE id = $1 AND user_id = $2
         RETURNING id`,
        [
          device.rows[0]?.id,
          userUuid,
          issuedAt,
          sanitizeDevice(context.platform),
          sanitizeDevice(context.deviceName),
        ]
      );
    } else {
      device = await client.query(
        `INSERT INTO user_devices (
           id, user_id, device_fingerprint, platform, device_name, last_seen_at, created_at, updated_at
         )
         VALUES ($1, $2, $3, $4, $5, $6, $6, $6)
         RETURNING id`,
      [
        generateId(),
        userUuid,
        deviceFingerprint,
        sanitizeDevice(context.platform),
        sanitizeDevice(context.deviceName),
        issuedAt,
      ]
      );
    }

    await client.query(
      `INSERT INTO auth_sessions (
         id, user_id, device_id, session_token_hash, ip_address, user_agent,
         created_at, expires_at, last_seen_at, last_used_at, session_family_id
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $7, $7, $1)`,
      [
        sessionId,
        userUuid,
        device.rows[0]?.id || null,
        sha256(`${sessionId}:${refreshToken.raw}`),
        context.ipAddress || null,
        context.userAgent || "",
        issuedAt,
        expiresAt,
      ]
    );

    await client.query(
      `INSERT INTO auth_refresh_tokens (
         id, session_id, token_hash, created_at, issued_at, expires_at
       )
       VALUES ($1, $2, $3, $4, $4, $5)`,
      [refreshId, sessionId, refreshToken.hash, issuedAt, expiresAt]
    );

    await client.query(
      `UPDATE users SET last_seen_at = $2, updated_at = $2 WHERE user_id = $1`,
      [user.user_id, issuedAt]
    );
  });

  return {
    accessToken: issueAccessToken({
      userId: user.user_id,
      email: user.email,
      username: user.username,
      displayName: user.display_name,
      isVerified: user.is_verified === true,
      sessionId,
      role: user.role || "user",
    }),
    refreshToken: refreshToken.raw,
    sessionId,
    expiresAt,
  };
}

async function revokeSessionFamily(sessionId: string): Promise<void> {
  const session = await queryOne(
    `SELECT COALESCE(session_family_id, id)::text AS family_id
     FROM auth_sessions
     WHERE id = $1`,
    [sessionId]
  );
  if (!session?.family_id) return;
  await query(
    `UPDATE auth_sessions
     SET revoked_at = COALESCE(revoked_at, NOW()),
         revoke_reason = COALESCE(revoke_reason, 'refresh_reuse')
     WHERE id = $1 OR session_family_id = $1`,
    [session.family_id]
  );
}

async function mapPostRows(rows: any[], viewerId: string): Promise<any[]> {
  if (rows.length === 0) return [];
  const authorIds = [...new Set(rows.map((row) => row.author_id).filter(Boolean))];
  const postIds = rows.map((row) => row.post_id);
  const [authors, likes] = await Promise.all([
    queryMany(
      `SELECT user_id, username, display_name, avatar_url, is_verified
       FROM users
       WHERE user_id = ANY($1::text[])`,
      [authorIds]
    ),
    queryMany(
      `SELECT post_id FROM post_likes WHERE user_id = $1 AND post_id = ANY($2::text[])`,
      [viewerId, postIds]
    ),
  ]);
  const authorMap = new Map(authors.map((author) => [author.user_id, author]));
  const likedSet = new Set(likes.map((like) => like.post_id));
  return rows.map((post) => {
    const author = authorMap.get(post.author_id);
    return {
      id: post.post_id,
      body: post.body || "",
      createdAt: toIso(post.created_at),
      updatedAt: toIso(post.updated_at),
      likeCount: Number(post.like_count || 0),
      commentCount: Number(post.comment_count || 0),
      shareCount: Number(post.share_count || 0),
      readCount: Number(post.read_count || 0),
      liked: likedSet.has(post.post_id),
      mentions: Array.isArray(post.mentions) ? post.mentions : [],
      hashtags: Array.isArray(post.hashtags) ? post.hashtags : [],
      author: {
        id: author?.user_id || post.author_id,
        username: author?.username || "",
        displayName: author?.display_name || author?.username || "",
        avatarUrl: author?.avatar_url || "",
        isVerified: author?.is_verified === true,
      },
    };
  });
}

async function setPostLike(postId: string, userId: string, shouldLike: boolean): Promise<Record<string, unknown>> {
  const post = await queryOne(`SELECT post_id, author_id FROM posts WHERE post_id = $1 AND deleted_at IS NULL`, [postId]);
  if (!post) throw new HttpError(404, "Post not found");

  const allowed = await canViewPost(userId, postId);
  if (!allowed.allowed) throw new HttpError(403, "Post is not available");

  const ts = now();
  let changed = false;
  await withTransaction(async (client) => {
    if (shouldLike) {
      const existing = await client.query(
        `SELECT 1 FROM post_likes WHERE post_id = $1 AND user_id = $2 LIMIT 1`,
        [postId, userId]
      );
      changed = (existing.rowCount || 0) === 0;
      if (changed) {
        await client.query(
          `INSERT INTO post_likes (post_id, user_id, created_at)
           VALUES ($1, $2, $3)
           ON CONFLICT (post_id, user_id) DO NOTHING`,
        [postId, userId, ts]
      );
      }
    } else {
      const result = await client.query(
        `DELETE FROM post_likes WHERE post_id = $1 AND user_id = $2`,
        [postId, userId]
      );
      changed = (result.rowCount || 0) > 0;
    }

    await client.query(
      `UPDATE posts
       SET like_count = (SELECT COUNT(*)::int FROM post_likes WHERE post_id = $1),
           updated_at = $2
       WHERE post_id = $1`,
      [postId, ts]
    );

    const postUuid = await resolvePostUuid(postId);
    if (changed && postUuid) {
      await enqueueOutboxEvent({
        eventType: shouldLike ? "post.liked" : "post.unliked",
        aggregateType: "post",
        aggregateId: postUuid,
        payload: { postId, userId },
      }, client);
    }
  });

  const updated = await queryOne(`SELECT like_count FROM posts WHERE post_id = $1`, [postId]);
  return {
    postId,
    liked: shouldLike,
    changed,
    likeCount: Number(updated?.like_count || 0),
  };
}

async function setPostBookmark(postId: string, userId: string, shouldBookmark: boolean): Promise<Record<string, unknown>> {
  const [postUuid, userUuid] = await Promise.all([resolvePostUuid(postId), resolveUserUuid(userId)]);
  if (!postUuid || !userUuid) throw new HttpError(404, "Post not found");

  if (shouldBookmark) {
    await query(
      `INSERT INTO post_bookmarks (post_id, user_id, created_at)
       VALUES ($1, $2, NOW())
       ON CONFLICT (post_id, user_id) DO NOTHING`,
      [postUuid, userUuid]
    );
  } else {
    await query(`DELETE FROM post_bookmarks WHERE post_id = $1 AND user_id = $2`, [postUuid, userUuid]);
  }

  await enqueueOutboxEvent({
    eventType: shouldBookmark ? "post.bookmarked" : "post.unbookmarked",
    aggregateType: "post",
    aggregateId: postUuid,
    payload: { postId, userId },
  });

  return { postId, bookmarked: shouldBookmark };
}

async function syncFriendshipFromLegacyFollows(a: string, b: string): Promise<void> {
  const reciprocal = await queryMany(
    `SELECT follower_id, following_id
     FROM follows
     WHERE (follower_id = $1 AND following_id = $2)
        OR (follower_id = $2 AND following_id = $1)`,
    [a, b]
  );
  const aFollowsB = reciprocal.some((row) => row.follower_id === a && row.following_id === b);
  const bFollowsA = reciprocal.some((row) => row.follower_id === b && row.following_id === a);
  if (!aFollowsB || !bFollowsA) return;

  const [aUuid, bUuid] = await Promise.all([resolveUserUuid(a), resolveUserUuid(b)]);
  if (!aUuid || !bUuid) return;
  const low = [aUuid, bUuid].sort()[0];
  const high = [aUuid, bUuid].sort()[1];
  await query(
    `INSERT INTO friendships (
       requester_id, addressee_id, user_low_id, user_high_id,
       status, requested_at, responded_at, formed_at, created_at, updated_at
     )
     VALUES ($1, $2, $3, $4, 'accepted', NOW(), NOW(), NOW(), NOW(), NOW())
     ON CONFLICT (requester_id, addressee_id)
     DO UPDATE SET status = 'accepted', updated_at = NOW(), formed_at = COALESCE(friendships.formed_at, NOW())`,
    [aUuid, bUuid, low, high]
  );
}

async function registerFollow(userId: string, targetUserId: string): Promise<Record<string, unknown>> {
  const target = await queryOne(`SELECT user_id FROM users WHERE user_id = $1 AND deleted_at IS NULL`, [targetUserId]);
  if (!target) throw new HttpError(404, "User not found");
  const allowed = await canFollow(userId, targetUserId);
  if (!allowed.allowed) throw new HttpError(403, "Cannot follow this user");

  const result = await query(
    `INSERT INTO follows (follower_id, following_id, created_at)
     VALUES ($1, $2, NOW())
     ON CONFLICT (follower_id, following_id) DO NOTHING`,
    [userId, targetUserId]
  );
  await syncFriendshipFromLegacyFollows(userId, targetUserId);
  await enqueueOutboxEvent({
    eventType: "follow.accepted",
    aggregateType: "user",
    aggregateId: await resolveUserUuid(targetUserId),
    payload: { followerId: userId, followingId: targetUserId },
  });
  return { following: true, changed: (result.rowCount || 0) > 0 };
}

async function removeFollow(userId: string, targetUserId: string): Promise<Record<string, unknown>> {
  const result = await query(
    `DELETE FROM follows WHERE follower_id = $1 AND following_id = $2`,
    [userId, targetUserId]
  );
  const [aUuid, bUuid] = await Promise.all([resolveUserUuid(userId), resolveUserUuid(targetUserId)]);
  if (aUuid && bUuid) {
    await query(
      `UPDATE friendships
       SET status = 'removed', updated_at = NOW()
       WHERE (requester_id = $1 AND addressee_id = $2)
          OR (requester_id = $2 AND addressee_id = $1)
          OR (user_low_id = LEAST($1::uuid, $2::uuid) AND user_high_id = GREATEST($1::uuid, $2::uuid))`,
      [aUuid, bUuid]
    );
  }
  return { following: false, changed: (result.rowCount || 0) > 0 };
}

function addBridge(app: FastifyInstance, route: BridgeRoute): void {
  app.route({
    method: route.method,
    url: route.path,
    handler: async (request, reply) => bridgeToLegacy(app, request, reply, {
      method: route.legacyMethod || route.method,
      path: typeof route.legacyPath === "function" ? route.legacyPath(request) : route.legacyPath,
      payload: route.payload ? route.payload(request) : request.body,
      query: route.query ? route.query(request) : queryParams(request),
    }),
  });
}

export default async function apiV1Service(app: FastifyInstance): Promise<void> {
  registerApiV1Envelope(app);

  app.post("/auth/signup", async (request, reply) => {
    const input = body(request);
    const email = normalizeEmail(input.email);
    const handle = normalizeUsername(input.handle || input.username);
    const displayName = String(input.displayName || handle).trim().slice(0, 120);
    const password = String(input.password || "");
    const languageCode = String(input.languageCode || "en").trim().slice(0, 12);

    ensure(isValidEmail(email), 400, "Invalid email");
    ensure(isValidUsername(handle), 400, "Invalid handle");
    ensure(isValidPassword(password), 400, "Invalid password");
    ensure(displayName.length >= 1, 400, "Invalid display name");

    const existing = await queryOne(
      `SELECT user_id FROM users WHERE email_lower = $1 OR username_lower = $2 OR handle_normalized = $2 LIMIT 1`,
      [email, handle]
    );
    if (existing) {
      throw new HttpError(409, "Account already exists");
    }

    const passwordHash = hashPassword(password);
    const userId = generateId();
    const userUuid = generateId();
    const emailUuid = generateId();
    let devCode: string | undefined;
    const ts = now();

    await withTransaction(async (client) => {
      await client.query(
        `INSERT INTO users (
           user_id, id, email, email_lower, username, username_lower,
           handle, handle_normalized, display_name, display_name_lower,
           password_hash, is_verified, account_status, language_code,
           primary_email_id, created_at, updated_at
         )
         VALUES ($1, $2, $3, $3, $4, $4, $4, $4, $5, $6, $7, FALSE, 'pending_verification', $8, $9, $10, $10)`,
        [
          userId,
          userUuid,
          email,
          handle,
          displayName,
          displayName.toLowerCase(),
          passwordHash,
          languageCode,
          emailUuid,
          ts,
        ]
      );
      await client.query(
        `INSERT INTO user_emails (
           id, user_id, email, email_normalized, is_primary, is_verified, created_at, updated_at
         )
         VALUES ($1, $2, $3, $3, TRUE, FALSE, $4, $4)`,
        [emailUuid, userUuid, email, ts]
      );
      await client.query(
        `INSERT INTO user_profiles (user_id, profile_metadata, created_at, updated_at)
         VALUES ($1, $2, $3, $3)
         ON CONFLICT (user_id) DO NOTHING`,
        [userUuid, JSON.stringify({ languageCode }), ts]
      );
      await client.query(
        `INSERT INTO user_stats (user_id, updated_at)
         VALUES ($1, $2)
         ON CONFLICT (user_id) DO NOTHING`,
        [userUuid, ts]
      );
      await client.query(
        `INSERT INTO user_settings (user_id, settings, updated_at)
         VALUES ($1, $2, $3)
         ON CONFLICT (user_id) DO NOTHING`,
        [userId, JSON.stringify({ languageCode, pushNotifications: true }), ts]
      );
      await client.query(
        `INSERT INTO user_privacy_settings (user_id, updated_at)
         VALUES ($1, $2)
         ON CONFLICT (user_id) DO NOTHING`,
        [userUuid, ts]
      );
      await client.query(
        `INSERT INTO user_credentials (
           user_id, password_hash, password_algo, password_algorithm,
           password_updated_at, password_changed_at, created_at, updated_at
         )
         VALUES ($1, $2, 'argon2id', 'argon2id', $3, $3, $3, $3)`,
        [userUuid, passwordHash, ts]
      );
      await client.query(
        `INSERT INTO user_roles (user_id, role_id, granted_at)
         SELECT $1, id, $2::timestamptz
         FROM roles
         WHERE name = 'user'
         ON CONFLICT (user_id, role_id) DO NOTHING`,
        [userUuid, ts]
      );

      const challenge = await createAuthChallenge(userUuid, email, "email_verification", 10, client);
      devCode = challenge.code;
      await enqueueOutboxEvent({
        eventType: "auth.verification_email.requested",
        aggregateType: "user",
        aggregateId: userUuid,
        payload: { userId, email, code: challenge.code, challengeExpiresAt: challenge.expiresAt.toISOString() },
      }, client);
    });

    reply.code(201);
    return {
      verificationRequired: true,
      userId,
      email,
      handle,
      expiresIn: 600,
      ...((process.env.NODE_ENV || "development") !== "production" ? { devCode } : {}),
    };
  });

  app.post("/auth/verify-email", async (request) => {
    const input = body(request);
    const email = normalizeEmail(input.email);
    const code = String(input.code || input.otp || "").trim();
    ensure(isValidEmail(email), 400, "Invalid email");
    ensure(/^\d{6}$/.test(code), 400, "Invalid code");

    const challenge = await queryOne(
      `SELECT ac.*, u.user_id
       FROM auth_challenges ac
       JOIN users u ON u.id = ac.user_id
       WHERE ac.target = $1
         AND ac.purpose = 'email_verification'
         AND ac.consumed_at IS NULL
         AND ac.expires_at > NOW()
       ORDER BY ac.created_at DESC
       LIMIT 1`,
      [email]
    );
    if (!challenge) throw new HttpError(401, "Invalid or expired code");
    if (Number(challenge.attempts || 0) >= Number(challenge.max_attempts || 5)) {
      throw new HttpError(401, "Invalid or expired code");
    }

    if (sha256(code) !== challenge.code_hash) {
      await query(
        `UPDATE auth_challenges SET attempts = attempts + 1 WHERE id = $1`,
        [challenge.id]
      );
      throw new HttpError(401, "Invalid or expired code");
    }

    await withTransaction(async (client) => {
      await client.query(
        `UPDATE auth_challenges SET consumed_at = NOW() WHERE id = $1`,
        [challenge.id]
      );
      await client.query(
        `UPDATE user_emails
         SET is_verified = TRUE, verified_at = COALESCE(verified_at, NOW()), updated_at = NOW()
         WHERE user_id = $1 AND email_normalized = $2`,
        [challenge.user_id, email]
      );
      await client.query(
        `UPDATE users
         SET is_verified = TRUE,
             email_verified_at = COALESCE(email_verified_at, NOW()),
             account_status = 'active',
             updated_at = NOW()
         WHERE id = $1`,
        [challenge.user_id]
      );
      await client.query(
        `INSERT INTO security_events (user_id, event_type, metadata, created_at, occurred_at)
         VALUES ($1, 'email_verified', $2, NOW(), NOW())`,
        [challenge.user_id, JSON.stringify({ email })]
      );
    });

    return { verified: true };
  });

  app.post("/auth/resend-verification", async (request) => {
    const email = normalizeEmail(body(request).email);
    ensure(isValidEmail(email), 400, "Invalid email");
    const user = await loadV1UserByIdentifier(email);
    if (!user) {
      return { success: true };
    }
    const userUuid = await resolveUserUuid(user.user_id);
    if (!userUuid) {
      return { success: true };
    }
    const challenge = await createAuthChallenge(userUuid, email, "email_verification", 10);
    await enqueueOutboxEvent({
      eventType: "auth.verification_email.requested",
      aggregateType: "user",
      aggregateId: userUuid,
      payload: { userId: user.user_id, email, code: challenge.code, challengeExpiresAt: challenge.expiresAt.toISOString() },
    });
    return {
      success: true,
      expiresIn: 600,
      ...((process.env.NODE_ENV || "development") !== "production" ? { devCode: challenge.code } : {}),
    };
  });

  app.post("/auth/login", async (request) => {
    const input = body(request);
    const identifier = String(input.identifier || input.email || input.username || "").trim();
    const password = String(input.password || "");
    ensure(identifier.length >= 3, 400, "Invalid request");
    ensure(isValidPassword(password), 400, "Invalid request");

    const user = await loadV1UserByIdentifier(identifier);
    const passwordHash = user?.credential_password_hash || user?.password_hash;
    if (!user || !passwordHash || !verifyPassword(password, passwordHash)) {
      await query(
        `INSERT INTO auth_login_attempts (identifier, success, failure_reason, created_at, occurred_at)
         VALUES ($1, FALSE, 'invalid_credentials', NOW(), NOW())`,
        [identifier.toLowerCase()]
      ).catch(() => undefined);
      throw new HttpError(401, "Invalid credentials");
    }
    if (user.account_status && !["active", "pending_verification"].includes(user.account_status)) {
      throw new HttpError(403, "Account is not active");
    }

    await query(
      `INSERT INTO auth_login_attempts (identifier, user_id, success, created_at, occurred_at)
       VALUES ($1, $2, TRUE, NOW(), NOW())`,
      [identifier.toLowerCase(), user.id]
    ).catch(() => undefined);

    const session = await createV1Session(user, {
      deviceId: input.deviceId || request.headers["x-device-id"],
      deviceName: input.deviceName,
      platform: input.platform,
      ipAddress: request.ip,
      userAgent: request.headers["user-agent"],
    });
    return {
      user: {
        id: user.user_id,
        email: user.email,
        handle: user.handle || user.username,
        username: user.username,
        displayName: user.display_name || user.username,
        isVerified: user.is_verified === true,
      },
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      sessionId: session.sessionId,
      expiresAt: toIso(session.expiresAt),
    };
  });

  app.post("/auth/refresh", async (request) => {
    const rawToken = String(body(request).refreshToken || "").trim();
    ensure(rawToken.length >= 32, 400, "Invalid request");
    const tokenHash = sha256(rawToken);
    const token = await queryOne(
      `SELECT rt.*, s.user_id, s.id AS session_id, s.revoked_at AS session_revoked_at, u.user_id AS legacy_user_id, u.email, u.username, u.display_name, u.is_verified, u.role
       FROM auth_refresh_tokens rt
       JOIN auth_sessions s ON s.id = rt.session_id
       JOIN users u ON u.id = s.user_id
       WHERE rt.token_hash = $1
       LIMIT 1`,
      [tokenHash]
    );
    if (!token) throw new HttpError(401, "Invalid refresh token");
    if (token.consumed_at || token.revoked_at || token.session_revoked_at) {
      await revokeSessionFamily(token.session_id);
      await query(
        `INSERT INTO security_events (user_id, event_type, severity, metadata, created_at, occurred_at)
         VALUES ($1, 'refresh_reuse_detected', 'high', $2, NOW(), NOW())`,
        [token.user_id, JSON.stringify({ sessionId: token.session_id })]
      ).catch(() => undefined);
      throw new HttpError(401, "Reauthentication required");
    }
    if (new Date(token.expires_at).getTime() <= Date.now()) {
      throw new HttpError(401, "Refresh token expired");
    }

    const next = generateRefreshToken();
    const nextId = generateId();
    const expiresAt = addSeconds(now(), getRefreshTtlSeconds());
    await withTransaction(async (client) => {
      await client.query(
        `UPDATE auth_refresh_tokens
         SET consumed_at = NOW(), replaced_by_token_id = $2
         WHERE id = $1`,
        [token.id, nextId]
      );
      await client.query(
        `INSERT INTO auth_refresh_tokens (
           id, session_id, token_hash, parent_token_id, created_at, issued_at, expires_at
         )
         VALUES ($1, $2, $3, $4, NOW(), NOW(), $5)`,
        [nextId, token.session_id, next.hash, token.id, expiresAt]
      );
      await client.query(
        `UPDATE auth_sessions SET last_used_at = NOW(), last_seen_at = NOW() WHERE id = $1`,
        [token.session_id]
      );
    });

    return {
      accessToken: issueAccessToken({
        userId: token.legacy_user_id,
        email: token.email,
        username: token.username,
        displayName: token.display_name,
        isVerified: token.is_verified === true,
        sessionId: token.session_id,
        role: token.role || "user",
      }),
      refreshToken: next.raw,
      sessionId: token.session_id,
      expiresAt: toIso(expiresAt),
    };
  });

  app.post("/auth/logout", { preHandler: requireAuth }, async (request) => {
    const sessionId = request.user?.sessionId || String(body(request).sessionId || "").trim();
    if (sessionId) {
      await query(
        `UPDATE auth_sessions SET revoked_at = COALESCE(revoked_at, NOW()), revoke_reason = 'logout' WHERE id = $1 AND user_id = (SELECT id FROM users WHERE user_id = $2)`,
        [sessionId, request.user!.userId]
      );
    }
    return { loggedOut: true };
  });

  app.post("/auth/logout-all", { preHandler: requireAuth }, async (request) => {
    await query(
      `UPDATE auth_sessions
       SET revoked_at = COALESCE(revoked_at, NOW()), revoke_reason = 'logout_all'
       WHERE user_id = (SELECT id FROM users WHERE user_id = $1)`,
      [request.user!.userId]
    );
    return { loggedOut: true };
  });

  app.get("/auth/sessions", { preHandler: requireAuth }, async (request) => {
    const rows = await queryMany(
      `SELECT s.id, s.created_at, s.expires_at, s.last_seen_at, s.last_used_at, s.revoked_at,
              d.device_name, d.platform, d.device_fingerprint
       FROM auth_sessions s
       LEFT JOIN user_devices d ON d.id = s.device_id
       WHERE s.user_id = (SELECT id FROM users WHERE user_id = $1)
       ORDER BY s.created_at DESC
       LIMIT 100`,
      [request.user!.userId]
    );
    return {
      items: rows.map((row) => ({
        id: row.id,
        deviceName: row.device_name || "",
        platform: row.platform || "",
        deviceId: row.device_fingerprint || "",
        createdAt: toIso(row.created_at),
        lastSeenAt: toIso(row.last_seen_at || row.last_used_at),
        expiresAt: toIso(row.expires_at),
        revokedAt: toIso(row.revoked_at),
      })),
    };
  });

  app.post("/auth/password-reset/request", async (request) => {
    const email = normalizeEmail(body(request).email);
    ensure(isValidEmail(email), 400, "Invalid email");
    const user = await loadV1UserByIdentifier(email);
    if (!user) return { success: true };
    const userUuid = await resolveUserUuid(user.user_id);
    if (!userUuid) return { success: true };
    const challenge = await createAuthChallenge(userUuid, email, "password_reset", 10);
    await enqueueOutboxEvent({
      eventType: "auth.password_reset_email.requested",
      aggregateType: "user",
      aggregateId: userUuid,
      payload: { userId: user.user_id, email, code: challenge.code, challengeExpiresAt: challenge.expiresAt.toISOString() },
    });
    return {
      success: true,
      ...((process.env.NODE_ENV || "development") !== "production" ? { devToken: challenge.code } : {}),
    };
  });

  app.post("/auth/password-reset/confirm", async (request) => {
    const input = body(request);
    const email = normalizeEmail(input.email);
    const token = String(input.token || input.code || "").trim();
    const newPassword = String(input.newPassword || input.password || "");
    ensure(isValidEmail(email), 400, "Invalid request");
    ensure(/^\d{6}$/.test(token), 400, "Invalid request");
    ensure(isValidPassword(newPassword), 400, "Invalid request");
    const challenge = await queryOne(
      `SELECT *
       FROM auth_challenges
       WHERE target = $1
         AND purpose = 'password_reset'
         AND consumed_at IS NULL
         AND expires_at > NOW()
       ORDER BY created_at DESC
       LIMIT 1`,
      [email]
    );
    if (!challenge || sha256(token) !== challenge.code_hash) {
      throw new HttpError(401, "Invalid or expired code");
    }
    const passwordHash = hashPassword(newPassword);
    await withTransaction(async (client) => {
      await client.query(`UPDATE auth_challenges SET consumed_at = NOW() WHERE id = $1`, [challenge.id]);
      await client.query(
        `UPDATE user_credentials
         SET password_hash = $2,
             password_algo = 'argon2id',
             password_algorithm = 'argon2id',
             password_updated_at = NOW(),
             password_changed_at = NOW(),
             updated_at = NOW()
         WHERE user_id = $1`,
        [challenge.user_id, passwordHash]
      );
      await client.query(
        `UPDATE users SET password_hash = $2, updated_at = NOW() WHERE id = $1`,
        [challenge.user_id, passwordHash]
      );
      await client.query(
        `UPDATE auth_sessions SET revoked_at = COALESCE(revoked_at, NOW()), revoke_reason = 'password_reset' WHERE user_id = $1`,
        [challenge.user_id]
      );
    });
    return { success: true };
  });

  const bridges: BridgeRoute[] = [
    { method: "GET", path: "/me", legacyPath: "/api/users/me/account" },
    { method: "PATCH", path: "/me/profile", legacyMethod: "PUT", legacyPath: "/api/users/me/profile-details" },
    { method: "PATCH", path: "/me/handle", legacyMethod: "PUT", legacyPath: "/api/users/me/handle" },
    { method: "GET", path: "/me/follow-requests", legacyPath: "/api/users/me/connections" },
    { method: "GET", path: "/me/friends", legacyPath: "/api/users/me/connections" },
    { method: "GET", path: "/feed/following", legacyPath: "/api/feed/following" },
    { method: "GET", path: "/feed/for-you", legacyPath: "/api/feed/for-you" },
    { method: "POST", path: "/feed/events", legacyPath: "/api/feed/events" },
    { method: "POST", path: "/posts", legacyMethod: "POST", legacyPath: "/api/feed" },
    { method: "GET", path: "/posts/:postId", legacyPath: (request) => `/api/feed/${param(request, "postId")}` },
    { method: "POST", path: "/posts/:postId/replies", legacyMethod: "POST", legacyPath: (request) => `/api/feed/${param(request, "postId")}/comments` },
    { method: "GET", path: "/posts/:postId/replies", legacyPath: (request) => `/api/feed/${param(request, "postId")}/comments` },
    { method: "POST", path: "/posts/:postId/hide", legacyPath: (request) => `/api/feed/${param(request, "postId")}/hide` },
    { method: "POST", path: "/posts/:postId/not-interested", legacyPath: (request) => `/api/feed/${param(request, "postId")}/not-interested` },
    { method: "POST", path: "/conversations/direct", legacyMethod: "POST", legacyPath: "/api/conversations/dm", payload: (request) => ({ otherUserId: body(request).userId || body(request).otherUserId }) },
    { method: "POST", path: "/conversations/group", legacyMethod: "POST", legacyPath: "/api/conversations/group" },
    { method: "GET", path: "/conversations", legacyPath: "/api/conversations" },
    { method: "GET", path: "/conversations/:conversationId", legacyPath: (request) => `/api/conversations/${param(request, "conversationId")}` },
    { method: "PATCH", path: "/conversations/:conversationId", legacyPath: (request) => `/api/conversations/${param(request, "conversationId")}` },
    { method: "GET", path: "/conversations/:conversationId/messages", legacyPath: (request) => `/api/conversations/${param(request, "conversationId")}/messages` },
    { method: "POST", path: "/conversations/:conversationId/messages", legacyPath: (request) => `/api/conversations/${param(request, "conversationId")}/messages` },
    { method: "POST", path: "/conversations/:conversationId/read", legacyPath: (request) => `/api/conversations/${param(request, "conversationId")}/read` },
    { method: "POST", path: "/conversations/:conversationId/members", legacyPath: (request) => `/api/conversations/${param(request, "conversationId")}/members` },
    { method: "DELETE", path: "/conversations/:conversationId/members/:userId", legacyPath: (request) => `/api/conversations/${param(request, "conversationId")}/members/${param(request, "userId")}` },
    { method: "PATCH", path: "/conversations/:conversationId/members/:userId/role", legacyMethod: "POST", legacyPath: (request) => `/api/conversations/${param(request, "conversationId")}/admins`, payload: (request) => ({ userId: param(request, "userId"), role: body(request).role || "admin" }) },
    { method: "POST", path: "/conversations/:conversationId/leave", legacyPath: (request) => `/api/conversations/${param(request, "conversationId")}/leave` },
    { method: "GET", path: "/notifications", legacyPath: "/api/notifications" },
    { method: "POST", path: "/notifications/:notificationId/read", legacyPath: (request) => `/api/notifications/${param(request, "notificationId")}/read` },
    { method: "POST", path: "/notifications/read-all", legacyPath: "/api/notifications/read-all" },
    { method: "GET", path: "/search", legacyPath: "/api/users/smart-search", query: queryParams },
  ];

  for (const route of bridges) {
    addBridge(app, route);
  }

  app.delete("/auth/sessions/:sessionId", { preHandler: requireAuth }, async (request) => {
    const sessionId = param(request, "sessionId");
    ensure(sessionId.length >= 3, 400, "Invalid session");
    const result = await query(
      `UPDATE refresh_tokens
       SET revoked_at = NOW()
       WHERE refresh_token_id = $1 AND user_id = $2 AND revoked_at IS NULL`,
      [sessionId, request.user!.userId]
    );
    return { revoked: (result.rowCount || 0) > 0 };
  });

  app.get("/users/:handle", { preHandler: requireAuth }, async (request, reply) => {
    const target = await resolveUserByHandleOrId(param(request, "handle"));
    if (!target) throw new HttpError(404, "User not found");
    const allowed = await canViewProfile(request.user!.userId, target.user_id);
    if (!allowed.allowed) throw new HttpError(403, "Profile is not available");
    return bridgeToLegacy(app, request, reply, {
      method: "GET",
      path: `/api/users/${target.user_id}/profile`,
      query: queryParams(request),
    });
  });

  app.get("/users/:userId/posts", { preHandler: requireAuth }, async (request) => {
    const targetUserId = param(request, "userId");
    const allowed = await canViewProfile(request.user!.userId, targetUserId);
    if (!allowed.allowed) throw new HttpError(403, "Profile is not available");
    const rows = await queryMany(
      `SELECT *
       FROM posts
       WHERE author_id = $1 AND deleted_at IS NULL
       ORDER BY created_at DESC
       LIMIT 50`,
      [targetUserId]
    );
    return { items: await mapPostRows(rows, request.user!.userId) };
  });

  app.get("/users/:userId/replies", { preHandler: requireAuth }, async (request) => {
    const targetUserId = param(request, "userId");
    const rows = await queryMany(
      `SELECT c.*, p.post_id AS parent_post_id
       FROM comments c
       JOIN posts p ON p.post_id = c.post_id
       WHERE c.author_id = $1
       ORDER BY c.created_at DESC
       LIMIT 50`,
      [targetUserId]
    );
    return {
      items: rows.map((row) => ({
        id: row.comment_id,
        postId: row.parent_post_id,
        body: row.body,
        createdAt: toIso(row.created_at),
      })),
    };
  });

  app.get("/users/:userId/followers", { preHandler: requireAuth }, async (request, reply) => bridgeToLegacy(app, request, reply, {
    method: "GET",
    path: `/api/users/${param(request, "userId")}/connections`,
    query: { ...queryParams(request), type: "followers" },
  }));

  app.get("/users/:userId/following", { preHandler: requireAuth }, async (request, reply) => bridgeToLegacy(app, request, reply, {
    method: "GET",
    path: `/api/users/${param(request, "userId")}/connections`,
    query: { ...queryParams(request), type: "following" },
  }));

  app.post("/users/:userId/follow", { preHandler: requireAuth }, async (request) => registerFollow(request.user!.userId, param(request, "userId")));
  app.delete("/users/:userId/follow", { preHandler: requireAuth }, async (request) => removeFollow(request.user!.userId, param(request, "userId")));

  app.post("/follow-requests/:userId/accept", { preHandler: requireAuth }, async (request) => registerFollow(request.user!.userId, param(request, "userId")));
  app.post("/follow-requests/:userId/reject", { preHandler: requireAuth }, async () => ({ accepted: false }));

  app.post("/users/:userId/block", { preHandler: requireAuth }, async (request, reply) => bridgeToLegacy(app, request, reply, {
    method: "POST",
    path: `/api/users/${param(request, "userId")}/block`,
    payload: body(request),
  }));
  app.delete("/users/:userId/block", { preHandler: requireAuth }, async (request, reply) => bridgeToLegacy(app, request, reply, {
    method: "DELETE",
    path: `/api/users/${param(request, "userId")}/block`,
  }));
  app.post("/users/:userId/mute", { preHandler: requireAuth }, async (request, reply) => bridgeToLegacy(app, request, reply, {
    method: "POST",
    path: `/api/users/${param(request, "userId")}/mute`,
    payload: body(request),
  }));
  app.delete("/users/:userId/mute", { preHandler: requireAuth }, async (request, reply) => bridgeToLegacy(app, request, reply, {
    method: "DELETE",
    path: `/api/users/${param(request, "userId")}/mute`,
  }));

  app.delete("/posts/:postId", { preHandler: requireAuth }, async (request) => {
    const postId = param(request, "postId");
    const result = await query(
      `UPDATE posts
       SET deleted_at = NOW(), updated_at = NOW()
       WHERE post_id = $1 AND author_id = $2 AND deleted_at IS NULL`,
      [postId, request.user!.userId]
    );
    return { deleted: (result.rowCount || 0) > 0 };
  });

  app.post("/posts/:postId/likes", { preHandler: requireAuth }, async (request) => setPostLike(param(request, "postId"), request.user!.userId, true));
  app.delete("/posts/:postId/likes", { preHandler: requireAuth }, async (request) => setPostLike(param(request, "postId"), request.user!.userId, false));
  app.post("/posts/:postId/bookmarks", { preHandler: requireAuth }, async (request) => setPostBookmark(param(request, "postId"), request.user!.userId, true));
  app.delete("/posts/:postId/bookmarks", { preHandler: requireAuth }, async (request) => setPostBookmark(param(request, "postId"), request.user!.userId, false));

  app.get("/me/bookmarks", { preHandler: requireAuth }, async (request) => {
    const userUuid = await resolveUserUuid(request.user!.userId);
    if (!userUuid) return { items: [] };
    const rows = await queryMany(
      `SELECT p.*
       FROM post_bookmarks pb
       JOIN posts p ON p.id = pb.post_id
       WHERE pb.user_id = $1
       ORDER BY pb.created_at DESC
       LIMIT 50`,
      [userUuid]
    );
    return { items: await mapPostRows(rows, request.user!.userId) };
  });

  app.post("/posts/:postId/reposts", { preHandler: requireAuth }, async (request, reply) => bridgeToLegacy(app, request, reply, {
    method: "POST",
    path: `/api/feed/${param(request, "postId")}/share`,
  }));

  app.delete("/posts/:postId/reposts", { preHandler: requireAuth }, async (request) => {
    const result = await query(
      `UPDATE posts
       SET deleted_at = NOW(), updated_at = NOW()
       WHERE author_id = $1 AND share_of_post_id = $2 AND deleted_at IS NULL`,
      [request.user!.userId, param(request, "postId")]
    );
    return { reposted: false, changed: (result.rowCount || 0) > 0 };
  });

  app.post("/posts/:postId/quotes", { preHandler: requireAuth }, async (request) => {
    const postId = param(request, "postId");
    const original = await queryOne(`SELECT post_id FROM posts WHERE post_id = $1 AND deleted_at IS NULL`, [postId]);
    if (!original) throw new HttpError(404, "Post not found");
    const text = normalizePostBody(body(request).body);
    const mentions = extractTokens(text, "@");
    const hashtags = extractTokens(text, "#");
    const quotePostId = generateId();
    const ts = now();
    await query(
      `INSERT INTO posts (
         post_id, author_id, body, media_urls, mentions, hashtags,
         like_count, comment_count, share_count, share_of_post_id, created_at, updated_at
       )
       VALUES ($1, $2, $3, '[]', $4, $5, 0, 0, 0, $6, $7, $8)`,
      [quotePostId, request.user!.userId, text, JSON.stringify(mentions), JSON.stringify(hashtags), postId, ts, ts]
    );
    return { id: quotePostId, quoteOfPostId: postId };
  });

  app.get("/topics/:topicId/posts", { preHandler: requireAuth }, async (request, reply) => bridgeToLegacy(app, request, reply, {
    method: "GET",
    path: "/api/feed",
    query: { ...queryParams(request), tag: param(request, "topicId") },
  }));
  app.get("/hashtags/:hashtag/posts", { preHandler: requireAuth }, async (request, reply) => bridgeToLegacy(app, request, reply, {
    method: "GET",
    path: "/api/feed",
    query: { ...queryParams(request), tag: param(request, "hashtag") },
  }));

  app.get("/me/notification-preferences", { preHandler: requireAuth }, async (request) => {
    const row = await queryOne(`SELECT settings FROM user_settings WHERE user_id = $1`, [request.user!.userId]);
    return { preferences: row?.settings || {} };
  });

  app.patch("/me/notification-preferences", { preHandler: requireAuth }, async (request) => {
    const incoming = body(request);
    const existing = await queryOne(`SELECT settings FROM user_settings WHERE user_id = $1`, [request.user!.userId]);
    const settings = { ...(existing?.settings || {}), ...incoming };
    await query(
      `INSERT INTO user_settings (user_id, settings, updated_at)
       VALUES ($1, $2, NOW())
       ON CONFLICT (user_id)
       DO UPDATE SET settings = EXCLUDED.settings, updated_at = EXCLUDED.updated_at`,
      [request.user!.userId, JSON.stringify(settings)]
    );
    return { preferences: settings };
  });

  app.post("/uploads/presign", { preHandler: requireAuth }, async (request) => {
    const uploadSessionId = generateId();
    const mediaObjectId = generateId();
    const purpose = String(body(request).purpose || "general").slice(0, 64);
    const mimeType = String(body(request).mimeType || "application/octet-stream").slice(0, 120);
    const byteSize = Math.max(0, Number(body(request).byteSize || 0));
    const userUuid = await resolveUserUuid(request.user!.userId);
    if (!userUuid) throw new HttpError(404, "User not found");
    await withTransaction(async (client) => {
      await client.query(
        `INSERT INTO media_objects (
           id, owner_id, bucket, object_key, media_type, mime_type,
           byte_size, processing_status, moderation_status, metadata, created_at
         )
         VALUES ($1, $2, 'cloudinary', $3, $4, $5, $6, 'pending', 'pending', $7, NOW())`,
        [mediaObjectId, userUuid, `${request.user!.userId}/${uploadSessionId}`, purpose, mimeType, byteSize, JSON.stringify({ purpose })]
      );
      await client.query(
        `INSERT INTO upload_sessions (
           id, owner_id, media_object_id, upload_type, status, expected_byte_size,
           expires_at, created_at, metadata
         )
         VALUES ($1, $2, $3, $4, 'pending', $5, NOW() + INTERVAL '30 minutes', NOW(), $6)`,
        [uploadSessionId, userUuid, mediaObjectId, purpose, byteSize || null, JSON.stringify({ mimeType })]
      );
    });
    return {
      uploadSessionId,
      mediaObjectId,
      provider: "cloudinary",
      directUpload: false,
      uploadEndpoint: "/api/v1/uploads/complete-via-api",
    };
  });

  app.post("/uploads/:uploadSessionId/complete", { preHandler: requireAuth }, async (request) => {
    const uploadSessionId = param(request, "uploadSessionId");
    const userUuid = await resolveUserUuid(request.user!.userId);
    const result = await query(
      `UPDATE upload_sessions
       SET status = 'completed', completed_at = NOW(), updated_at = NOW()
       WHERE id = $1 AND owner_id = $2
       RETURNING media_object_id`,
      [uploadSessionId, userUuid]
    );
    if ((result.rowCount || 0) === 0) throw new HttpError(404, "Upload session not found");
    await query(`UPDATE media_objects SET processing_status = 'ready', updated_at = NOW() WHERE id = $1`, [result.rows[0]?.media_object_id]);
    return { uploadSessionId, mediaObjectId: result.rows[0]?.media_object_id, completed: true };
  });

  app.post("/reports", { preHandler: requireAuth }, async (request) => {
    const targetType = String(body(request).targetType || "").trim().slice(0, 32);
    const targetId = String(body(request).targetId || "").trim();
    const reason = String(body(request).reason || "user_report").trim().slice(0, 80);
    ensure(["post", "comment", "user", "message"].includes(targetType), 400, "Invalid target type");
    ensure(targetId.length >= 8, 400, "Invalid target");
    const reporterUuid = await resolveUserUuid(request.user!.userId);
    if (!reporterUuid) throw new HttpError(404, "User not found");
    const reportId = generateId();
    await query(
      `INSERT INTO reports (
         id, reporter_id, target_type, target_uuid, reason, status, created_at
       )
       VALUES ($1, $2, $3, $4, $5, 'open', NOW())
       ON CONFLICT DO NOTHING`,
      [reportId, reporterUuid, targetType, targetId, reason]
    );
    await enqueueOutboxEvent({
      eventType: "moderation.report.created",
      aggregateType: targetType,
      aggregateId: targetId,
      payload: { reportId, reporterId: request.user!.userId, reason },
    });
    return { reportId, status: "open" };
  });

  app.get("/admin/moderation/cases", { preHandler: requireAuth }, async (request) => {
    const allowed = await canModerate(request.user!.userId);
    if (!allowed.allowed) throw new HttpError(403, "Admin permission required");
    const rows = await queryMany(
      `SELECT *
       FROM moderation_cases
       ORDER BY priority DESC, opened_at DESC
       LIMIT 100`
    );
    return { items: rows };
  });

  app.get("/admin/moderation/cases/:caseId", { preHandler: requireAuth }, async (request) => {
    const allowed = await canModerate(request.user!.userId);
    if (!allowed.allowed) throw new HttpError(403, "Admin permission required");
    const row = await queryOne(`SELECT * FROM moderation_cases WHERE id = $1`, [param(request, "caseId")]);
    if (!row) throw new HttpError(404, "Moderation case not found");
    return { case: row };
  });

  app.post("/admin/moderation/cases/:caseId/notes", { preHandler: requireAuth }, async (request) => {
    const allowed = await canModerate(request.user!.userId);
    if (!allowed.allowed) throw new HttpError(403, "Admin permission required");
    await enqueueOutboxEvent({
      eventType: "moderation.case.note_added",
      aggregateType: "moderation_case",
      aggregateId: param(request, "caseId"),
      payload: { note: String(body(request).note || "").slice(0, 2000), actorId: request.user!.userId },
    });
    return { added: true };
  });

  app.post("/admin/moderation/actions", { preHandler: requireAuth }, async (request) => {
    const allowed = await canModerate(request.user!.userId);
    if (!allowed.allowed) throw new HttpError(403, "Admin permission required");
    const actionId = generateId();
    await query(
      `INSERT INTO moderation_actions (
         id, case_id, actor_id, action_type, target_type, target_uuid, reason, metadata, created_at
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())`,
      [
        actionId,
        body(request).caseId || null,
        await resolveUserUuid(request.user!.userId),
        String(body(request).actionType || "reviewed").slice(0, 40),
        String(body(request).targetType || "post").slice(0, 32),
        String(body(request).targetId || ""),
        String(body(request).reason || "").slice(0, 500),
        JSON.stringify(body(request).metadata || {}),
      ]
    );
    return { actionId };
  });

  app.post("/admin/moderation/actions/:actionId/reverse", { preHandler: requireAuth }, async (request) => {
    const allowed = await canModerate(request.user!.userId);
    if (!allowed.allowed) throw new HttpError(403, "Admin permission required");
    await enqueueOutboxEvent({
      eventType: "moderation.action.reversed",
      aggregateType: "moderation_action",
      aggregateId: param(request, "actionId"),
      payload: { actorId: request.user!.userId },
    });
    return { reversed: true };
  });
}
