import assert from "node:assert/strict";
import test, { after, before } from "node:test";

import Fastify from "fastify";
import jwt from "jsonwebtoken";
import { newDb } from "pg-mem";

function authHeader(token: string): Record<string, string> {
  return {
    authorization: `Bearer ${token}`,
    "content-type": "application/json",
  };
}

function signAccessToken(userId: string): string {
  return jwt.sign(
    {
      sub: userId,
      email: `${userId}@example.com`,
      username: userId.slice(0, 16),
    },
    process.env.JWT_SECRET || "",
    {
      issuer: "prava",
      audience: "prava-clients",
      expiresIn: "30m",
    }
  );
}

async function injectJson<T = any>(
  path: string,
  options: {
    method?: string;
    token?: string;
    body?: unknown;
  } = {}
): Promise<{ status: number; data: T }> {
  const response = await app.inject({
    method: options.method || "GET",
    url: path,
    headers: options.token
      ? (options.body === undefined
          ? { authorization: `Bearer ${options.token}` }
          : authHeader(options.token))
      : (options.body === undefined ? {} : { "content-type": "application/json" }),
    payload: options.body === undefined ? undefined : JSON.stringify(options.body),
  });
  return {
    status: response.statusCode,
    data: response.json() as T,
  };
}

let app: ReturnType<typeof Fastify>;
let closePg: (() => Promise<void>) | null = null;
let userA = "";
let userB = "";
let postId = "";
let tokenA = "";
let tokenB = "";

before(async () => {
  process.env.NODE_ENV = "test";
  process.env.JWT_SECRET = process.env.JWT_SECRET || "test_jwt_secret_key";
  process.env.DATABASE_URL =
    process.env.DATABASE_URL || "postgresql://postgres:postgres@127.0.0.1:5432/prava_test";

  const pgLib = await import("../src/lib/pg.js");
  const memoryDb = newDb({ autoCreateForeignKeyIndices: true });
  const adapter = memoryDb.adapters.createPg();
  const pool = new adapter.Pool();
  pgLib.setPgPoolForTest(pool as any);
  await pgLib.runMigrations(pool as any);
  closePg = pgLib.closePg;

  const stamp = Date.now();
  userA = `v1_user_a_${stamp}`;
  userB = `v1_user_b_${stamp}`;
  postId = `v1_post_${stamp}`;
  const ts = new Date();

  await pgLib.query(
    `INSERT INTO users (
       user_id, email, email_lower, username, username_lower, display_name,
       display_name_lower, password_hash, is_verified, created_at, updated_at
     )
     VALUES
       ($1, $2, $2, $3, $3, 'User A', 'user a', 'scrypt$dummy$dummy', TRUE, $7, $7),
       ($4, $5, $5, $6, $6, 'User B', 'user b', 'scrypt$dummy$dummy', TRUE, $7, $7)`,
    [userA, `${userA}@example.com`, userA, userB, `${userB}@example.com`, userB, ts]
  );
  await pgLib.query(
    `INSERT INTO follows (follower_id, following_id, created_at)
     VALUES ($1, $2, $3)`,
    [userB, userA, ts]
  );
  await pgLib.query(
    `INSERT INTO posts (
       post_id, author_id, body, media_urls, mentions, hashtags,
       like_count, comment_count, share_count, created_at, updated_at
     )
     VALUES ($1, $2, 'hello #v1', '[]', '[]', '["v1"]', 0, 0, 0, $3, $3)`,
    [postId, userB, ts]
  );

  tokenA = signAccessToken(userA);
  tokenB = signAccessToken(userB);
  const apiV1Service = (await import("../src/services/api-v1/index.js")).default;
  const feedService = (await import("../src/services/feed/index.js")).default;
  const userService = (await import("../src/services/user/index.js")).default;
  const notificationService = (await import("../src/services/notification/index.js")).default;
  app = Fastify({ logger: false });
  app.register(feedService, { prefix: "/api/feed" });
  app.register(userService, { prefix: "/api/users" });
  app.register(notificationService, { prefix: "/api/notifications" });
  app.register(apiV1Service, { prefix: "/api/v1" });
  await app.ready();
});

after(async () => {
  await app?.close().catch(() => undefined);
  if (closePg) {
    await closePg();
  }
});

test("api v1 wraps responses and keeps post likes idempotent", async () => {
  const first = await injectJson<any>(`/api/v1/posts/${postId}/likes`, {
    method: "POST",
    token: tokenA,
  });
  assert.equal(first.status, 200);
  assert.equal(first.data.success, true);
  assert.equal(first.data.data.liked, true);
  assert.equal(first.data.data.likeCount, 1);
  assert.ok(first.data.meta.requestId);

  const second = await injectJson<any>(`/api/v1/posts/${postId}/likes`, {
    method: "POST",
    token: tokenA,
  });
  assert.equal(second.status, 200);
  assert.equal(second.data.data.likeCount, 1);

  const unlike = await injectJson<any>(`/api/v1/posts/${postId}/likes`, {
    method: "DELETE",
    token: tokenA,
  });
  assert.equal(unlike.status, 200);
  assert.equal(unlike.data.data.liked, false);
  assert.equal(unlike.data.data.likeCount, 0);
});

test("api v1 auth uses verified signup, argon2 passwords, refresh rotation, and replay detection", async () => {
  const stamp = Date.now();
  const handle = `v1_auth_${stamp}`;
  const email = `${handle}@example.com`;
  const password = "CorrectHorse123";

  const signup = await injectJson<any>("/api/v1/auth/signup", {
    method: "POST",
    body: {
      email,
      handle,
      displayName: "V1 Auth User",
      password,
      languageCode: "en",
    },
  });
  assert.equal(signup.status, 201, JSON.stringify(signup.data));
  assert.equal(signup.data.success, true);
  assert.equal(signup.data.data.verificationRequired, true);
  assert.equal(signup.data.data.email, email);
  assert.match(signup.data.data.devCode, /^\d{6}$/);

  const pgLib = await import("../src/lib/pg.js");
  const createdUser = await pgLib.queryOne<{ id: string; user_id: string; password_hash: string }>(
    `SELECT id::text AS id, user_id, password_hash FROM users WHERE username_lower = $1`,
    [handle]
  );
  assert.ok(createdUser);
  assert.ok(createdUser.password_hash.startsWith("$argon2id$"));

  const credential = await pgLib.queryOne<{ password_hash: string }>(
    `SELECT password_hash FROM user_credentials WHERE user_id = $1`,
    [createdUser.id]
  );
  assert.ok(credential?.password_hash.startsWith("$argon2id$"));

  const outbox = await pgLib.queryOne<{ count: string }>(
    `SELECT COUNT(*)::text AS count
     FROM outbox_events
     WHERE event_type = 'auth.verification_email.requested'
       AND aggregate_id = $1`,
    [createdUser.id]
  );
  assert.equal(outbox?.count, "1");

  const verify = await injectJson<any>("/api/v1/auth/verify-email", {
    method: "POST",
    body: {
      email,
      code: signup.data.data.devCode,
    },
  });
  assert.equal(verify.status, 200);
  assert.equal(verify.data.success, true);
  assert.equal(verify.data.data.verified, true);

  const login = await injectJson<any>("/api/v1/auth/login", {
    method: "POST",
    body: {
      identifier: email,
      password,
      deviceId: "contract-device",
      deviceName: "Contract Browser",
      platform: "web",
    },
  });
  assert.equal(login.status, 200, JSON.stringify(login.data));
  assert.equal(login.data.success, true);
  assert.ok(login.data.data.accessToken);
  assert.ok(login.data.data.refreshToken);
  assert.ok(login.data.data.sessionId);
  assert.equal(login.data.data.user.handle, handle);

  const refresh = await injectJson<any>("/api/v1/auth/refresh", {
    method: "POST",
    body: {
      refreshToken: login.data.data.refreshToken,
    },
  });
  assert.equal(refresh.status, 200);
  assert.equal(refresh.data.success, true);
  assert.ok(refresh.data.data.accessToken);
  assert.notEqual(refresh.data.data.refreshToken, login.data.data.refreshToken);

  const replay = await injectJson<any>("/api/v1/auth/refresh", {
    method: "POST",
    body: {
      refreshToken: login.data.data.refreshToken,
    },
  });
  assert.equal(replay.status, 401);

  const revoked = await pgLib.queryOne<{ revoked: string }>(
    `SELECT COUNT(*)::text AS revoked
     FROM auth_sessions
     WHERE user_id = $1 AND revoked_at IS NOT NULL`,
    [createdUser.id]
  );
  assert.equal(revoked?.revoked, "1");
});

test("api v1 follow creates reciprocal friendship metadata", async () => {
  const response = await injectJson<any>(`/api/v1/users/${userB}/follow`, {
    method: "POST",
    token: tokenA,
  });
  assert.equal(response.status, 200);
  assert.equal(response.data.success, true);
  assert.equal(response.data.data.following, true);

  const pgLib = await import("../src/lib/pg.js");
  const friendship = await pgLib.queryOne<{ count: string }>(
    `SELECT COUNT(*)::text AS count FROM friendships WHERE status = 'accepted'`
  );
  assert.equal(friendship?.count, "1");
});

test("outbox dispatcher materializes notification side effects", async () => {
  const worker = await import("../src/workers/outbox-dispatcher/index.js");
  const result = await worker.runOutboxDispatcherBatch(100);
  assert.ok(result.processed >= 1);
  assert.equal(result.failed, 0);

  const pgLib = await import("../src/lib/pg.js");
  const notification = await pgLib.queryOne<{ count: string; unread: string }>(
    `SELECT COUNT(*)::text AS count,
            COUNT(*) FILTER (WHERE read_at IS NULL)::text AS unread
     FROM notifications
     WHERE user_id = $1
       AND actor_user_id = $2
       AND type IN ('post.like', 'relationship.follow')`,
    [userB, userA]
  );
  assert.equal(notification?.count, "2");
  assert.equal(notification?.unread, "2");

  const stats = await pgLib.queryOne<{ unread_notifications_count: string }>(
    `SELECT unread_notifications_count::text AS unread_notifications_count
     FROM user_stats
     WHERE user_id = (SELECT id FROM users WHERE user_id = $1)`,
    [userB]
  );
  assert.equal(stats?.unread_notifications_count, "2");

  const latest = await pgLib.queryOne<{ notification_id: string }>(
    `SELECT notification_id
     FROM notifications
     WHERE user_id = $1
     ORDER BY created_at DESC
     LIMIT 1`,
    [userB]
  );
  assert.ok(latest?.notification_id);

  const read = await injectJson<any>(`/api/v1/notifications/${latest.notification_id}/read`, {
    method: "POST",
    token: tokenB,
    body: {},
  });
  assert.equal(read.status, 200, JSON.stringify(read.data));
  assert.equal(read.data.data.unreadCount, 1);

  const updatedStats = await pgLib.queryOne<{ unread_notifications_count: string }>(
    `SELECT unread_notifications_count::text AS unread_notifications_count
     FROM user_stats
     WHERE user_id = (SELECT id FROM users WHERE user_id = $1)`,
    [userB]
  );
  assert.equal(updatedStats?.unread_notifications_count, "1");
});
