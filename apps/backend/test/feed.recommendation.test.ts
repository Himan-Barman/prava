import assert from "node:assert/strict";
import { AddressInfo } from "node:net";
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
  const secret = process.env.JWT_SECRET || "";
  return jwt.sign(
    {
      sub: userId,
      email: `${userId}@example.com`,
      username: userId.slice(0, 16),
    },
    secret,
    {
      issuer: "prava",
      audience: "prava-clients",
      expiresIn: "30m",
    }
  );
}

async function httpJson<T = unknown>(
  baseUrl: string,
  path: string,
  options: {
    method?: string;
    token?: string;
    body?: unknown;
  } = {}
): Promise<{ status: number; data: T }> {
  const response = await fetch(`${baseUrl}${path}`, {
    method: options.method || "GET",
    headers: options.token
      ? authHeader(options.token)
      : { "content-type": "application/json" },
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  });

  const text = await response.text();
  const data = text ? (JSON.parse(text) as T) : ({} as T);
  return { status: response.status, data };
}

let app: ReturnType<typeof Fastify>;
let baseUrl = "";
let closePg: (() => Promise<void>) | null = null;
let token = "";
let viewerId = "";
let followedId = "";
let outsideId = "";
let blockedId = "";
let followedPostId = "";
let outsidePostId = "";
let blockedPostId = "";

before(async () => {
  process.env.NODE_ENV = "test";
  process.env.JWT_SECRET = process.env.JWT_SECRET || "test_jwt_secret_key";
  process.env.DATABASE_URL = process.env.DATABASE_URL || "postgresql://postgres:postgres@127.0.0.1:5432/prava_test";

  const stamp = Date.now();
  viewerId = `feed_viewer_${stamp}`;
  followedId = `feed_followed_${stamp}`;
  outsideId = `feed_outside_${stamp}`;
  blockedId = `feed_blocked_${stamp}`;
  followedPostId = `post_followed_${stamp}`;
  outsidePostId = `post_outside_${stamp}`;
  blockedPostId = `post_blocked_${stamp}`;

  const pgLib = await import("../src/lib/pg.js");
  const memoryDb = newDb({ autoCreateForeignKeyIndices: true });
  const adapter = memoryDb.adapters.createPg();
  const pool = new adapter.Pool();
  pgLib.setPgPoolForTest(pool as any);
  await pgLib.runMigrations(pool as any);
  closePg = pgLib.closePg;

  const ts = new Date();
  await pgLib.query(
    `INSERT INTO users (
       user_id, email, email_lower, username, username_lower, display_name,
       display_name_lower, password_hash, is_verified, created_at, updated_at
     )
     VALUES
       ($1, 'viewer@example.com', 'viewer@example.com', 'viewer_test', 'viewer_test', 'Viewer', 'viewer', 'scrypt$dummy$dummy', TRUE, $5, $5),
       ($2, 'followed@example.com', 'followed@example.com', 'followed_test', 'followed_test', 'Followed', 'followed', 'scrypt$dummy$dummy', TRUE, $5, $5),
       ($3, 'outside@example.com', 'outside@example.com', 'outside_test', 'outside_test', 'Outside', 'outside', 'scrypt$dummy$dummy', TRUE, $5, $5),
       ($4, 'blocked@example.com', 'blocked@example.com', 'blocked_test', 'blocked_test', 'Blocked', 'blocked', 'scrypt$dummy$dummy', TRUE, $5, $5)`,
    [viewerId, followedId, outsideId, blockedId, ts]
  );

  await pgLib.query(
    `INSERT INTO follows (follower_id, following_id, created_at)
     VALUES ($1, $2, $3)`,
    [viewerId, followedId, ts]
  );
  await pgLib.query(
    `INSERT INTO user_blocks (blocker_id, blocked_id, created_at)
     VALUES ($1, $2, $3)`,
    [viewerId, blockedId, ts]
  );
  await pgLib.query(
    `INSERT INTO posts (
       post_id, author_id, body, media_urls, mentions, hashtags,
       like_count, comment_count, share_count, created_at, updated_at
     )
     VALUES
       ($1, $4, 'followed post #prava', '[]', '[]', '["prava"]', 2, 1, 0, $7, $7),
       ($2, $5, 'outside post #tech', '[]', '[]', '["tech"]', 8, 2, 1, $7, $7),
       ($3, $6, 'blocked post #tech', '[]', '[]', '["tech"]', 100, 40, 20, $7, $7)`,
    [followedPostId, outsidePostId, blockedPostId, followedId, outsideId, blockedId, ts]
  );
  await pgLib.query(
    `INSERT INTO post_tags (post_id, tag, author_id, created_at)
     VALUES
       ($1, 'prava', $3, $5),
       ($2, 'tech', $4, $5),
       ($6, 'tech', $7, $5)`,
    [followedPostId, outsidePostId, followedId, outsideId, ts, blockedPostId, blockedId]
  );
  await pgLib.query(
    `INSERT INTO user_topic_affinities (user_id, topic, score, positive_count, negative_count, last_signal_at, updated_at)
     VALUES ($1, 'tech', 10, 3, 0, $2, $2)`,
    [viewerId, ts]
  );

  token = signAccessToken(viewerId);

  const feedService = (await import("../src/services/feed/index.js")).default;
  app = Fastify({ logger: false });
  app.register(feedService, { prefix: "/api/feed" });

  await app.listen({ host: "127.0.0.1", port: 0 });
  const address = app.server.address() as AddressInfo;
  baseUrl = `http://127.0.0.1:${address.port}`;
});

after(async () => {
  try {
    await app?.close();
  } catch {
    // ignore
  }

  try {
    if (closePg) {
      await closePg();
    }
  } catch {
    // ignore
  }
});

test("feed recommendation serves followed and interest posts without blocked content", async () => {
  const pgLib = await import("../src/lib/pg.js");
  const direct = await pgLib.queryMany(
    `SELECT p.post_id
     FROM posts p
     LEFT JOIN follows f ON f.follower_id = $1 AND f.following_id = p.author_id
     WHERE (p.author_id = $1 OR f.following_id IS NOT NULL)
       AND p.created_at > $2
       AND p.deleted_at IS NULL
       AND p.moderation_state = 'active'`,
    [viewerId, new Date(Date.now() - 21 * 24 * 60 * 60 * 1000)]
  );
  assert.ok(direct.some((row) => row.post_id === followedPostId), `direct candidate query returned ${JSON.stringify(direct)}`);

  const response = await httpJson<{ items: Array<{ id: string; recommendationReason?: string | null }> }>(
    baseUrl,
    "/api/feed/for-you?limit=10",
    { token }
  );

  assert.equal(response.status, 200, JSON.stringify(response.data));
  const ids = response.data.items.map((post) => post.id);
  assert.ok(ids.includes(followedPostId), `expected followed post in ${JSON.stringify(response.data)}`);
  assert.ok(ids.includes(outsidePostId), `expected interest post in ${JSON.stringify(response.data)}`);
  assert.equal(ids.includes(blockedPostId), false, `blocked post leaked in ${JSON.stringify(response.data)}`);
});

test("following feed is restricted to followed authors and self", async () => {
  const response = await httpJson<{ items: Array<{ id: string }> }>(
    baseUrl,
    "/api/feed/following?limit=10",
    { token }
  );

  assert.equal(response.status, 200, JSON.stringify(response.data));
  const ids = response.data.items.map((post) => post.id);
  assert.ok(ids.includes(followedPostId), `expected followed post in ${JSON.stringify(ids)}`);
  assert.equal(ids.includes(outsidePostId), false, `outside post leaked in ${JSON.stringify(ids)}`);
});

test("not interested removes a post from personalized feed", async () => {
  const mark = await httpJson<{ notInterested: boolean }>(
    baseUrl,
    `/api/feed/${outsidePostId}/not-interested`,
    {
      method: "POST",
      token,
      body: { reason: "test" },
    }
  );
  assert.equal(mark.status, 200, JSON.stringify(mark.data));
  assert.equal(mark.data.notInterested, true);

  const response = await httpJson<{ items: Array<{ id: string }> }>(
    baseUrl,
    "/api/feed/for-you?limit=10",
    { token }
  );
  assert.equal(response.status, 200, JSON.stringify(response.data));
  const ids = response.data.items.map((post) => post.id);
  assert.equal(ids.includes(outsidePostId), false);
});

test("feed event ingestion is idempotent by client event id", async () => {
  const clientEventId = `evt_${Date.now()}`;
  const first = await httpJson<{ accepted: number }>(
    baseUrl,
    "/api/feed/events",
    {
      method: "POST",
      token,
      body: {
        events: [
          {
            type: "impression",
            postId: followedPostId,
            clientEventId,
            source: "test",
          },
        ],
      },
    }
  );
  assert.equal(first.status, 200, JSON.stringify(first.data));
  assert.equal(first.data.accepted, 1);

  const second = await httpJson<{ accepted: number }>(
    baseUrl,
    "/api/feed/events",
    {
      method: "POST",
      token,
      body: {
        events: [
          {
            type: "impression",
            postId: followedPostId,
            clientEventId,
            source: "test",
          },
        ],
      },
    }
  );
  assert.equal(second.status, 200, JSON.stringify(second.data));
  assert.equal(second.data.accepted, 0);
});
