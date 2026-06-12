import assert from "node:assert/strict";
import test, { after, before } from "node:test";

import { newDb } from "pg-mem";

let closePg: (() => Promise<void>) | null = null;
let backfilledUserUuid = "";

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
});

after(async () => {
  if (closePg) {
    await closePg();
  }
});

test("database foundation creates production catalog tables and seed data", async () => {
  const pgLib = await import("../src/lib/pg.js");

  const tables = await pgLib.queryMany<{ table_name: string }>(
    `SELECT table_name
     FROM information_schema.tables
     WHERE table_schema = 'public'
       AND table_name IN (
        'user_profiles',
        'user_stats',
        'post_stats',
        'post_mentions',
        'feed_algorithm_versions',
        'feed_requests',
        'notification_preferences',
        'push_subscriptions',
        'reports',
        'media_objects',
        'outbox_events',
        'feature_flags',
        'admin_audit_logs'
       )`
  );
  const names = new Set(tables.map((row) => row.table_name));
  assert.equal(names.size, 13, `missing foundation tables: ${JSON.stringify([...names])}`);

  const roles = await pgLib.queryMany<{ name: string }>(
    "SELECT name FROM roles ORDER BY name"
  );
  assert.deepEqual(
    roles.map((row) => row.name),
    ["admin", "moderator", "super_admin", "support", "user"]
  );

  const activeFeed = await pgLib.queryOne<{ version: string }>(
    "SELECT version FROM feed_algorithm_versions WHERE name = 'prava-personalized-feed' AND is_active = true"
  );
  assert.equal(activeFeed?.version, "1.0.0");
});

test("foundation migration is re-runnable and backfills legacy ids", async () => {
  const pgLib = await import("../src/lib/pg.js");
  const { runDatabaseFoundationMigrations } = await import("../src/lib/database-foundation.js");

  const stamp = Date.now();
  const userId = `foundation_user_${stamp}`;
  const postId = `foundation_post_${stamp}`;
  await pgLib.query(
    `INSERT INTO users (
      user_id, email, email_lower, username, username_lower, display_name,
      display_name_lower, password_hash, created_at, updated_at
    ) VALUES ($1, $2, $2, $3, $3, 'Foundation User', 'foundation user', 'hash', now(), now())`,
    [userId, `${userId}@example.com`, userId]
  );
  await pgLib.query(
    `INSERT INTO posts (post_id, author_id, body, media_urls, mentions, hashtags, created_at, updated_at)
     VALUES ($1, $2, 'hello #foundation', '[]', '[]', '["foundation"]', now(), now())`,
    [postId, userId]
  );

  await runDatabaseFoundationMigrations(pgLib.getPool());

  const row = await pgLib.queryOne<{ user_uuid: string; post_uuid: string; author_uuid: string }>(
    `SELECT u.id::text AS user_uuid, p.id::text AS post_uuid, p.author_uuid::text AS author_uuid
     FROM users u
     JOIN posts p ON p.author_id = u.user_id
     WHERE u.user_id = $1 AND p.post_id = $2`,
    [userId, postId]
  );
  assert.ok(row?.user_uuid);
  assert.ok(row?.post_uuid);
  assert.equal(row?.author_uuid, row?.user_uuid);
  backfilledUserUuid = row.user_uuid;
});

test("foundation refresh adds missing comment uuid columns", async () => {
  const pgLib = await import("../src/lib/pg.js");
  const { runDatabaseFoundationMigrations } = await import("../src/lib/database-foundation.js");

  const stamp = Date.now();
  const userId = `foundation_comment_user_${stamp}`;
  const postId = `foundation_comment_post_${stamp}`;
  const commentId = `foundation_comment_${stamp}`;

  await pgLib.query(
    `INSERT INTO users (
      user_id, email, email_lower, username, username_lower, display_name,
      display_name_lower, password_hash, created_at, updated_at
    ) VALUES ($1, $2, $2, $3, $3, 'Foundation Comment User', 'foundation comment user', 'hash', now(), now())`,
    [userId, `${userId}@example.com`, userId]
  );
  await pgLib.query(
    `INSERT INTO posts (post_id, author_id, body, media_urls, mentions, hashtags, created_at, updated_at)
     VALUES ($1, $2, 'comment migration check', '[]', '[]', '[]', now(), now())`,
    [postId, userId]
  );
  await pgLib.query(
    `INSERT INTO comments (comment_id, post_id, author_id, body, created_at)
     VALUES ($1, $2, $3, 'legacy comment', now())`,
    [commentId, postId, userId]
  );
  await pgLib.query(
    `INSERT INTO comment_likes (comment_id, user_id, created_at)
     VALUES ($1, $2, now())`,
    [commentId, userId]
  );

  await pgLib.query(`
    DROP INDEX IF EXISTS idx_comment_likes_uuid_unique;
    DROP INDEX IF EXISTS idx_comments_parent_uuid_created;
    DROP INDEX IF EXISTS idx_comments_post_uuid_created;
    DROP INDEX IF EXISTS idx_comments_uuid_unique;

    ALTER TABLE comment_likes DROP COLUMN IF EXISTS comment_uuid;
    ALTER TABLE comment_likes DROP COLUMN IF EXISTS user_uuid;

    ALTER TABLE comments DROP COLUMN IF EXISTS id;
    ALTER TABLE comments DROP COLUMN IF EXISTS post_uuid;
    ALTER TABLE comments DROP COLUMN IF EXISTS author_uuid;
    ALTER TABLE comments DROP COLUMN IF EXISTS parent_comment_uuid;
    ALTER TABLE comments DROP COLUMN IF EXISTS depth;
    ALTER TABLE comments DROP COLUMN IF EXISTS likes_count;
    ALTER TABLE comments DROP COLUMN IF EXISTS replies_count;
    ALTER TABLE comments DROP COLUMN IF EXISTS edited_at;
    ALTER TABLE comments DROP COLUMN IF EXISTS deleted_at;
  `);

  await runDatabaseFoundationMigrations(pgLib.getPool());

  const row = await pgLib.queryOne<{
    comment_uuid: string;
    post_uuid: string;
    author_uuid: string;
    like_comment_uuid: string;
    like_user_uuid: string;
  }>(
    `SELECT
       c.id::text AS comment_uuid,
       c.post_uuid::text AS post_uuid,
       c.author_uuid::text AS author_uuid,
       cl.comment_uuid::text AS like_comment_uuid,
       cl.user_uuid::text AS like_user_uuid
     FROM comments c
     JOIN comment_likes cl ON cl.comment_id = c.comment_id
     WHERE c.comment_id = $1`,
    [commentId]
  );

  assert.ok(row?.comment_uuid, JSON.stringify(row));
  assert.ok(row?.post_uuid, JSON.stringify(row));
  assert.ok(row?.author_uuid, JSON.stringify(row));
  assert.equal(row?.like_comment_uuid, row?.comment_uuid);
  assert.equal(row?.like_user_uuid, row?.author_uuid);
});

test("foundation rerun repairs partially marked foundation tables", async () => {
  const pgLib = await import("../src/lib/pg.js");
  const { runDatabaseFoundationMigrations } = await import("../src/lib/database-foundation.js");

  await pgLib.query(`
    DROP TABLE IF EXISTS user_profiles;
    DROP INDEX IF EXISTS user_profiles_pkey;
  `);
  await runDatabaseFoundationMigrations(pgLib.getPool());

  const columns = await pgLib.queryMany<{ column_name: string }>(
    `SELECT column_name
     FROM information_schema.columns
     WHERE table_schema = 'public'
       AND table_name = 'user_profiles'
       AND column_name IN ('user_id', 'profile_metadata', 'display_name', 'search_vector')`
  );
  const names = new Set(columns.map((row) => row.column_name));
  assert.equal(names.has("user_id"), true);
  assert.equal(names.has("profile_metadata"), true);
  assert.equal(names.has("display_name"), true);
  assert.equal(names.has("search_vector"), true);
});

test("foundation refresh restores follow uuid columns before domain indexes", async () => {
  const pgLib = await import("../src/lib/pg.js");
  const { runDatabaseFoundationMigrations } = await import("../src/lib/database-foundation.js");

  const stamp = Date.now();
  const followerId = `foundation_follower_${stamp}`;
  const followingId = `foundation_following_${stamp}`;

  await pgLib.query(
    `INSERT INTO users (
      user_id, email, email_lower, username, username_lower, display_name,
      display_name_lower, password_hash, created_at, updated_at
    ) VALUES
      ($1, $2, $2, $3, $3, 'Foundation Follower', 'foundation follower', 'hash', now(), now()),
      ($4, $5, $5, $6, $6, 'Foundation Following', 'foundation following', 'hash', now(), now())`,
    [
      followerId,
      `${followerId}@example.com`,
      followerId,
      followingId,
      `${followingId}@example.com`,
      followingId,
    ]
  );
  await pgLib.query(
    `INSERT INTO follows (follower_id, following_id, created_at)
     VALUES ($1, $2, now())`,
    [followerId, followingId]
  );

  await pgLib.query(`
    DROP INDEX IF EXISTS idx_follows_follower_status_created;
    DROP INDEX IF EXISTS idx_follows_following_status_created;
    DROP INDEX IF EXISTS idx_follows_follower_uuid_created;
    DROP INDEX IF EXISTS idx_follows_following_uuid_created;
    ALTER TABLE follows DROP COLUMN IF EXISTS follower_uuid;
    ALTER TABLE follows DROP COLUMN IF EXISTS following_uuid;
  `);

  await runDatabaseFoundationMigrations(pgLib.getPool());

  const row = await pgLib.queryOne<{
    follower_uuid: string;
    following_uuid: string;
  }>(
    `SELECT follower_uuid::text AS follower_uuid, following_uuid::text AS following_uuid
     FROM follows
     WHERE follower_id = $1 AND following_id = $2`,
    [followerId, followingId]
  );

  assert.ok(row?.follower_uuid, JSON.stringify(row));
  assert.ok(row?.following_uuid, JSON.stringify(row));
});

test("foundation enforces identity and reliability uniqueness", async () => {
  const pgLib = await import("../src/lib/pg.js");
  const stamp = Date.now();
  assert.ok(backfilledUserUuid);

  await pgLib.query(
    `INSERT INTO user_emails (id, user_id, email, is_primary, is_verified)
     VALUES ('10000000-0000-0000-0000-000000000001', $1, $2, true, true)`,
    [backfilledUserUuid, `foundation_unique_${stamp}@example.com`]
  );
  await assert.rejects(() =>
    pgLib.query(
      `INSERT INTO user_emails (id, user_id, email)
       VALUES ('10000000-0000-0000-0000-000000000002', $1, $2)`,
      [backfilledUserUuid, `foundation_unique_${stamp}@example.com`]
    )
  );

  await pgLib.query(
    `INSERT INTO processed_events (consumer_name, event_id)
     VALUES ('foundation-test', '20000000-0000-0000-0000-000000000001')`
  );
  await assert.rejects(() =>
    pgLib.query(
      `INSERT INTO processed_events (consumer_name, event_id)
       VALUES ('foundation-test', '20000000-0000-0000-0000-000000000001')`
    )
  );
});
