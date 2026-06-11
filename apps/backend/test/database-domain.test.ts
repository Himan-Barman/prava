import assert from "node:assert/strict";
import test, { after, before } from "node:test";

import { newDb } from "pg-mem";

let closePg: (() => Promise<void>) | null = null;
let pgLib: typeof import("../src/lib/pg.js");

const userA = `domain_user_a_${Date.now()}`;
const userB = `domain_user_b_${Date.now()}`;

before(async () => {
  process.env.NODE_ENV = "test";
  process.env.JWT_SECRET = process.env.JWT_SECRET || "test_jwt_secret_key";
  process.env.DATABASE_URL =
    process.env.DATABASE_URL || "postgresql://postgres:postgres@127.0.0.1:5432/prava_test";

  pgLib = await import("../src/lib/pg.js");
  const memoryDb = newDb({ autoCreateForeignKeyIndices: true });
  const adapter = memoryDb.adapters.createPg();
  const pool = new adapter.Pool();
  pgLib.setPgPoolForTest(pool as any);
  await pgLib.runMigrations(pool as any);
  closePg = pgLib.closePg;

  await pgLib.query(
    `INSERT INTO users (
      user_id, email, email_lower, username, username_lower, display_name,
      display_name_lower, password_hash, created_at, updated_at
    ) VALUES
      ($1, $2, $2, $3, $3, 'Domain A', 'domain a', 'hash', now(), now()),
      ($4, $5, $5, $6, $6, 'Domain B', 'domain b', 'hash', now(), now())`,
    [userA, `${userA}@example.com`, userA, userB, `${userB}@example.com`, userB]
  );
  const { runDatabaseFoundationMigrations } = await import("../src/lib/database-foundation.js");
  await runDatabaseFoundationMigrations(pgLib.getPool());
});

after(async () => {
  if (closePg) {
    await closePg();
  }
});

test("domain expansion creates required high-level tables", async () => {
  const tables = await pgLib.queryMany<{ table_name: string }>(
    `SELECT table_name
     FROM information_schema.tables
     WHERE table_schema = 'public'
       AND table_name IN (
         'user_phones',
         'data_export_requests',
         'user_muted_topics',
         'post_edits',
         'post_reaction_events',
         'topic_aliases',
         'hashtag_topic_edges',
         'mention_notifications',
         'feed_request_items',
         'user_negative_feedback',
         'feed_candidate_sources',
         'topic_trend_windows',
         'retention_policies',
         'retention_job_runs',
         'message_delivery_events',
         'group_role_permissions',
         'notification_delivery_attempts',
         'notification_batches',
         'moderation_queues',
         'moderation_policy_versions',
         'feature_flag_overrides',
         'daily_system_metrics'
       )`
  );
  assert.equal(tables.length, 22, JSON.stringify(tables));
});

test("post domain supports reply/repost fields and prevents duplicate reposts", async () => {
  const author = await pgLib.queryOne<{ id: string }>(
    "SELECT id::text AS id FROM users WHERE user_id = $1",
    [userA]
  );
  assert.ok(author?.id);

  const originalUuid = "30000000-0000-0000-0000-000000000001";
  await pgLib.query(
    `INSERT INTO posts (post_id, id, author_id, author_uuid, body, media_urls, mentions, hashtags, post_type, created_at, updated_at)
     VALUES ('domain_original', $1, $2, $3, 'original', '[]', '[]', '[]', 'post', now(), now())`,
    [originalUuid, userA, author.id]
  );

  await pgLib.query(
    `INSERT INTO posts (post_id, id, author_id, author_uuid, body, media_urls, mentions, hashtags, post_type, repost_of_post_uuid, created_at, updated_at)
     VALUES ('domain_repost_1', '30000000-0000-0000-0000-000000000002', $1, $2, '', '[]', '[]', '[]', 'repost', $3, now(), now())`,
    [userA, author.id, originalUuid]
  );

  await assert.rejects(() =>
    pgLib.query(
      `INSERT INTO posts (post_id, id, author_id, author_uuid, body, media_urls, mentions, hashtags, post_type, repost_of_post_uuid, created_at, updated_at)
       VALUES ('domain_repost_2', '30000000-0000-0000-0000-000000000003', $1, $2, '', '[]', '[]', '[]', 'repost', $3, now(), now())`,
      [userA, author.id, originalUuid]
    )
  );
});

test("chat domain prevents duplicate client message ids in one conversation", async () => {
  const sender = await pgLib.queryOne<{ id: string }>(
    "SELECT id::text AS id FROM users WHERE user_id = $1",
    [userA]
  );
  assert.ok(sender?.id);

  const conversationUuid = "40000000-0000-0000-0000-000000000001";
  const clientMessageId = "40000000-0000-0000-0000-0000000000aa";
  await pgLib.query(
    `INSERT INTO conversations (conversation_id, id, type, created_at, updated_at)
     VALUES ('domain_conversation', $1, 'dm', now(), now())`,
    [conversationUuid]
  );
  await pgLib.query(
    `INSERT INTO messages (
      message_id, message_uuid, conversation_id, conversation_uuid, sender_user_id, sender_uuid,
      seq, sequence_id, body, client_message_id, created_at, updated_at
    ) VALUES (
      'domain_message_1', '40000000-0000-0000-0000-000000000101',
      'domain_conversation', $1, $2, $3, 1, 1, 'hello', $4, now(), now()
    )`,
    [conversationUuid, userA, sender.id, clientMessageId]
  );

  await assert.rejects(() =>
    pgLib.query(
      `INSERT INTO messages (
        message_id, message_uuid, conversation_id, conversation_uuid, sender_user_id, sender_uuid,
        seq, sequence_id, body, client_message_id, created_at, updated_at
      ) VALUES (
        'domain_message_2', '40000000-0000-0000-0000-000000000102',
        'domain_conversation', $1, $2, $3, 2, 2, 'duplicate retry', $4, now(), now()
      )`,
      [conversationUuid, userA, sender.id, clientMessageId]
    )
  );
});

test("notification delivery attempts and batches are writable", async () => {
  const recipient = await pgLib.queryOne<{ id: string }>(
    "SELECT id::text AS id FROM users WHERE user_id = $1",
    [userB]
  );
  assert.ok(recipient?.id);

  const notificationUuid = "50000000-0000-0000-0000-000000000001";
  await pgLib.query(
    `INSERT INTO notifications (notification_id, notification_uuid, user_id, recipient_uuid, type, notification_type, title, body, data, created_at)
     VALUES ('domain_notification', $1, $2, $3, 'mention', 'mention', 'Mention', 'You were mentioned', '{}', now())`,
    [notificationUuid, userB, recipient.id]
  );
  await pgLib.query(
    `INSERT INTO notification_delivery_attempts (notification_id, channel, provider, status, attempted_at)
     VALUES ($1, 'push', 'test', 'sent', now())`,
    [notificationUuid]
  );
  await pgLib.query(
    `INSERT INTO notification_batches (id, recipient_id, batch_type, status, payload, scheduled_for)
     VALUES ('50000000-0000-0000-0000-000000000002', $1, 'daily_digest', 'pending', '{}', now())`,
    [recipient.id]
  );

  const count = await pgLib.queryOne<{ count: string }>(
    "SELECT count(*)::text AS count FROM notification_delivery_attempts WHERE notification_id = $1",
    [notificationUuid]
  );
  assert.equal(count?.count, "1");
});

test("feature overrides and retention policies are constrained", async () => {
  await pgLib.query(
    `INSERT INTO feature_flag_overrides (flag_key, subject_type, subject_key, enabled, config_json)
     VALUES ('for_you_feed', 'user', $1, true, '{}')`,
    [userA]
  );
  await assert.rejects(() =>
    pgLib.query(
      `INSERT INTO feature_flag_overrides (flag_key, subject_type, subject_key, enabled, config_json)
       VALUES ('for_you_feed', 'user', $1, false, '{}')`,
      [userA]
    )
  );

  await pgLib.query(
    `INSERT INTO retention_policies (policy_key, table_name, retention_days, action)
     VALUES ('feed_events_raw', 'feed_events', 180, 'delete')
     ON CONFLICT (policy_key) DO UPDATE SET retention_days = EXCLUDED.retention_days`
  );
  await pgLib.query(
    `INSERT INTO retention_job_runs (policy_key, status, rows_affected)
     VALUES ('feed_events_raw', 'completed', 0)`
  );

  const policy = await pgLib.queryOne<{ retention_days: number }>(
    "SELECT retention_days FROM retention_policies WHERE policy_key = 'feed_events_raw'"
  );
  assert.equal(policy?.retention_days, 180);
});
