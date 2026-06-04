import pg from "pg";

import { env } from "../config/env.js";

const { Pool } = pg;

let pool: pg.Pool | undefined;

export async function connectPg(): Promise<pg.Pool> {
  if (pool) {
    return pool;
  }

  pool = new Pool({
    connectionString: env.DATABASE_URL,
    max: env.PG_POOL_MAX,
    idleTimeoutMillis: env.PG_POOL_IDLE_TIMEOUT_MS,
    connectionTimeoutMillis: env.PG_CONNECT_TIMEOUT_MS,
    statement_timeout: env.PG_STATEMENT_TIMEOUT_MS,
    ssl: env.DATABASE_URL.includes("supabase")
      ? { rejectUnauthorized: false }
      : undefined,
  });

  // Verify connectivity
  const client = await pool.connect();
  try {
    await client.query("SELECT 1");
  } finally {
    client.release();
  }

  await runMigrations(pool);
  return pool;
}

export function getPool(): pg.Pool {
  if (!pool) {
    throw new Error("PostgreSQL is not connected");
  }
  return pool;
}

export async function closePg(): Promise<void> {
  if (pool) {
    await pool.end();
  }
  pool = undefined;
}

export function setPgPoolForTest(nextPool: pg.Pool | undefined): void {
  pool = nextPool;
}

// Query helpers
export async function query<T extends pg.QueryResultRow = any>(
  text: string,
  params?: unknown[]
): Promise<pg.QueryResult<T>> {
  return getPool().query<T>(text, params);
}

export async function queryOne<T extends pg.QueryResultRow = any>(
  text: string,
  params?: unknown[]
): Promise<T | null> {
  const result = await query<T>(text, params);
  return result.rows[0] ?? null;
}

export async function queryMany<T extends pg.QueryResultRow = any>(
  text: string,
  params?: unknown[]
): Promise<T[]> {
  const result = await query<T>(text, params);
  return result.rows;
}

// Transaction helper
export async function withTransaction<T>(
  fn: (client: pg.PoolClient) => Promise<T>
): Promise<T> {
  const client = await getPool().connect();
  try {
    await client.query("BEGIN");
    const result = await fn(client);
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

// Schema migrations
export async function runMigrations(p: pg.Pool): Promise<void> {
  await p.query(`
    -- USERS & AUTH
    CREATE TABLE IF NOT EXISTS users (
      user_id         TEXT PRIMARY KEY,
      email           TEXT NOT NULL,
      email_lower     TEXT NOT NULL UNIQUE,
      username        TEXT NOT NULL,
      username_lower  TEXT NOT NULL UNIQUE,
      display_name    TEXT NOT NULL DEFAULT '',
      display_name_lower TEXT NOT NULL DEFAULT '',
      password_hash   TEXT NOT NULL,
      bio             TEXT NOT NULL DEFAULT '',
      location        TEXT NOT NULL DEFAULT '',
      website         TEXT NOT NULL DEFAULT '',
      avatar_url      TEXT NOT NULL DEFAULT '',
      cover_url       TEXT NOT NULL DEFAULT '',
      details         JSONB DEFAULT NULL,
      is_verified     BOOLEAN NOT NULL DEFAULT FALSE,
      email_verified_at TIMESTAMPTZ DEFAULT NULL,
      deleted_at      TIMESTAMPTZ DEFAULT NULL,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      last_seen_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    ALTER TABLE users ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
    CREATE INDEX IF NOT EXISTS idx_users_display_name_lower ON users (display_name_lower);
    CREATE INDEX IF NOT EXISTS idx_users_created_at ON users (created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_users_last_seen_at ON users (last_seen_at DESC);

    CREATE TABLE IF NOT EXISTS refresh_tokens (
      id              BIGSERIAL PRIMARY KEY,
      refresh_token_id TEXT NOT NULL,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      device_id       TEXT NOT NULL DEFAULT '',
      device_name     TEXT NOT NULL DEFAULT '',
      platform        TEXT NOT NULL DEFAULT '',
      token_hash      TEXT NOT NULL,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      last_seen_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      expires_at      TIMESTAMPTZ NOT NULL,
      revoked_at      TIMESTAMPTZ DEFAULT NULL,
      UNIQUE(token_hash, device_id)
    );
    CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens (user_id, revoked_at, expires_at);

    CREATE TABLE IF NOT EXISTS email_otp_tokens (
      id              BIGSERIAL PRIMARY KEY,
      email_lower     TEXT NOT NULL,
      token_hash      TEXT NOT NULL,
      attempts        INT NOT NULL DEFAULT 0,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      expires_at      TIMESTAMPTZ NOT NULL,
      used_at         TIMESTAMPTZ DEFAULT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_email_otp_email ON email_otp_tokens (email_lower, created_at DESC);

    CREATE TABLE IF NOT EXISTS username_reservations (
      username_lower  TEXT PRIMARY KEY,
      email_lower     TEXT NOT NULL,
      purpose         TEXT NOT NULL DEFAULT 'signup',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      expires_at      TIMESTAMPTZ NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_username_res_email ON username_reservations (email_lower, expires_at DESC);

    CREATE TABLE IF NOT EXISTS password_reset_tokens (
      id              BIGSERIAL PRIMARY KEY,
      reset_token_id  TEXT NOT NULL,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      email_lower     TEXT NOT NULL,
      token_hash      TEXT NOT NULL UNIQUE,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      expires_at      TIMESTAMPTZ NOT NULL,
      used_at         TIMESTAMPTZ DEFAULT NULL
    );

    -- SOCIAL GRAPH
    CREATE TABLE IF NOT EXISTS follows (
      follower_id     TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      following_id    TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (follower_id, following_id)
    );
    CREATE INDEX IF NOT EXISTS idx_follows_following ON follows (following_id, follower_id);

    CREATE TABLE IF NOT EXISTS user_blocks (
      blocker_id      TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      blocked_id      TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (blocker_id, blocked_id)
    );
    CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker ON user_blocks (blocker_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS user_muted_words (
      id              BIGSERIAL PRIMARY KEY,
      muted_word_id   TEXT NOT NULL,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      phrase          TEXT NOT NULL,
      phrase_lower    TEXT NOT NULL,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE(user_id, phrase_lower)
    );

    -- USER SETTINGS
    CREATE TABLE IF NOT EXISTS user_settings (
      user_id         TEXT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
      settings        JSONB NOT NULL DEFAULT '{}',
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    -- FEED & CONTENT
    CREATE TABLE IF NOT EXISTS posts (
      post_id         TEXT PRIMARY KEY,
      author_id       TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      body            TEXT NOT NULL DEFAULT '',
      media_urls      JSONB NOT NULL DEFAULT '[]',
      mentions        JSONB NOT NULL DEFAULT '[]',
      hashtags        JSONB NOT NULL DEFAULT '[]',
      like_count      INT NOT NULL DEFAULT 0,
      comment_count   INT NOT NULL DEFAULT 0,
      share_count     INT NOT NULL DEFAULT 0,
      share_of_post_id TEXT DEFAULT NULL,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_posts_author ON posts (author_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_posts_created ON posts (created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_posts_share ON posts (share_of_post_id, author_id);

    CREATE TABLE IF NOT EXISTS post_tags (
      post_id         TEXT NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
      tag             TEXT NOT NULL,
      author_id       TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (post_id, tag)
    );
    CREATE INDEX IF NOT EXISTS idx_post_tags_tag_created ON post_tags (tag, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_post_tags_author ON post_tags (author_id, tag);

    CREATE TABLE IF NOT EXISTS tag_stats (
      tag             TEXT PRIMARY KEY,
      post_count      INT NOT NULL DEFAULT 0,
      last_post_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_tag_stats_rank ON tag_stats (post_count DESC, last_post_at DESC);

    CREATE TABLE IF NOT EXISTS post_likes (
      post_id         TEXT NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (post_id, user_id)
    );
    CREATE INDEX IF NOT EXISTS idx_post_likes_user ON post_likes (user_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS comments (
      comment_id      TEXT PRIMARY KEY,
      post_id         TEXT NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
      author_id       TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      body            TEXT NOT NULL DEFAULT '',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_comments_post ON comments (post_id, created_at DESC);

    -- MESSAGING
    CREATE TABLE IF NOT EXISTS conversations (
      conversation_id TEXT PRIMARY KEY,
      type            TEXT NOT NULL DEFAULT 'dm' CHECK (type IN ('dm', 'group')),
      title           TEXT DEFAULT NULL,
      member_hash     TEXT UNIQUE DEFAULT NULL,
      owner_user_id   TEXT DEFAULT NULL,
      seq_counter     INT NOT NULL DEFAULT 0,
      last_message_id TEXT DEFAULT NULL,
      last_message_seq INT DEFAULT NULL,
      last_message_sender_user_id TEXT DEFAULT NULL,
      last_message_body TEXT DEFAULT NULL,
      last_message_content_type TEXT DEFAULT NULL,
      last_message_deleted_for_all_at TIMESTAMPTZ DEFAULT NULL,
      last_message_created_at TIMESTAMPTZ DEFAULT NULL,
      last_message_edit_version INT NOT NULL DEFAULT 0,
      dm_request_status TEXT NOT NULL DEFAULT 'active',
      dm_request_sender_user_id TEXT DEFAULT NULL,
      dm_request_recipient_user_id TEXT DEFAULT NULL,
      dm_request_responded_at TIMESTAMPTZ DEFAULT NULL,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    ALTER TABLE conversations ADD COLUMN IF NOT EXISTS dm_request_status TEXT NOT NULL DEFAULT 'active';
    ALTER TABLE conversations ADD COLUMN IF NOT EXISTS dm_request_sender_user_id TEXT DEFAULT NULL;
    ALTER TABLE conversations ADD COLUMN IF NOT EXISTS dm_request_recipient_user_id TEXT DEFAULT NULL;
    ALTER TABLE conversations ADD COLUMN IF NOT EXISTS dm_request_responded_at TIMESTAMPTZ DEFAULT NULL;
    CREATE INDEX IF NOT EXISTS idx_conversations_updated ON conversations (updated_at DESC);
    CREATE INDEX IF NOT EXISTS idx_conversations_dm_requests ON conversations (dm_request_recipient_user_id, dm_request_status, updated_at DESC);

    CREATE TABLE IF NOT EXISTS conversation_members (
      conversation_id TEXT NOT NULL REFERENCES conversations(conversation_id) ON DELETE CASCADE,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      role            TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
      joined_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      left_at         TIMESTAMPTZ DEFAULT NULL,
      PRIMARY KEY (conversation_id, user_id)
    );
    CREATE INDEX IF NOT EXISTS idx_conv_members_user ON conversation_members (user_id, left_at);

    CREATE TABLE IF NOT EXISTS messages (
      id              BIGSERIAL PRIMARY KEY,
      message_id      TEXT NOT NULL UNIQUE,
      conversation_id TEXT NOT NULL REFERENCES conversations(conversation_id) ON DELETE CASCADE,
      sender_user_id  TEXT NOT NULL,
      sender_device_id TEXT NOT NULL DEFAULT '',
      seq             INT NOT NULL,
      content_type    TEXT NOT NULL DEFAULT 'text',
      body            TEXT NOT NULL DEFAULT '',
      reply_to_message_id TEXT DEFAULT NULL,
      media_asset_id  TEXT DEFAULT NULL,
      client_timestamp TEXT DEFAULT NULL,
      edit_version    INT NOT NULL DEFAULT 0,
      deleted_for_all_at TIMESTAMPTZ DEFAULT NULL,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE(conversation_id, seq)
    );
    CREATE INDEX IF NOT EXISTS idx_messages_conv_created ON messages (conversation_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS message_reactions (
      message_id      TEXT NOT NULL,
      user_id         TEXT NOT NULL,
      emoji           TEXT NOT NULL DEFAULT '',
      reacted_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (message_id, user_id)
    );

    CREATE TABLE IF NOT EXISTS conversation_reads (
      conversation_id TEXT NOT NULL,
      user_id         TEXT NOT NULL,
      last_read_seq   INT NOT NULL DEFAULT 0,
      last_delivered_seq INT NOT NULL DEFAULT 0,
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (conversation_id, user_id)
    );
    CREATE INDEX IF NOT EXISTS idx_conv_reads_user ON conversation_reads (user_id, conversation_id);

    CREATE TABLE IF NOT EXISTS conversation_user_preferences (
      conversation_id TEXT NOT NULL REFERENCES conversations(conversation_id) ON DELETE CASCADE,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      is_favorite     BOOLEAN NOT NULL DEFAULT FALSE,
      is_starred      BOOLEAN NOT NULL DEFAULT FALSE,
      is_muted        BOOLEAN NOT NULL DEFAULT FALSE,
      is_archived     BOOLEAN NOT NULL DEFAULT FALSE,
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (conversation_id, user_id)
    );
    CREATE INDEX IF NOT EXISTS idx_conv_preferences_user ON conversation_user_preferences (user_id, is_favorite, is_starred, updated_at DESC);

    -- E2EE CRYPTO
    CREATE TABLE IF NOT EXISTS crypto_devices (
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      device_id       TEXT NOT NULL,
      platform        TEXT NOT NULL DEFAULT 'unknown',
      identity_key    TEXT NOT NULL DEFAULT '',
      registration_id INT NOT NULL DEFAULT 0,
      signed_pre_key  JSONB DEFAULT NULL,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (user_id, device_id)
    );

    CREATE TABLE IF NOT EXISTS crypto_prekeys (
      id              BIGSERIAL PRIMARY KEY,
      user_id         TEXT NOT NULL,
      device_id       TEXT NOT NULL,
      key_id          INT NOT NULL,
      public_key      TEXT NOT NULL,
      is_used         BOOLEAN NOT NULL DEFAULT FALSE,
      used_at         TIMESTAMPTZ DEFAULT NULL,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE(user_id, device_id, key_id)
    );
    CREATE INDEX IF NOT EXISTS idx_prekeys_available ON crypto_prekeys (user_id, device_id, is_used, key_id);

    -- NOTIFICATIONS
    CREATE TABLE IF NOT EXISTS notifications (
      id              BIGSERIAL PRIMARY KEY,
      notification_id TEXT NOT NULL UNIQUE,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      actor_user_id   TEXT DEFAULT NULL,
      type            TEXT NOT NULL DEFAULT 'system',
      title           TEXT NOT NULL DEFAULT 'Notification',
      body            TEXT NOT NULL DEFAULT '',
      data            JSONB NOT NULL DEFAULT '{}',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      read_at         TIMESTAMPTZ DEFAULT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications (user_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications (user_id, read_at);

    -- SUPPORT & EXPORTS
    CREATE TABLE IF NOT EXISTS support_requests (
      id              BIGSERIAL PRIMARY KEY,
      support_id      TEXT NOT NULL UNIQUE,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      type            TEXT NOT NULL,
      category        TEXT DEFAULT NULL,
      score           INT DEFAULT NULL,
      include_logs    BOOLEAN NOT NULL DEFAULT FALSE,
      allow_contact   BOOLEAN NOT NULL DEFAULT TRUE,
      message         TEXT NOT NULL,
      status          TEXT NOT NULL DEFAULT 'open',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_support_user ON support_requests (user_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS data_exports (
      id              BIGSERIAL PRIMARY KEY,
      export_id       TEXT NOT NULL UNIQUE,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      status          TEXT NOT NULL DEFAULT 'pending',
      format          TEXT NOT NULL DEFAULT 'json',
      payload         JSONB NOT NULL DEFAULT '{}',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      completed_at    TIMESTAMPTZ DEFAULT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_data_exports_user ON data_exports (user_id, created_at DESC);

    -- MEDIA ASSETS (Cloudinary tracking)
    CREATE TABLE IF NOT EXISTS media_assets (
      asset_id        TEXT PRIMARY KEY,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      public_id       TEXT NOT NULL,
      url             TEXT NOT NULL,
      secure_url      TEXT NOT NULL,
      resource_type   TEXT NOT NULL DEFAULT 'image',
      format          TEXT NOT NULL DEFAULT '',
      width           INT DEFAULT NULL,
      height          INT DEFAULT NULL,
      bytes           BIGINT DEFAULT NULL,
      folder          TEXT NOT NULL DEFAULT '',
      context         TEXT NOT NULL DEFAULT 'general',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_media_user ON media_assets (user_id, created_at DESC);
  `);
}
