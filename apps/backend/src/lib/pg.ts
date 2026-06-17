import pg from "pg";

import { env } from "../config/env.js";
import { runDatabaseFoundationMigrations } from "./database-foundation.js";

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
      username_changed_at TIMESTAMPTZ DEFAULT NULL,
      deleted_at      TIMESTAMPTZ DEFAULT NULL,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      last_seen_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    ALTER TABLE users ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
    ALTER TABLE users ADD COLUMN IF NOT EXISTS username_changed_at TIMESTAMPTZ DEFAULT NULL;
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

    CREATE TABLE IF NOT EXISTS follow_requests (
      requester_id    TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      target_id       TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      status          TEXT NOT NULL DEFAULT 'pending',
      message         TEXT NOT NULL DEFAULT '',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      responded_at    TIMESTAMPTZ DEFAULT NULL,
      PRIMARY KEY (requester_id, target_id)
    );
    CREATE INDEX IF NOT EXISTS idx_follow_requests_target_status
      ON follow_requests (target_id, status, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_follow_requests_requester_status
      ON follow_requests (requester_id, status, created_at DESC);

    CREATE TABLE IF NOT EXISTS close_friends (
      owner_id        TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (owner_id, user_id)
    );
    CREATE INDEX IF NOT EXISTS idx_close_friends_user ON close_friends (user_id, owner_id);

    CREATE TABLE IF NOT EXISTS restricted_users (
      owner_id        TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      restricted_id   TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      reason          TEXT NOT NULL DEFAULT '',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (owner_id, restricted_id)
    );
    CREATE INDEX IF NOT EXISTS idx_restricted_users_restricted ON restricted_users (restricted_id, owner_id);

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

    CREATE TABLE IF NOT EXISTS profile_visibility_settings (
      user_id         TEXT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
      account_privacy TEXT NOT NULL DEFAULT 'public',
      posts_visibility TEXT NOT NULL DEFAULT 'everyone',
      replies_visibility TEXT NOT NULL DEFAULT 'everyone',
      media_visibility TEXT NOT NULL DEFAULT 'everyone',
      highlights_visibility TEXT NOT NULL DEFAULT 'everyone',
      about_visibility TEXT NOT NULL DEFAULT 'everyone',
      bio_visibility TEXT NOT NULL DEFAULT 'everyone',
      location_visibility TEXT NOT NULL DEFAULT 'friends',
      website_visibility TEXT NOT NULL DEFAULT 'everyone',
      birthday_visibility TEXT NOT NULL DEFAULT 'onlyMe',
      followers_list_visibility TEXT NOT NULL DEFAULT 'everyone',
      following_list_visibility TEXT NOT NULL DEFAULT 'everyone',
      friends_list_visibility TEXT NOT NULL DEFAULT 'friends',
      mutual_friends_visibility TEXT NOT NULL DEFAULT 'friends',
      profile_sharing_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      search_engine_visibility BOOLEAN NOT NULL DEFAULT FALSE,
      accent_color TEXT NOT NULL DEFAULT '',
      profile_theme TEXT NOT NULL DEFAULT 'default',
      cover_style TEXT NOT NULL DEFAULT 'standard',
      badge_visibility TEXT NOT NULL DEFAULT 'everyone',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS privacy_settings (
      user_id         TEXT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
      show_online_status BOOLEAN NOT NULL DEFAULT TRUE,
      show_last_active BOOLEAN NOT NULL DEFAULT TRUE,
      read_receipts_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      typing_indicator_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      activity_status_visibility TEXT NOT NULL DEFAULT 'friends',
      allow_find_by_username BOOLEAN NOT NULL DEFAULT TRUE,
      allow_find_by_email BOOLEAN NOT NULL DEFAULT FALSE,
      allow_find_by_phone BOOLEAN NOT NULL DEFAULT FALSE,
      suggest_profile_to_others BOOLEAN NOT NULL DEFAULT TRUE,
      contact_sync_enabled BOOLEAN NOT NULL DEFAULT FALSE,
      allow_mentions_from TEXT NOT NULL DEFAULT 'everyone',
      allow_tags_from TEXT NOT NULL DEFAULT 'everyone',
      review_tags_before_showing BOOLEAN NOT NULL DEFAULT FALSE,
      allow_reposts BOOLEAN NOT NULL DEFAULT TRUE,
      allow_quote_posts BOOLEAN NOT NULL DEFAULT TRUE,
      who_can_message TEXT NOT NULL DEFAULT 'everyone',
      message_requests_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      filter_unknown_senders BOOLEAN NOT NULL DEFAULT FALSE,
      hide_message_preview BOOLEAN NOT NULL DEFAULT FALSE,
      sensitive_content_filter BOOLEAN NOT NULL DEFAULT TRUE,
      blur_sensitive_media BOOLEAN NOT NULL DEFAULT TRUE,
      offensive_words_filter BOOLEAN NOT NULL DEFAULT TRUE,
      content_safety_level TEXT NOT NULL DEFAULT 'balanced',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS notification_settings (
      user_id         TEXT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
      push_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      in_app_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      email_enabled BOOLEAN NOT NULL DEFAULT FALSE,
      sms_enabled BOOLEAN NOT NULL DEFAULT FALSE,
      likes_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      comments_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      replies_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      reposts_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      quote_posts_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      mentions_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      tags_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      follows_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      follow_requests_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      friend_requests_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      friend_accepts_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      direct_messages_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      message_requests_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      group_messages_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      recommendations_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      trending_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      security_alerts_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      quiet_hours_enabled BOOLEAN NOT NULL DEFAULT FALSE,
      quiet_hours_start TEXT NOT NULL DEFAULT '22:00',
      quiet_hours_end TEXT NOT NULL DEFAULT '07:00',
      allow_important_alerts BOOLEAN NOT NULL DEFAULT TRUE,
      allow_message_exceptions BOOLEAN NOT NULL DEFAULT TRUE,
      notification_preview_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      sound_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      vibration_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      badge_count_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      lock_screen_preview_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS chat_settings (
      user_id         TEXT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
      who_can_message TEXT NOT NULL DEFAULT 'everyone',
      message_requests_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      filter_unknown_senders BOOLEAN NOT NULL DEFAULT FALSE,
      read_receipts_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      typing_indicators_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      online_status_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      show_last_seen BOOLEAN NOT NULL DEFAULT TRUE,
      who_can_add_to_groups TEXT NOT NULL DEFAULT 'friends',
      group_invite_approval_required BOOLEAN NOT NULL DEFAULT TRUE,
      allow_group_mentions BOOLEAN NOT NULL DEFAULT TRUE,
      group_notification_defaults TEXT NOT NULL DEFAULT 'all',
      chat_theme TEXT NOT NULL DEFAULT 'system',
      bubble_density TEXT NOT NULL DEFAULT 'comfortable',
      font_size TEXT NOT NULL DEFAULT 'default',
      timestamp_display TEXT NOT NULL DEFAULT 'compact',
      auto_download_images BOOLEAN NOT NULL DEFAULT TRUE,
      auto_download_videos BOOLEAN NOT NULL DEFAULT TRUE,
      auto_download_voice_notes BOOLEAN NOT NULL DEFAULT TRUE,
      data_saver_media BOOLEAN NOT NULL DEFAULT FALSE,
      enter_key_sends BOOLEAN NOT NULL DEFAULT FALSE,
      send_button_always_visible BOOLEAN NOT NULL DEFAULT TRUE,
      link_previews_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      default_reaction TEXT NOT NULL DEFAULT 'like',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS appearance_settings (
      user_id         TEXT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
      theme_mode TEXT NOT NULL DEFAULT 'system',
      accent_color TEXT NOT NULL DEFAULT 'pravaBlue',
      display_density TEXT NOT NULL DEFAULT 'comfortable',
      font_size TEXT NOT NULL DEFAULT 'default',
      bold_text BOOLEAN NOT NULL DEFAULT FALSE,
      reduce_animations BOOLEAN NOT NULL DEFAULT FALSE,
      blur_effects_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      haptic_feedback_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      premium_motion_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS accessibility_settings (
      user_id         TEXT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
      text_size TEXT NOT NULL DEFAULT 'default',
      high_contrast BOOLEAN NOT NULL DEFAULT FALSE,
      bold_text BOOLEAN NOT NULL DEFAULT FALSE,
      reduce_motion BOOLEAN NOT NULL DEFAULT FALSE,
      reduce_transparency BOOLEAN NOT NULL DEFAULT FALSE,
      larger_touch_targets BOOLEAN NOT NULL DEFAULT FALSE,
      screen_reader_enhanced_labels BOOLEAN NOT NULL DEFAULT TRUE,
      disable_autoplay BOOLEAN NOT NULL DEFAULT FALSE,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS ai_personalization_settings (
      user_id         TEXT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
      personalized_feed_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      ai_friend_suggestions_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      ai_post_recommendations_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      ai_smart_replies_enabled BOOLEAN NOT NULL DEFAULT FALSE,
      ai_profile_summary_enabled BOOLEAN NOT NULL DEFAULT FALSE,
      ai_safety_filtering_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      use_activity_for_ai BOOLEAN NOT NULL DEFAULT TRUE,
      use_posts_for_recommendations BOOLEAN NOT NULL DEFAULT TRUE,
      use_likes_for_recommendations BOOLEAN NOT NULL DEFAULT TRUE,
      use_chats_for_ai BOOLEAN NOT NULL DEFAULT FALSE,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS creator_settings (
      user_id         TEXT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
      creator_mode_enabled BOOLEAN NOT NULL DEFAULT FALSE,
      creator_category TEXT NOT NULL DEFAULT '',
      professional_account_enabled BOOLEAN NOT NULL DEFAULT FALSE,
      public_contact_button_enabled BOOLEAN NOT NULL DEFAULT FALSE,
      public_email TEXT NOT NULL DEFAULT '',
      show_creator_badge BOOLEAN NOT NULL DEFAULT FALSE,
      analytics_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      monetization_enabled BOOLEAN NOT NULL DEFAULT FALSE,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS security_settings (
      user_id         TEXT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
      two_factor_enabled BOOLEAN NOT NULL DEFAULT FALSE,
      login_alerts_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      suspicious_login_protection_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      trusted_devices_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      recovery_email_set BOOLEAN NOT NULL DEFAULT FALSE,
      recovery_phone_set BOOLEAN NOT NULL DEFAULT FALSE,
      app_lock_enabled BOOLEAN NOT NULL DEFAULT FALSE,
      biometrics_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS data_storage_settings (
      user_id         TEXT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
      data_saver_enabled BOOLEAN NOT NULL DEFAULT FALSE,
      auto_download_enabled BOOLEAN NOT NULL DEFAULT TRUE,
      auto_play_videos BOOLEAN NOT NULL DEFAULT TRUE,
      media_quality TEXT NOT NULL DEFAULT 'auto',
      clear_cache_metadata_at TIMESTAMPTZ DEFAULT NULL,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS friend_settings (
      user_id         TEXT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
      allow_friend_requests_from TEXT NOT NULL DEFAULT 'everyone',
      show_mutual_friend_activity BOOLEAN NOT NULL DEFAULT TRUE,
      people_you_may_know BOOLEAN NOT NULL DEFAULT TRUE,
      close_friends_notifications BOOLEAN NOT NULL DEFAULT TRUE,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS setting_audit_logs (
      id              TEXT PRIMARY KEY,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      setting_category TEXT NOT NULL,
      setting_key     TEXT NOT NULL DEFAULT '',
      old_value       JSONB NOT NULL DEFAULT 'null',
      new_value       JSONB NOT NULL DEFAULT 'null',
      changed_by      TEXT NOT NULL DEFAULT '',
      ip_address      TEXT NOT NULL DEFAULT '',
      user_agent      TEXT NOT NULL DEFAULT '',
      reason          TEXT NOT NULL DEFAULT '',
      sensitivity_level TEXT NOT NULL DEFAULT 'normal',
      changed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_setting_audit_user_changed ON setting_audit_logs (user_id, changed_at DESC);

    CREATE TABLE IF NOT EXISTS account_deletion_requests (
      request_id      TEXT PRIMARY KEY,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      request_type    TEXT NOT NULL DEFAULT 'delete',
      status          TEXT NOT NULL DEFAULT 'pending',
      reason          TEXT NOT NULL DEFAULT '',
      recovery_until  TIMESTAMPTZ DEFAULT NULL,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      canceled_at     TIMESTAMPTZ DEFAULT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_account_deletion_user_status ON account_deletion_requests (user_id, status, created_at DESC);

    CREATE TABLE IF NOT EXISTS support_tickets (
      ticket_id       TEXT PRIMARY KEY,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      issue_type      TEXT NOT NULL DEFAULT 'help',
      description     TEXT NOT NULL DEFAULT '',
      include_logs    BOOLEAN NOT NULL DEFAULT FALSE,
      status          TEXT NOT NULL DEFAULT 'open',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_support_tickets_user_created ON support_tickets (user_id, created_at DESC);

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
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS moderation_state TEXT NOT NULL DEFAULT 'active';
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS language TEXT NOT NULL DEFAULT '';
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS quality_score DOUBLE PRECISION NOT NULL DEFAULT 1;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS impression_count INT NOT NULL DEFAULT 0;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS post_type TEXT NOT NULL DEFAULT 'post';
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS parent_post_id TEXT DEFAULT NULL;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS original_post_id TEXT DEFAULT NULL;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS quote_post_id TEXT DEFAULT NULL;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS duplicate_fingerprint TEXT NOT NULL DEFAULT '';
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS visibility TEXT NOT NULL DEFAULT 'public';
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS sensitive_label TEXT NOT NULL DEFAULT '';
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS spam_score DOUBLE PRECISION NOT NULL DEFAULT 0;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS toxicity_score DOUBLE PRECISION NOT NULL DEFAULT 0;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS clickbait_score DOUBLE PRECISION NOT NULL DEFAULT 0;
    CREATE INDEX IF NOT EXISTS idx_posts_author ON posts (author_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_posts_created ON posts (created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_posts_share ON posts (share_of_post_id, author_id);
    CREATE INDEX IF NOT EXISTS idx_posts_recommendable ON posts (created_at DESC, author_id)
      WHERE deleted_at IS NULL AND moderation_state = 'active';
    CREATE INDEX IF NOT EXISTS idx_posts_language_created ON posts (language, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_posts_conversation ON posts (original_post_id, parent_post_id, created_at DESC);

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
    ALTER TABLE post_likes ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
    CREATE INDEX IF NOT EXISTS idx_post_likes_user ON post_likes (user_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS post_reads (
      post_id         TEXT NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      first_read_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      last_read_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (post_id, user_id)
    );
    CREATE INDEX IF NOT EXISTS idx_post_reads_post ON post_reads (post_id);
    CREATE INDEX IF NOT EXISTS idx_post_reads_user ON post_reads (user_id, last_read_at DESC);

    CREATE TABLE IF NOT EXISTS post_hidden (
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      post_id         TEXT NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
      reason          TEXT NOT NULL DEFAULT 'hidden',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (user_id, post_id)
    );
    CREATE INDEX IF NOT EXISTS idx_post_hidden_user_created ON post_hidden (user_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS post_saves (
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      post_id         TEXT NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (user_id, post_id)
    );
    CREATE INDEX IF NOT EXISTS idx_post_saves_user_created ON post_saves (user_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS post_not_interested (
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      post_id         TEXT NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
      reason          TEXT NOT NULL DEFAULT 'not_interested',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (user_id, post_id)
    );
    CREATE INDEX IF NOT EXISTS idx_post_not_interested_user_created ON post_not_interested (user_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS user_mutes (
      muter_id        TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      muted_id        TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (muter_id, muted_id)
    );
    CREATE INDEX IF NOT EXISTS idx_user_mutes_muter ON user_mutes (muter_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS feed_events (
      event_id        TEXT PRIMARY KEY,
      client_event_id TEXT DEFAULT NULL,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      post_id         TEXT DEFAULT NULL REFERENCES posts(post_id) ON DELETE SET NULL,
      author_id       TEXT DEFAULT NULL REFERENCES users(user_id) ON DELETE SET NULL,
      comment_id      TEXT DEFAULT NULL,
      event_type      TEXT NOT NULL,
      dwell_ms        INT NOT NULL DEFAULT 0,
      source          TEXT NOT NULL DEFAULT '',
      session_id      TEXT NOT NULL DEFAULT '',
      metadata        JSONB NOT NULL DEFAULT '{}',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_feed_events_user_client_event
      ON feed_events (user_id, client_event_id)
      WHERE client_event_id IS NOT NULL;
    CREATE INDEX IF NOT EXISTS idx_feed_events_user_created ON feed_events (user_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_feed_events_post_created ON feed_events (post_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_feed_events_type_created ON feed_events (event_type, created_at DESC);

    CREATE TABLE IF NOT EXISTS feed_impressions (
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      post_id         TEXT NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
      author_id       TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      source          TEXT NOT NULL DEFAULT '',
      reason          TEXT NOT NULL DEFAULT '',
      score           DOUBLE PRECISION NOT NULL DEFAULT 0,
      impression_count INT NOT NULL DEFAULT 1,
      total_dwell_ms  BIGINT NOT NULL DEFAULT 0,
      first_seen_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      last_seen_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      engaged_at      TIMESTAMPTZ DEFAULT NULL,
      negative_at     TIMESTAMPTZ DEFAULT NULL,
      PRIMARY KEY (user_id, post_id)
    );
    CREATE INDEX IF NOT EXISTS idx_feed_impressions_user_seen ON feed_impressions (user_id, last_seen_at DESC);
    CREATE INDEX IF NOT EXISTS idx_feed_impressions_post_seen ON feed_impressions (post_id, last_seen_at DESC);

    CREATE TABLE IF NOT EXISTS feed_served_history (
      id              BIGSERIAL PRIMARY KEY,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      post_id         TEXT NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
      session_id      TEXT NOT NULL DEFAULT '',
      source          TEXT NOT NULL DEFAULT '',
      reason          TEXT NOT NULL DEFAULT '',
      score           DOUBLE PRECISION NOT NULL DEFAULT 0,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_feed_served_unique_session
      ON feed_served_history (user_id, post_id, session_id);
    CREATE INDEX IF NOT EXISTS idx_feed_served_user_created ON feed_served_history (user_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS post_topics (
      post_id         TEXT NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
      topic           TEXT NOT NULL,
      weight          DOUBLE PRECISION NOT NULL DEFAULT 1,
      source          TEXT NOT NULL DEFAULT 'hashtag',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (post_id, topic)
    );
    CREATE INDEX IF NOT EXISTS idx_post_topics_topic_created ON post_topics (topic, created_at DESC);

    CREATE TABLE IF NOT EXISTS post_engagement_stats (
      post_id         TEXT PRIMARY KEY REFERENCES posts(post_id) ON DELETE CASCADE,
      impression_count INT NOT NULL DEFAULT 0,
      unique_impressions INT NOT NULL DEFAULT 0,
      like_count      INT NOT NULL DEFAULT 0,
      comment_count   INT NOT NULL DEFAULT 0,
      reply_count     INT NOT NULL DEFAULT 0,
      share_count     INT NOT NULL DEFAULT 0,
      bookmark_count  INT NOT NULL DEFAULT 0,
      click_count     INT NOT NULL DEFAULT 0,
      profile_click_count INT NOT NULL DEFAULT 0,
      total_dwell_ms  BIGINT NOT NULL DEFAULT 0,
      negative_count  INT NOT NULL DEFAULT 0,
      report_count    INT NOT NULL DEFAULT 0,
      unique_engaged_users INT NOT NULL DEFAULT 0,
      engagement_rate DOUBLE PRECISION NOT NULL DEFAULT 0,
      trend_velocity_score DOUBLE PRECISION NOT NULL DEFAULT 0,
      quality_score   DOUBLE PRECISION NOT NULL DEFAULT 1,
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_post_engagement_velocity ON post_engagement_stats (trend_velocity_score DESC, updated_at DESC);
    CREATE INDEX IF NOT EXISTS idx_post_engagement_quality ON post_engagement_stats (quality_score DESC, engagement_rate DESC);

    CREATE TABLE IF NOT EXISTS user_topic_affinities (
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      topic           TEXT NOT NULL,
      score           DOUBLE PRECISION NOT NULL DEFAULT 0,
      positive_count  INT NOT NULL DEFAULT 0,
      negative_count  INT NOT NULL DEFAULT 0,
      last_signal_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (user_id, topic)
    );
    CREATE INDEX IF NOT EXISTS idx_user_topic_affinity_rank ON user_topic_affinities (user_id, score DESC, last_signal_at DESC);

    CREATE TABLE IF NOT EXISTS user_author_affinities (
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      author_id       TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      score           DOUBLE PRECISION NOT NULL DEFAULT 0,
      positive_count  INT NOT NULL DEFAULT 0,
      negative_count  INT NOT NULL DEFAULT 0,
      last_signal_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (user_id, author_id)
    );
    CREATE INDEX IF NOT EXISTS idx_user_author_affinity_rank ON user_author_affinities (user_id, score DESC, last_signal_at DESC);

    CREATE TABLE IF NOT EXISTS post_trend_snapshots (
      id              BIGSERIAL PRIMARY KEY,
      post_id         TEXT NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
      window_minutes  INT NOT NULL,
      engagement_count INT NOT NULL DEFAULT 0,
      unique_user_count INT NOT NULL DEFAULT 0,
      velocity_score  DOUBLE PRECISION NOT NULL DEFAULT 0,
      captured_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_post_trend_snapshots_post_window ON post_trend_snapshots (post_id, window_minutes, captured_at DESC);

    CREATE TABLE IF NOT EXISTS trending_topics (
      topic           TEXT PRIMARY KEY,
      post_count      INT NOT NULL DEFAULT 0,
      engagement_count INT NOT NULL DEFAULT 0,
      velocity_score  DOUBLE PRECISION NOT NULL DEFAULT 0,
      language        TEXT NOT NULL DEFAULT '',
      region          TEXT NOT NULL DEFAULT '',
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_trending_topics_rank ON trending_topics (velocity_score DESC, engagement_count DESC, updated_at DESC);

    CREATE TABLE IF NOT EXISTS feed_algorithm_config (
      config_key      TEXT PRIMARY KEY,
      config_value    JSONB NOT NULL DEFAULT '{}',
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS feed_experiments (
      experiment_key  TEXT PRIMARY KEY,
      enabled         BOOLEAN NOT NULL DEFAULT FALSE,
      allocation      DOUBLE PRECISION NOT NULL DEFAULT 0,
      config          JSONB NOT NULL DEFAULT '{}',
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS topics (
      topic_id        TEXT PRIMARY KEY,
      slug            TEXT NOT NULL UNIQUE,
      name            TEXT NOT NULL,
      category        TEXT NOT NULL DEFAULT 'general',
      language        TEXT NOT NULL DEFAULT '',
      description     TEXT NOT NULL DEFAULT '',
      is_active       BOOLEAN NOT NULL DEFAULT TRUE,
      admin_curated   BOOLEAN NOT NULL DEFAULT FALSE,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_topics_active_category ON topics (is_active, category, slug);

    CREATE TABLE IF NOT EXISTS user_followed_topics (
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      topic           TEXT NOT NULL,
      followed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (user_id, topic)
    );
    CREATE INDEX IF NOT EXISTS idx_user_followed_topics_user ON user_followed_topics (user_id, followed_at DESC);

    CREATE TABLE IF NOT EXISTS feed_muted_topics (
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      topic           TEXT NOT NULL,
      reason          TEXT NOT NULL DEFAULT 'muted',
      snoozed_until   TIMESTAMPTZ DEFAULT NULL,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (user_id, topic)
    );
    CREATE INDEX IF NOT EXISTS idx_feed_muted_topics_user ON feed_muted_topics (user_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS feed_preferences (
      user_id         TEXT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
      lens            TEXT NOT NULL DEFAULT 'balanced',
      discovery_intensity DOUBLE PRECISION NOT NULL DEFAULT 0.22,
      friend_priority DOUBLE PRECISION NOT NULL DEFAULT 0.35,
      latest_priority DOUBLE PRECISION NOT NULL DEFAULT 0.15,
      reduce_reposts  BOOLEAN NOT NULL DEFAULT FALSE,
      reduce_political_content BOOLEAN NOT NULL DEFAULT FALSE,
      reduce_sensitive_content BOOLEAN NOT NULL DEFAULT TRUE,
      prefer_professional_content BOOLEAN NOT NULL DEFAULT FALSE,
      prefer_local_content BOOLEAN NOT NULL DEFAULT FALSE,
      local_discovery_enabled BOOLEAN NOT NULL DEFAULT FALSE,
      perspective_broadening_enabled BOOLEAN NOT NULL DEFAULT FALSE,
      preferred_languages JSONB NOT NULL DEFAULT '[]',
      muted_keywords  JSONB NOT NULL DEFAULT '[]',
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS feed_custom_feeds (
      feed_id         TEXT PRIMARY KEY,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      name            TEXT NOT NULL,
      definition      JSONB NOT NULL DEFAULT '{}',
      is_public       BOOLEAN NOT NULL DEFAULT FALSE,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_feed_custom_feeds_user ON feed_custom_feeds (user_id, updated_at DESC);

    CREATE TABLE IF NOT EXISTS feed_sessions (
      session_id      TEXT NOT NULL,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      mode            TEXT NOT NULL,
      lens            TEXT NOT NULL DEFAULT 'balanced',
      config_hash     TEXT NOT NULL DEFAULT 'default',
      post_ids        JSONB NOT NULL DEFAULT '[]',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      expires_at      TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 minutes'),
      PRIMARY KEY (session_id, user_id)
    );
    CREATE INDEX IF NOT EXISTS idx_feed_sessions_expiry ON feed_sessions (expires_at);

    CREATE TABLE IF NOT EXISTS feed_feedback (
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      post_id         TEXT NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
      feedback_type   TEXT NOT NULL,
      feedback_value  DOUBLE PRECISION NOT NULL DEFAULT 1,
      metadata        JSONB NOT NULL DEFAULT '{}',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (user_id, post_id, feedback_type)
    );
    CREATE INDEX IF NOT EXISTS idx_feed_feedback_user_created ON feed_feedback (user_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_feed_feedback_post_type ON feed_feedback (post_id, feedback_type);

    CREATE TABLE IF NOT EXISTS profile_links (
      link_id         TEXT PRIMARY KEY,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      title           TEXT NOT NULL DEFAULT '',
      url             TEXT NOT NULL,
      position        INT NOT NULL DEFAULT 0,
      visibility      TEXT NOT NULL DEFAULT 'public',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_profile_links_user_position
      ON profile_links (user_id, position ASC, created_at DESC);

    CREATE TABLE IF NOT EXISTS profile_badges (
      badge_id        TEXT PRIMARY KEY,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      badge_type      TEXT NOT NULL,
      label           TEXT NOT NULL,
      icon            TEXT NOT NULL DEFAULT '',
      awarded_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      expires_at      TIMESTAMPTZ DEFAULT NULL,
      visibility      TEXT NOT NULL DEFAULT 'public'
    );
    CREATE INDEX IF NOT EXISTS idx_profile_badges_user_awarded
      ON profile_badges (user_id, awarded_at DESC);

    CREATE TABLE IF NOT EXISTS profile_views (
      viewer_id       TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      profile_user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      view_count      INT NOT NULL DEFAULT 1,
      first_viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      last_viewed_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (viewer_id, profile_user_id)
    );
    CREATE INDEX IF NOT EXISTS idx_profile_views_profile_last
      ON profile_views (profile_user_id, last_viewed_at DESC);

    CREATE TABLE IF NOT EXISTS profile_highlights (
      highlight_id    TEXT PRIMARY KEY,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      title           TEXT NOT NULL DEFAULT '',
      description     TEXT NOT NULL DEFAULT '',
      cover_url       TEXT NOT NULL DEFAULT '',
      post_ids        JSONB NOT NULL DEFAULT '[]',
      media_urls      JSONB NOT NULL DEFAULT '[]',
      visibility      TEXT NOT NULL DEFAULT 'public',
      position        INT NOT NULL DEFAULT 0,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_profile_highlights_user_position
      ON profile_highlights (user_id, position ASC, created_at DESC);

    CREATE TABLE IF NOT EXISTS profile_pinned_posts (
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      post_id         TEXT NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
      position        INT NOT NULL DEFAULT 0,
      pinned_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (user_id, post_id)
    );
    CREATE INDEX IF NOT EXISTS idx_profile_pinned_posts_user_position
      ON profile_pinned_posts (user_id, position ASC, pinned_at DESC);

    CREATE TABLE IF NOT EXISTS profile_reports (
      report_id       TEXT PRIMARY KEY,
      reporter_user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      profile_user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      reason          TEXT NOT NULL DEFAULT 'other',
      details         TEXT NOT NULL DEFAULT '',
      status          TEXT NOT NULL DEFAULT 'open',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_profile_reports_profile_status
      ON profile_reports (profile_user_id, status, created_at DESC);

    CREATE TABLE IF NOT EXISTS editorial_feed_items (
      item_id         TEXT PRIMARY KEY,
      post_id         TEXT NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
      label           TEXT NOT NULL DEFAULT 'editorial',
      priority        DOUBLE PRECISION NOT NULL DEFAULT 0.5,
      starts_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      ends_at         TIMESTAMPTZ DEFAULT NULL,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_editorial_feed_active ON editorial_feed_items (starts_at, ends_at, priority DESC);

    INSERT INTO topics (topic_id, slug, name, category, language, admin_curated, created_at, updated_at)
    VALUES
      ('topic_technology', 'technology', 'Technology', 'professional', '', TRUE, NOW(), NOW()),
      ('topic_startups', 'startups', 'Startups', 'professional', '', TRUE, NOW(), NOW()),
      ('topic_coding', 'coding', 'Coding', 'professional', '', TRUE, NOW(), NOW()),
      ('topic_careers', 'careers', 'Careers', 'professional', '', TRUE, NOW(), NOW()),
      ('topic_sports', 'sports', 'Sports', 'general', '', TRUE, NOW(), NOW()),
      ('topic_entertainment', 'entertainment', 'Entertainment', 'general', '', TRUE, NOW(), NOW()),
      ('topic_education', 'education', 'Education', 'professional', '', TRUE, NOW(), NOW()),
      ('topic_local_news', 'local_news', 'Local News', 'local', '', TRUE, NOW(), NOW()),
      ('topic_art', 'art', 'Art', 'creative', '', TRUE, NOW(), NOW()),
      ('topic_literature', 'literature', 'Literature', 'creative', '', TRUE, NOW(), NOW()),
      ('topic_bengali_literature', 'bengali_literature', 'Bengali Literature', 'creative', 'bn', TRUE, NOW(), NOW())
    ON CONFLICT (slug) DO NOTHING;

    CREATE TABLE IF NOT EXISTS comments (
      comment_id      TEXT PRIMARY KEY,
      post_id         TEXT NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
      parent_comment_id TEXT DEFAULT NULL REFERENCES comments(comment_id) ON DELETE CASCADE,
      author_id       TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      body            TEXT NOT NULL DEFAULT '',
      like_count      INT NOT NULL DEFAULT 0,
      reply_count     INT NOT NULL DEFAULT 0,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    ALTER TABLE comments ADD COLUMN IF NOT EXISTS parent_comment_id TEXT DEFAULT NULL;
    ALTER TABLE comments ADD COLUMN IF NOT EXISTS like_count INT NOT NULL DEFAULT 0;
    ALTER TABLE comments ADD COLUMN IF NOT EXISTS reply_count INT NOT NULL DEFAULT 0;
    CREATE INDEX IF NOT EXISTS idx_comments_post ON comments (post_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_comments_parent ON comments (parent_comment_id, created_at ASC);

    CREATE TABLE IF NOT EXISTS comment_likes (
      comment_id      TEXT NOT NULL REFERENCES comments(comment_id) ON DELETE CASCADE,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (comment_id, user_id)
    );
    ALTER TABLE comment_likes ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
    CREATE INDEX IF NOT EXISTS idx_comment_likes_user ON comment_likes (user_id, created_at DESC);

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
    ALTER TABLE messages ADD COLUMN IF NOT EXISTS client_message_id UUID DEFAULT NULL;
    CREATE INDEX IF NOT EXISTS idx_messages_conv_created ON messages (conversation_id, created_at DESC);
    CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_legacy_client_dedupe
      ON messages (conversation_id, sender_user_id, client_message_id)
      WHERE client_message_id IS NOT NULL;

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
      marked_unread   BOOLEAN NOT NULL DEFAULT FALSE,
      draft_text      TEXT NOT NULL DEFAULT '',
      draft_updated_at TIMESTAMPTZ DEFAULT NULL,
      cleared_before_seq INT NOT NULL DEFAULT 0,
      local_deleted_at TIMESTAMPTZ DEFAULT NULL,
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (conversation_id, user_id)
    );
    ALTER TABLE conversation_user_preferences ADD COLUMN IF NOT EXISTS marked_unread BOOLEAN NOT NULL DEFAULT FALSE;
    ALTER TABLE conversation_user_preferences ADD COLUMN IF NOT EXISTS draft_text TEXT NOT NULL DEFAULT '';
    ALTER TABLE conversation_user_preferences ADD COLUMN IF NOT EXISTS draft_updated_at TIMESTAMPTZ DEFAULT NULL;
    ALTER TABLE conversation_user_preferences ADD COLUMN IF NOT EXISTS cleared_before_seq INT NOT NULL DEFAULT 0;
    ALTER TABLE conversation_user_preferences ADD COLUMN IF NOT EXISTS local_deleted_at TIMESTAMPTZ DEFAULT NULL;
    CREATE INDEX IF NOT EXISTS idx_conv_preferences_user ON conversation_user_preferences (user_id, is_favorite, is_starred, updated_at DESC);
    CREATE INDEX IF NOT EXISTS idx_conv_preferences_archived ON conversation_user_preferences (user_id, is_archived, updated_at DESC);
    CREATE INDEX IF NOT EXISTS idx_conv_preferences_local_deleted
      ON conversation_user_preferences (user_id, local_deleted_at, cleared_before_seq);

    CREATE TABLE IF NOT EXISTS chat_pinned_messages (
      conversation_id TEXT NOT NULL REFERENCES conversations(conversation_id) ON DELETE CASCADE,
      message_id      TEXT NOT NULL REFERENCES messages(message_id) ON DELETE CASCADE,
      pinned_by_user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      pinned_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (conversation_id, message_id)
    );
    CREATE INDEX IF NOT EXISTS idx_chat_pinned_messages_conversation
      ON chat_pinned_messages (conversation_id, pinned_at DESC);

    CREATE TABLE IF NOT EXISTS chat_saved_messages (
      conversation_id TEXT NOT NULL REFERENCES conversations(conversation_id) ON DELETE CASCADE,
      message_id      TEXT NOT NULL REFERENCES messages(message_id) ON DELETE CASCADE,
      user_id         TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      saved_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      note            TEXT NOT NULL DEFAULT '',
      PRIMARY KEY (conversation_id, message_id, user_id)
    );
    CREATE INDEX IF NOT EXISTS idx_chat_saved_messages_user
      ON chat_saved_messages (user_id, saved_at DESC);
    CREATE INDEX IF NOT EXISTS idx_chat_saved_messages_conversation
      ON chat_saved_messages (conversation_id, user_id, saved_at DESC);

    CREATE TABLE IF NOT EXISTS chat_reports (
      report_id       TEXT PRIMARY KEY,
      reporter_user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      conversation_id TEXT DEFAULT NULL REFERENCES conversations(conversation_id) ON DELETE CASCADE,
      message_id      TEXT DEFAULT NULL REFERENCES messages(message_id) ON DELETE SET NULL,
      reported_user_id TEXT DEFAULT NULL REFERENCES users(user_id) ON DELETE SET NULL,
      reason          TEXT NOT NULL DEFAULT 'other',
      details         TEXT NOT NULL DEFAULT '',
      status          TEXT NOT NULL DEFAULT 'open',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_chat_reports_conversation
      ON chat_reports (conversation_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_chat_reports_status
      ON chat_reports (status, created_at DESC);

    CREATE TABLE IF NOT EXISTS group_invites (
      invite_id       TEXT PRIMARY KEY,
      conversation_id TEXT NOT NULL REFERENCES conversations(conversation_id) ON DELETE CASCADE,
      invite_token    TEXT NOT NULL UNIQUE,
      created_by_user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      max_uses        INT DEFAULT NULL,
      use_count       INT NOT NULL DEFAULT 0,
      requires_approval BOOLEAN NOT NULL DEFAULT FALSE,
      status          TEXT NOT NULL DEFAULT 'active',
      expires_at      TIMESTAMPTZ DEFAULT NULL,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      revoked_at      TIMESTAMPTZ DEFAULT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_group_invites_conversation
      ON group_invites (conversation_id, status, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_group_invites_token
      ON group_invites (invite_token);

    CREATE TABLE IF NOT EXISTS group_join_requests (
      request_id      TEXT PRIMARY KEY,
      invite_id       TEXT DEFAULT NULL REFERENCES group_invites(invite_id) ON DELETE SET NULL,
      conversation_id TEXT NOT NULL REFERENCES conversations(conversation_id) ON DELETE CASCADE,
      requester_user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      status          TEXT NOT NULL DEFAULT 'pending',
      decided_by_user_id TEXT DEFAULT NULL REFERENCES users(user_id) ON DELETE SET NULL,
      decided_at      TIMESTAMPTZ DEFAULT NULL,
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE(conversation_id, requester_user_id, status)
    );
    CREATE INDEX IF NOT EXISTS idx_group_join_requests_conversation
      ON group_join_requests (conversation_id, status, created_at DESC);

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

    CREATE TABLE IF NOT EXISTS chat_attachments (
      attachment_id   TEXT PRIMARY KEY,
      owner_user_id   TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
      conversation_id TEXT DEFAULT NULL REFERENCES conversations(conversation_id) ON DELETE CASCADE,
      message_id      TEXT DEFAULT NULL REFERENCES messages(message_id) ON DELETE SET NULL,
      media_asset_id  TEXT DEFAULT NULL REFERENCES media_assets(asset_id) ON DELETE SET NULL,
      upload_session_id TEXT NOT NULL UNIQUE,
      attachment_type TEXT NOT NULL DEFAULT 'file',
      file_name       TEXT NOT NULL DEFAULT '',
      mime_type       TEXT NOT NULL DEFAULT 'application/octet-stream',
      byte_size       BIGINT NOT NULL DEFAULT 0,
      status          TEXT NOT NULL DEFAULT 'pending',
      metadata        JSONB NOT NULL DEFAULT '{}',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      deleted_at      TIMESTAMPTZ DEFAULT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_chat_attachments_owner
      ON chat_attachments (owner_user_id, status, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_chat_attachments_conversation
      ON chat_attachments (conversation_id, created_at DESC);
  `);

  await runDatabaseFoundationMigrations(p);

  // ── Phase 1: Add all missing columns (DDL only) ──
  // Must be a separate query() so PostgreSQL parses later statements
  // AFTER these columns exist.
  await p.query(`
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS notification_type VARCHAR(48);
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS recipient_uuid UUID;
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS actor_uuid UUID;
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS recipient_user_id UUID;
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS actor_internal_user_id UUID;
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS aggregation_key TEXT;
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS idempotency_key TEXT;
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS priority TEXT NOT NULL DEFAULT 'normal';
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS dismissed_at TIMESTAMPTZ DEFAULT NULL;
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS entity_id TEXT DEFAULT NULL;
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS push_eligible BOOLEAN NOT NULL DEFAULT TRUE;
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS preference_category TEXT NOT NULL DEFAULT 'system';
  `);

  // Ensure notification_preferences table exists with notification_type column
  // (may have been created by older migration without it)
  await p.query(`
    CREATE TABLE IF NOT EXISTS notification_preferences (
      user_id UUID,
      channel VARCHAR(24),
      notification_type VARCHAR(64),
      enabled BOOLEAN,
      quiet_hours_start TIME,
      quiet_hours_end TIME,
      updated_at TIMESTAMPTZ
    );
    ALTER TABLE notification_preferences ADD COLUMN IF NOT EXISTS notification_type VARCHAR(64);
    ALTER TABLE notification_preferences ADD COLUMN IF NOT EXISTS preference_category TEXT;
    ALTER TABLE notification_preferences ADD COLUMN IF NOT EXISTS in_app_enabled BOOLEAN NOT NULL DEFAULT TRUE;
    ALTER TABLE notification_preferences ADD COLUMN IF NOT EXISTS push_enabled BOOLEAN NOT NULL DEFAULT TRUE;
    ALTER TABLE notification_preferences ADD COLUMN IF NOT EXISTS email_enabled BOOLEAN NOT NULL DEFAULT FALSE;
    ALTER TABLE notification_preferences ADD COLUMN IF NOT EXISTS quiet_hours_enabled BOOLEAN NOT NULL DEFAULT FALSE;
    ALTER TABLE notification_preferences ADD COLUMN IF NOT EXISTS timezone TEXT NOT NULL DEFAULT 'UTC';
    ALTER TABLE notification_preferences ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
    CREATE UNIQUE INDEX IF NOT EXISTS idx_notification_preferences_user_channel_type
      ON notification_preferences (user_id, channel, notification_type);

    ALTER TABLE user_devices ADD COLUMN IF NOT EXISTS public_device_id TEXT;
    ALTER TABLE user_devices ADD COLUMN IF NOT EXISTS push_provider TEXT NOT NULL DEFAULT 'fcm';
    ALTER TABLE user_devices ADD COLUMN IF NOT EXISTS push_token TEXT;
    ALTER TABLE user_devices ADD COLUMN IF NOT EXISTS token_refreshed_at TIMESTAMPTZ;
    ALTER TABLE user_devices ADD COLUMN IF NOT EXISTS invalidated_at TIMESTAMPTZ;

    ALTER TABLE outbox_events ADD COLUMN IF NOT EXISTS locked_at TIMESTAMPTZ;
    ALTER TABLE outbox_events ADD COLUMN IF NOT EXISTS locked_by TEXT;
    ALTER TABLE outbox_events ADD COLUMN IF NOT EXISTS published_at TIMESTAMPTZ;
  `);

  // ── Phase 2: Backfill data & create indexes/tables that reference new columns ──
  await p.query(`
    UPDATE notifications
       SET recipient_user_id = users.id
      FROM users
     WHERE notifications.user_id = users.user_id
       AND notifications.recipient_user_id IS NULL;
    UPDATE notifications
       SET actor_internal_user_id = users.id
      FROM users
     WHERE notifications.actor_user_id = users.user_id
       AND notifications.actor_internal_user_id IS NULL;
    UPDATE notifications SET notification_type = type WHERE notification_type IS NULL;
    UPDATE notifications SET recipient_uuid = recipient_user_id WHERE recipient_uuid IS NULL AND recipient_user_id IS NOT NULL;
    UPDATE notifications SET actor_uuid = actor_internal_user_id WHERE actor_uuid IS NULL AND actor_internal_user_id IS NOT NULL;
    CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_idempotency_unique_full
      ON notifications (idempotency_key);
    CREATE INDEX IF NOT EXISTS idx_notifications_inbox_cursor
      ON notifications (recipient_user_id, created_at DESC, notification_id DESC);
    CREATE INDEX IF NOT EXISTS idx_notifications_unread_cursor
      ON notifications (recipient_user_id, created_at DESC, notification_id DESC)
      WHERE read_at IS NULL;
    CREATE INDEX IF NOT EXISTS idx_notifications_expires
      ON notifications (expires_at)
      WHERE expires_at IS NOT NULL;
    CREATE INDEX IF NOT EXISTS idx_notifications_type_recipient
      ON notifications (recipient_user_id, notification_type, created_at DESC);

    CREATE TABLE IF NOT EXISTS notification_outbox (
      event_id UUID PRIMARY KEY,
      event_type TEXT NOT NULL,
      actor_user_id UUID DEFAULT NULL,
      recipient_user_id UUID DEFAULT NULL,
      entity_type TEXT DEFAULT NULL,
      entity_id TEXT DEFAULT NULL,
      payload JSONB NOT NULL DEFAULT '{}',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      published_at TIMESTAMPTZ DEFAULT NULL,
      attempt_count INT NOT NULL DEFAULT 0,
      last_error TEXT DEFAULT NULL,
      locked_at TIMESTAMPTZ DEFAULT NULL,
      locked_by TEXT DEFAULT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_notification_outbox_unpublished
      ON notification_outbox (published_at, created_at)
      WHERE published_at IS NULL;
    CREATE INDEX IF NOT EXISTS idx_notification_outbox_locked
      ON notification_outbox (locked_at, attempt_count, created_at)
      WHERE published_at IS NULL;

    UPDATE notification_preferences SET preference_category = notification_type WHERE preference_category IS NULL;
    CREATE INDEX IF NOT EXISTS idx_notification_preferences_user_category
      ON notification_preferences (user_id, preference_category);

    CREATE UNIQUE INDEX IF NOT EXISTS idx_user_devices_public_active
      ON user_devices (user_id, public_device_id)
      WHERE public_device_id IS NOT NULL AND invalidated_at IS NULL AND revoked_at IS NULL;
    CREATE UNIQUE INDEX IF NOT EXISTS idx_user_devices_push_token_active
      ON user_devices (push_provider, push_token)
      WHERE push_token IS NOT NULL AND invalidated_at IS NULL AND revoked_at IS NULL;

    CREATE TABLE IF NOT EXISTS notification_deliveries (
      delivery_id UUID PRIMARY KEY,
      notification_id TEXT NOT NULL REFERENCES notifications(notification_id) ON DELETE CASCADE,
      device_id UUID DEFAULT NULL REFERENCES user_devices(id) ON DELETE SET NULL,
      channel TEXT NOT NULL,
      provider_message_id TEXT DEFAULT NULL,
      status TEXT NOT NULL DEFAULT 'queued',
      attempt_count INT NOT NULL DEFAULT 0,
      next_retry_at TIMESTAMPTZ DEFAULT NULL,
      sent_at TIMESTAMPTZ DEFAULT NULL,
      delivered_at TIMESTAMPTZ DEFAULT NULL,
      failed_at TIMESTAMPTZ DEFAULT NULL,
      error_code TEXT DEFAULT NULL,
      error_message TEXT DEFAULT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_notification_deliveries_notification
      ON notification_deliveries (notification_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_notification_deliveries_retry
      ON notification_deliveries (status, next_retry_at)
      WHERE status IN ('queued', 'retry');

    CREATE TABLE IF NOT EXISTS notification_aggregates (
      aggregation_key TEXT NOT NULL,
      recipient_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      notification_type TEXT NOT NULL,
      entity_id TEXT DEFAULT NULL,
      actor_count INT NOT NULL DEFAULT 0,
      latest_actor_user_id UUID DEFAULT NULL REFERENCES users(id) ON DELETE SET NULL,
      notification_id TEXT NOT NULL REFERENCES notifications(notification_id) ON DELETE CASCADE,
      window_started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      window_expires_at TIMESTAMPTZ NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (aggregation_key, recipient_user_id)
    );
    CREATE INDEX IF NOT EXISTS idx_notification_aggregates_expires
      ON notification_aggregates (window_expires_at);

    CREATE TABLE IF NOT EXISTS notification_dead_letters (
      dead_letter_id UUID PRIMARY KEY,
      source_event_id UUID DEFAULT NULL,
      event_type TEXT NOT NULL,
      payload JSONB NOT NULL DEFAULT '{}',
      error_message TEXT NOT NULL,
      failed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      resolved_at TIMESTAMPTZ DEFAULT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_notification_dead_letters_failed
      ON notification_dead_letters (resolved_at, failed_at DESC);
  `);
}
