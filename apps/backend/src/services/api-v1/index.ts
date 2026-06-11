import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";

import { requireAuth } from "../../lib/auth.js";
import { query, queryMany, queryOne, withTransaction } from "../../lib/pg.js";
import {
  HttpError,
  ensure,
  generateId,
  normalizeUsername,
  now,
  toIso,
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
  await withTransaction(async (client) => {
    if (shouldLike) {
      await client.query(
        `INSERT INTO post_likes (post_id, user_id, created_at)
         VALUES ($1, $2, $3)
         ON CONFLICT (post_id, user_id) DO NOTHING`,
        [postId, userId, ts]
      );
    } else {
      await client.query(
        `DELETE FROM post_likes WHERE post_id = $1 AND user_id = $2`,
        [postId, userId]
      );
    }

    await client.query(
      `UPDATE posts
       SET like_count = (SELECT COUNT(*)::int FROM post_likes WHERE post_id = $1),
           updated_at = $2
       WHERE post_id = $1`,
      [postId, ts]
    );

    const postUuid = await resolvePostUuid(postId);
    if (postUuid) {
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

  const bridges: BridgeRoute[] = [
    { method: "POST", path: "/auth/signup", legacyMethod: "POST", legacyPath: "/api/auth/email-otp/request", payload: (request) => ({ email: body(request).email, username: body(request).handle || body(request).username }) },
    { method: "POST", path: "/auth/verify-email", legacyMethod: "POST", legacyPath: "/api/auth/email-otp/verify", payload: (request) => ({ email: body(request).email, code: body(request).code || body(request).otp }) },
    { method: "POST", path: "/auth/resend-verification", legacyMethod: "POST", legacyPath: "/api/auth/email-otp/request", payload: (request) => ({ email: body(request).email, username: body(request).handle || body(request).username }) },
    { method: "POST", path: "/auth/login", legacyPath: "/api/auth/login" },
    { method: "POST", path: "/auth/refresh", legacyPath: "/api/auth/refresh" },
    { method: "POST", path: "/auth/logout", legacyPath: "/api/auth/logout" },
    { method: "POST", path: "/auth/logout-all", legacyPath: "/api/auth/logout-all" },
    { method: "GET", path: "/auth/sessions", legacyMethod: "POST", legacyPath: "/api/auth/sessions" },
    { method: "POST", path: "/auth/password-reset/request", legacyPath: "/api/auth/password-reset/request" },
    { method: "POST", path: "/auth/password-reset/confirm", legacyPath: "/api/auth/password-reset/confirm" },
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
