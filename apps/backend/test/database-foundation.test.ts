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
