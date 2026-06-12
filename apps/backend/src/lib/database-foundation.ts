import { createHash } from "node:crypto";
import type pg from "pg";

import { runDatabaseDomainMigrations } from "./database-domain-migrations.js";

export async function runDatabaseFoundationMigrations(pool: pg.Pool): Promise<void> {
  if (await isFoundationApplied(pool)) {
    await refreshFoundationBackfills(pool);
    await ensureFoundationPrerequisiteTables(pool);
    await runDatabaseDomainMigrations(pool);
    await seedFoundationData(pool);
    return;
  }

  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version VARCHAR(128) PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      checksum TEXT,
      description TEXT
    );

    CREATE TABLE IF NOT EXISTS database_foundation_metadata (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    INSERT INTO schema_migrations (version, checksum, description)
    VALUES ('0001_database_foundation', 'runtime-additive-v1', 'Prava production database foundation')
    ON CONFLICT (version) DO UPDATE SET
      applied_at = EXCLUDED.applied_at,
      checksum = EXCLUDED.checksum,
      description = EXCLUDED.description;

    INSERT INTO database_foundation_metadata (key, value)
    VALUES
      ('id_strategy', 'uuid-compatible additive columns; legacy text ids retained'),
      ('rollout_mode', 'non-destructive online migration'),
      ('spec_status', 'NOW foundation implemented with NEXT/FUTURE-gated docs')
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now();
  `);

  await pool.query(`
    ALTER TABLE users ADD COLUMN IF NOT EXISTS id UUID;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS handle VARCHAR(30);
    UPDATE users SET handle = substring(username from 1 for 30) WHERE handle IS NULL;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS handle_normalized VARCHAR(30);
    UPDATE users SET handle_normalized = lower(handle) WHERE handle_normalized IS NULL AND handle IS NOT NULL;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS display_name VARCHAR(80);
    ALTER TABLE users ADD COLUMN IF NOT EXISTS account_status VARCHAR(24) NOT NULL DEFAULT 'active';
    ALTER TABLE users ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT false;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS is_private BOOLEAN NOT NULL DEFAULT false;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(32) NOT NULL DEFAULT 'user';
    ALTER TABLE users ADD COLUMN IF NOT EXISTS language_code VARCHAR(12) NOT NULL DEFAULT 'en';
    ALTER TABLE users ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
    CREATE UNIQUE INDEX IF NOT EXISTS idx_users_uuid_unique ON users (id);
    CREATE UNIQUE INDEX IF NOT EXISTS idx_users_handle_normalized_unique
      ON users (handle_normalized)
      WHERE deleted_at IS NULL;
    CREATE INDEX IF NOT EXISTS idx_users_account_status ON users (account_status);
    CREATE INDEX IF NOT EXISTS idx_users_last_seen_at ON users (last_seen_at DESC);

    ALTER TABLE posts ADD COLUMN IF NOT EXISTS id UUID;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS author_uuid UUID;
    UPDATE posts SET author_uuid = users.id FROM users WHERE posts.author_id = users.user_id AND posts.author_uuid IS NULL;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS visibility VARCHAR(24) NOT NULL DEFAULT 'public';
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS status VARCHAR(24) NOT NULL DEFAULT 'published';
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS language_code VARCHAR(12);
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS moderation_state VARCHAR(24) NOT NULL DEFAULT 'clean';
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS last_engagement_at TIMESTAMPTZ;
    CREATE UNIQUE INDEX IF NOT EXISTS idx_posts_uuid_unique ON posts (id);
    CREATE INDEX IF NOT EXISTS idx_posts_author_uuid_created ON posts (author_uuid, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_posts_visibility_status_created ON posts (visibility, status, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_posts_last_engagement ON posts (last_engagement_at DESC NULLS LAST);

    ALTER TABLE conversations ADD COLUMN IF NOT EXISTS id UUID;
    ALTER TABLE conversations ADD COLUMN IF NOT EXISTS created_by_uuid UUID;
    UPDATE conversations SET created_by_uuid = users.id FROM users WHERE conversations.owner_user_id = users.user_id AND conversations.created_by_uuid IS NULL;
    ALTER TABLE conversations ADD COLUMN IF NOT EXISTS conversation_type VARCHAR(24) NOT NULL DEFAULT 'direct';
    ALTER TABLE conversations ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ;
    ALTER TABLE conversations ADD COLUMN IF NOT EXISTS member_count INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE conversations ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
    CREATE UNIQUE INDEX IF NOT EXISTS idx_conversations_uuid_unique ON conversations (id);
    CREATE INDEX IF NOT EXISTS idx_conversations_last_message_at ON conversations (last_message_at DESC NULLS LAST);

    ALTER TABLE messages ADD COLUMN IF NOT EXISTS message_uuid UUID;
    ALTER TABLE messages ADD COLUMN IF NOT EXISTS conversation_uuid UUID;
    UPDATE messages SET conversation_uuid = conversations.id FROM conversations WHERE messages.conversation_id = conversations.conversation_id AND messages.conversation_uuid IS NULL;
    ALTER TABLE messages ADD COLUMN IF NOT EXISTS sender_uuid UUID;
    UPDATE messages SET sender_uuid = users.id FROM users WHERE messages.sender_user_id = users.user_id AND messages.sender_uuid IS NULL;
    ALTER TABLE messages ADD COLUMN IF NOT EXISTS client_message_uuid UUID;
    ALTER TABLE messages ADD COLUMN IF NOT EXISTS message_type VARCHAR(24) NOT NULL DEFAULT 'text';
    ALTER TABLE messages ADD COLUMN IF NOT EXISTS body_text TEXT;
    UPDATE messages SET body_text = body WHERE body_text IS NULL AND body IS NOT NULL;
    ALTER TABLE messages ADD COLUMN IF NOT EXISTS sequence_id BIGINT;
    ALTER TABLE messages ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ;
    ALTER TABLE messages ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
    CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_uuid_unique ON messages (message_uuid);
    CREATE INDEX IF NOT EXISTS idx_messages_conversation_uuid_created ON messages (conversation_uuid, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_messages_sender_uuid_created ON messages (sender_uuid, created_at DESC);

    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS notification_uuid UUID;
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS recipient_uuid UUID;
    UPDATE notifications SET recipient_uuid = users.id FROM users WHERE notifications.user_id = users.user_id AND notifications.recipient_uuid IS NULL;
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS actor_uuid UUID;
    UPDATE notifications SET actor_uuid = users.id FROM users WHERE notifications.actor_user_id = users.user_id AND notifications.actor_uuid IS NULL;
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS notification_type VARCHAR(48);
    UPDATE notifications SET notification_type = type WHERE notification_type IS NULL AND type IS NOT NULL;
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS entity_type VARCHAR(48);
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS entity_uuid UUID;
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS clicked_at TIMESTAMPTZ;
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
    CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_uuid_unique ON notifications (notification_uuid);
    CREATE INDEX IF NOT EXISTS idx_notifications_recipient_unread
      ON notifications (recipient_uuid, created_at DESC)
      WHERE read_at IS NULL;
  `);

  await backfillPrimaryUuidColumns(pool);
  await remapPrimaryUuidReferences(pool);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS user_profiles (
      user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      bio TEXT,
      avatar_media_id UUID,
      cover_media_id UUID,
      location_text VARCHAR(120),
      website_url TEXT,
      display_name VARCHAR(100),
      banner_media_id UUID,
      birth_date DATE,
      search_vector TEXT,
      profile_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS user_stats (
      user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      posts_count BIGINT NOT NULL DEFAULT 0,
      followers_count BIGINT NOT NULL DEFAULT 0,
      following_count BIGINT NOT NULL DEFAULT 0,
      friends_count BIGINT NOT NULL DEFAULT 0,
      profile_views_count BIGINT NOT NULL DEFAULT 0,
      unread_notifications_count BIGINT NOT NULL DEFAULT 0,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS user_privacy_settings (
      user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      profile_visibility VARCHAR(24) NOT NULL DEFAULT 'public',
      message_permission VARCHAR(24) NOT NULL DEFAULT 'friends',
      mention_permission VARCHAR(24) NOT NULL DEFAULT 'everyone',
      activity_visibility VARCHAR(24) NOT NULL DEFAULT 'friends',
      search_discoverable BOOLEAN NOT NULL DEFAULT true,
      personalized_feed_enabled BOOLEAN NOT NULL DEFAULT true,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS user_emails (
      id UUID PRIMARY KEY,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      email CITEXT NOT NULL,
      is_primary BOOLEAN NOT NULL DEFAULT false,
      is_verified BOOLEAN NOT NULL DEFAULT false,
      verified_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      deleted_at TIMESTAMPTZ
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_user_emails_email_active
      ON user_emails (email)
      WHERE deleted_at IS NULL;
    CREATE UNIQUE INDEX IF NOT EXISTS idx_user_emails_primary
      ON user_emails (user_id)
      WHERE is_primary = true AND deleted_at IS NULL;

    CREATE TABLE IF NOT EXISTS user_handle_history (
      id BIGSERIAL PRIMARY KEY,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      old_handle VARCHAR(30),
      new_handle VARCHAR(30) NOT NULL,
      changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      changed_by UUID REFERENCES users(id),
      reason TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_user_handle_history_user_changed
      ON user_handle_history (user_id, changed_at DESC);

    CREATE TABLE IF NOT EXISTS user_consents (
      id BIGSERIAL PRIMARY KEY,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      consent_key VARCHAR(64) NOT NULL,
      consent_value BOOLEAN NOT NULL,
      policy_version VARCHAR(64) NOT NULL,
      captured_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_user_consents_latest_key
      ON user_consents (user_id, consent_key, policy_version);

    CREATE TABLE IF NOT EXISTS account_deletion_requests (
      id UUID PRIMARY KEY,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      scheduled_delete_at TIMESTAMPTZ NOT NULL,
      cancelled_at TIMESTAMPTZ,
      completed_at TIMESTAMPTZ,
      reason TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_account_deletion_requests_due
      ON account_deletion_requests (scheduled_delete_at)
      WHERE cancelled_at IS NULL AND completed_at IS NULL;

    CREATE TABLE IF NOT EXISTS user_credentials (
      user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      password_hash TEXT NOT NULL,
      password_algo VARCHAR(32) NOT NULL DEFAULT 'bcrypt',
      password_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      must_rotate_password BOOLEAN NOT NULL DEFAULT false
    );

    CREATE TABLE IF NOT EXISTS user_devices (
      id UUID PRIMARY KEY,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      device_fingerprint TEXT NOT NULL,
      platform VARCHAR(32) NOT NULL,
      app_version VARCHAR(32),
      device_name TEXT,
      trusted_at TIMESTAMPTZ,
      last_seen_at TIMESTAMPTZ,
      revoked_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_user_devices_fingerprint_active
      ON user_devices (user_id, device_fingerprint)
      WHERE revoked_at IS NULL;

    CREATE TABLE IF NOT EXISTS auth_sessions (
      id UUID PRIMARY KEY,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      device_id UUID REFERENCES user_devices(id) ON DELETE SET NULL,
      session_token_hash TEXT NOT NULL,
      ip_address INET,
      user_agent TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      expires_at TIMESTAMPTZ NOT NULL,
      revoked_at TIMESTAMPTZ,
      last_seen_at TIMESTAMPTZ
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_auth_sessions_token_hash ON auth_sessions (session_token_hash);
    CREATE INDEX IF NOT EXISTS idx_auth_sessions_user_active
      ON auth_sessions (user_id, expires_at DESC)
      WHERE revoked_at IS NULL;

    CREATE TABLE IF NOT EXISTS auth_refresh_tokens (
      id UUID PRIMARY KEY,
      session_id UUID NOT NULL REFERENCES auth_sessions(id) ON DELETE CASCADE,
      token_hash TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      expires_at TIMESTAMPTZ NOT NULL,
      rotated_at TIMESTAMPTZ,
      revoked_at TIMESTAMPTZ
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_auth_refresh_tokens_hash ON auth_refresh_tokens (token_hash);

    CREATE TABLE IF NOT EXISTS auth_challenges (
      id UUID PRIMARY KEY,
      user_id UUID REFERENCES users(id) ON DELETE CASCADE,
      channel VARCHAR(24) NOT NULL,
      target CITEXT,
      purpose VARCHAR(48) NOT NULL,
      code_hash TEXT NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      max_attempts INTEGER NOT NULL DEFAULT 5,
      expires_at TIMESTAMPTZ NOT NULL,
      consumed_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_auth_challenges_target_purpose
      ON auth_challenges (target, purpose, created_at DESC);

    CREATE TABLE IF NOT EXISTS auth_login_attempts (
      id BIGSERIAL PRIMARY KEY,
      identifier CITEXT NOT NULL,
      user_id UUID REFERENCES users(id) ON DELETE SET NULL,
      ip_address INET,
      success BOOLEAN NOT NULL,
      failure_reason VARCHAR(64),
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_auth_login_attempts_identifier_created
      ON auth_login_attempts (identifier, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_auth_login_attempts_ip_created
      ON auth_login_attempts (ip_address, created_at DESC);

    CREATE TABLE IF NOT EXISTS security_events (
      id BIGSERIAL PRIMARY KEY,
      user_id UUID REFERENCES users(id) ON DELETE SET NULL,
      event_type VARCHAR(64) NOT NULL,
      ip_address INET,
      user_agent TEXT,
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_security_events_user_created
      ON security_events (user_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS roles (
      id UUID PRIMARY KEY,
      name VARCHAR(48) NOT NULL UNIQUE,
      description TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS permissions (
      id UUID PRIMARY KEY,
      name VARCHAR(96) NOT NULL UNIQUE,
      description TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS role_permissions (
      role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
      permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (role_id, permission_id)
    );

    CREATE TABLE IF NOT EXISTS user_roles (
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
      granted_by UUID REFERENCES users(id),
      granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      expires_at TIMESTAMPTZ,
      PRIMARY KEY (user_id, role_id)
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS friendships (
      requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      addressee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      status VARCHAR(24) NOT NULL DEFAULT 'pending',
      requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      responded_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      CHECK (requester_id <> addressee_id),
      PRIMARY KEY (requester_id, addressee_id)
    );
    CREATE INDEX IF NOT EXISTS idx_friendships_addressee_status
      ON friendships (addressee_id, status, requested_at DESC);

    ALTER TABLE follows ADD COLUMN IF NOT EXISTS follower_uuid UUID;
    UPDATE follows SET follower_uuid = users.id FROM users WHERE follows.follower_id = users.user_id AND follows.follower_uuid IS NULL;
    ALTER TABLE follows ADD COLUMN IF NOT EXISTS following_uuid UUID;
    UPDATE follows SET following_uuid = users.id FROM users WHERE follows.following_id = users.user_id AND follows.following_uuid IS NULL;
    ALTER TABLE follows ADD COLUMN IF NOT EXISTS source VARCHAR(32) NOT NULL DEFAULT 'app';
    CREATE INDEX IF NOT EXISTS idx_follows_follower_uuid_created ON follows (follower_uuid, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_follows_following_uuid_created ON follows (following_uuid, created_at DESC);

    CREATE TABLE IF NOT EXISTS blocks (
      blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      blocked_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      reason VARCHAR(64),
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      CHECK (blocker_id <> blocked_id),
      PRIMARY KEY (blocker_id, blocked_id)
    );
    CREATE INDEX IF NOT EXISTS idx_blocks_blocked ON blocks (blocked_id);

    CREATE TABLE IF NOT EXISTS mutes (
      muter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      muted_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      mute_type VARCHAR(24) NOT NULL DEFAULT 'all',
      expires_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      CHECK (muter_id <> muted_user_id),
      PRIMARY KEY (muter_id, muted_user_id, mute_type)
    );
    CREATE INDEX IF NOT EXISTS idx_mutes_muter_active
      ON mutes (muter_id, expires_at);

    CREATE TABLE IF NOT EXISTS topic_catalog (
      id UUID PRIMARY KEY,
      slug VARCHAR(80) NOT NULL UNIQUE,
      name VARCHAR(120) NOT NULL,
      description TEXT,
      parent_topic_id UUID REFERENCES topic_catalog(id) ON DELETE SET NULL,
      is_active BOOLEAN NOT NULL DEFAULT true,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS user_selected_topics (
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      topic_id UUID NOT NULL REFERENCES topic_catalog(id) ON DELETE CASCADE,
      weight REAL NOT NULL DEFAULT 1,
      selected_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (user_id, topic_id)
    );

    CREATE TABLE IF NOT EXISTS user_recommendation_dismissals (
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      entity_type VARCHAR(32) NOT NULL,
      entity_uuid UUID NOT NULL,
      reason VARCHAR(64),
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      expires_at TIMESTAMPTZ,
      PRIMARY KEY (user_id, entity_type, entity_uuid)
    );
    CREATE INDEX IF NOT EXISTS idx_user_recommendation_dismissals_active
      ON user_recommendation_dismissals (user_id, expires_at);
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS post_stats (
      post_id UUID PRIMARY KEY REFERENCES posts(id) ON DELETE CASCADE,
      likes_count BIGINT NOT NULL DEFAULT 0,
      comments_count BIGINT NOT NULL DEFAULT 0,
      shares_count BIGINT NOT NULL DEFAULT 0,
      bookmarks_count BIGINT NOT NULL DEFAULT 0,
      impressions_count BIGINT NOT NULL DEFAULT 0,
      reads_count BIGINT NOT NULL DEFAULT 0,
      profile_clicks_count BIGINT NOT NULL DEFAULT 0,
      engagement_score DOUBLE PRECISION NOT NULL DEFAULT 0,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    ALTER TABLE post_likes ADD COLUMN IF NOT EXISTS post_uuid UUID;
    UPDATE post_likes SET post_uuid = posts.id FROM posts WHERE post_likes.post_id = posts.post_id AND post_likes.post_uuid IS NULL;
    ALTER TABLE post_likes ADD COLUMN IF NOT EXISTS user_uuid UUID;
    UPDATE post_likes SET user_uuid = users.id FROM users WHERE post_likes.user_id = users.user_id AND post_likes.user_uuid IS NULL;
    ALTER TABLE post_likes ADD COLUMN IF NOT EXISTS reaction_type VARCHAR(24) NOT NULL DEFAULT 'like';
    CREATE UNIQUE INDEX IF NOT EXISTS idx_post_likes_uuid_unique ON post_likes (post_uuid, user_uuid, reaction_type);
    CREATE INDEX IF NOT EXISTS idx_post_likes_user_uuid_created ON post_likes (user_uuid, created_at DESC);

    CREATE TABLE IF NOT EXISTS post_bookmarks (
      post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (post_id, user_id)
    );
    CREATE INDEX IF NOT EXISTS idx_post_bookmarks_user_created
      ON post_bookmarks (user_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS post_shares (
      id UUID PRIMARY KEY,
      post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      share_target VARCHAR(32) NOT NULL DEFAULT 'internal',
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb
    );
    CREATE INDEX IF NOT EXISTS idx_post_shares_post_created ON post_shares (post_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS hashtags (
      id UUID PRIMARY KEY,
      tag VARCHAR(96) NOT NULL,
      tag_normalized VARCHAR(96) NOT NULL UNIQUE,
      posts_count BIGINT NOT NULL DEFAULT 0,
      engagement_score DOUBLE PRECISION NOT NULL DEFAULT 0,
      last_used_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_hashtags_engagement ON hashtags (engagement_score DESC, last_used_at DESC);

    CREATE TABLE IF NOT EXISTS post_hashtags (
      post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
      hashtag_id UUID NOT NULL REFERENCES hashtags(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (post_id, hashtag_id)
    );
    CREATE INDEX IF NOT EXISTS idx_post_hashtags_hashtag_created
      ON post_hashtags (hashtag_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS post_mentions (
      post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
      mentioned_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      mentioned_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
      token VARCHAR(64) NOT NULL,
      start_offset INTEGER,
      end_offset INTEGER,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (post_id, mentioned_user_id, token)
    );
    CREATE INDEX IF NOT EXISTS idx_post_mentions_user_created
      ON post_mentions (mentioned_user_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS hidden_posts (
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
      reason VARCHAR(64),
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (user_id, post_id)
    );

    ALTER TABLE comments ADD COLUMN IF NOT EXISTS id UUID;
    ALTER TABLE comments ADD COLUMN IF NOT EXISTS post_uuid UUID;
    UPDATE comments SET post_uuid = posts.id FROM posts WHERE comments.post_id = posts.post_id AND comments.post_uuid IS NULL;
    ALTER TABLE comments ADD COLUMN IF NOT EXISTS author_uuid UUID;
    UPDATE comments SET author_uuid = users.id FROM users WHERE comments.author_id = users.user_id AND comments.author_uuid IS NULL;
    ALTER TABLE comments ADD COLUMN IF NOT EXISTS parent_comment_uuid UUID;
    ALTER TABLE comments ADD COLUMN IF NOT EXISTS depth INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE comments ADD COLUMN IF NOT EXISTS likes_count BIGINT NOT NULL DEFAULT 0;
    ALTER TABLE comments ADD COLUMN IF NOT EXISTS replies_count BIGINT NOT NULL DEFAULT 0;
    ALTER TABLE comments ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ;
    ALTER TABLE comments ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
    CREATE UNIQUE INDEX IF NOT EXISTS idx_comments_uuid_unique ON comments (id);
    CREATE INDEX IF NOT EXISTS idx_comments_post_uuid_created ON comments (post_uuid, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_comments_parent_uuid_created ON comments (parent_comment_uuid, created_at ASC);

    CREATE INDEX IF NOT EXISTS idx_comment_likes_user_created ON comment_likes (user_id, created_at DESC);
  `);

  await refreshCommentUuidReferences(pool);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS post_quality_scores (
      post_id UUID PRIMARY KEY REFERENCES posts(id) ON DELETE CASCADE,
      language_quality_score REAL NOT NULL DEFAULT 0,
      media_quality_score REAL NOT NULL DEFAULT 0,
      originality_score REAL NOT NULL DEFAULT 0,
      spam_probability REAL NOT NULL DEFAULT 0,
      safety_score REAL NOT NULL DEFAULT 1,
      calculated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      model_version VARCHAR(64) NOT NULL DEFAULT 'manual-v1'
    );

    ALTER TABLE post_topics ADD COLUMN IF NOT EXISTS post_uuid UUID;
    UPDATE post_topics SET post_uuid = posts.id FROM posts WHERE post_topics.post_id = posts.post_id AND post_topics.post_uuid IS NULL;
    ALTER TABLE post_topics ADD COLUMN IF NOT EXISTS topic_id UUID REFERENCES topic_catalog(id) ON DELETE SET NULL;
    ALTER TABLE post_topics ADD COLUMN IF NOT EXISTS confidence_score REAL NOT NULL DEFAULT 1;
    ALTER TABLE post_topics ADD COLUMN IF NOT EXISTS source VARCHAR(32) NOT NULL DEFAULT 'legacy';
    CREATE INDEX IF NOT EXISTS idx_post_topics_uuid_confidence ON post_topics (post_uuid, confidence_score DESC);
    CREATE INDEX IF NOT EXISTS idx_post_topics_topic_id ON post_topics (topic_id);

    CREATE TABLE IF NOT EXISTS post_engagement_windows (
      post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
      window_start TIMESTAMPTZ NOT NULL,
      window_size_minutes INTEGER NOT NULL,
      impressions_count BIGINT NOT NULL DEFAULT 0,
      likes_count BIGINT NOT NULL DEFAULT 0,
      comments_count BIGINT NOT NULL DEFAULT 0,
      shares_count BIGINT NOT NULL DEFAULT 0,
      reads_count BIGINT NOT NULL DEFAULT 0,
      engagement_score DOUBLE PRECISION NOT NULL DEFAULT 0,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (post_id, window_start, window_size_minutes)
    );
    CREATE INDEX IF NOT EXISTS idx_post_engagement_windows_score
      ON post_engagement_windows (window_size_minutes, engagement_score DESC, window_start DESC);

    ALTER TABLE post_trend_snapshots ADD COLUMN IF NOT EXISTS post_uuid UUID;
    UPDATE post_trend_snapshots SET post_uuid = posts.id FROM posts WHERE post_trend_snapshots.post_id = posts.post_id AND post_trend_snapshots.post_uuid IS NULL;
    ALTER TABLE post_trend_snapshots ADD COLUMN IF NOT EXISTS scope_type VARCHAR(24) NOT NULL DEFAULT 'global';
    ALTER TABLE post_trend_snapshots ADD COLUMN IF NOT EXISTS scope_key VARCHAR(96) NOT NULL DEFAULT 'global';
    ALTER TABLE post_trend_snapshots ADD COLUMN IF NOT EXISTS trending_score DOUBLE PRECISION NOT NULL DEFAULT 0;
    CREATE INDEX IF NOT EXISTS idx_post_trend_snapshots_scope_score
      ON post_trend_snapshots (scope_type, scope_key, trending_score DESC);

    ALTER TABLE trending_topics ADD COLUMN IF NOT EXISTS topic_id UUID REFERENCES topic_catalog(id) ON DELETE SET NULL;
    ALTER TABLE trending_topics ADD COLUMN IF NOT EXISTS scope_type VARCHAR(24) NOT NULL DEFAULT 'global';
    ALTER TABLE trending_topics ADD COLUMN IF NOT EXISTS scope_key VARCHAR(96) NOT NULL DEFAULT 'global';
    ALTER TABLE trending_topics ADD COLUMN IF NOT EXISTS posts_count BIGINT NOT NULL DEFAULT 0;
    ALTER TABLE trending_topics ADD COLUMN IF NOT EXISTS engagement_score DOUBLE PRECISION NOT NULL DEFAULT 0;
    CREATE INDEX IF NOT EXISTS idx_trending_topics_scope_score
      ON trending_topics (scope_type, scope_key, engagement_score DESC);
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS feed_algorithm_versions (
      id UUID PRIMARY KEY,
      name VARCHAR(96) NOT NULL,
      version VARCHAR(48) NOT NULL,
      config JSONB NOT NULL DEFAULT '{}'::jsonb,
      is_active BOOLEAN NOT NULL DEFAULT false,
      rollout_percent INTEGER NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      activated_at TIMESTAMPTZ,
      UNIQUE (name, version)
    );

    CREATE TABLE IF NOT EXISTS feed_requests (
      id UUID PRIMARY KEY,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      algorithm_version_id UUID REFERENCES feed_algorithm_versions(id) ON DELETE SET NULL,
      feed_type VARCHAR(24) NOT NULL,
      cursor_in TEXT,
      cursor_out TEXT,
      request_context JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_feed_requests_user_created ON feed_requests (user_id, created_at DESC);

    ALTER TABLE feed_impressions ADD COLUMN IF NOT EXISTS request_uuid UUID REFERENCES feed_requests(id) ON DELETE SET NULL;
    ALTER TABLE feed_impressions ADD COLUMN IF NOT EXISTS user_uuid UUID;
    UPDATE feed_impressions SET user_uuid = users.id FROM users WHERE feed_impressions.user_id = users.user_id AND feed_impressions.user_uuid IS NULL;
    ALTER TABLE feed_impressions ADD COLUMN IF NOT EXISTS post_uuid UUID;
    UPDATE feed_impressions SET post_uuid = posts.id FROM posts WHERE feed_impressions.post_id = posts.post_id AND feed_impressions.post_uuid IS NULL;
    ALTER TABLE feed_impressions ADD COLUMN IF NOT EXISTS rank_position INTEGER;
    ALTER TABLE feed_impressions ADD COLUMN IF NOT EXISTS score DOUBLE PRECISION;
    ALTER TABLE feed_impressions ADD COLUMN IF NOT EXISTS reason_codes TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];
    ALTER TABLE feed_impressions ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
    CREATE INDEX IF NOT EXISTS idx_feed_impressions_uuid_user_post
      ON feed_impressions (user_uuid, post_uuid, created_at DESC);

    ALTER TABLE feed_events ADD COLUMN IF NOT EXISTS request_uuid UUID REFERENCES feed_requests(id) ON DELETE SET NULL;
    ALTER TABLE feed_events ADD COLUMN IF NOT EXISTS user_uuid UUID;
    UPDATE feed_events SET user_uuid = users.id FROM users WHERE feed_events.user_id = users.user_id AND feed_events.user_uuid IS NULL;
    ALTER TABLE feed_events ADD COLUMN IF NOT EXISTS post_uuid UUID;
    UPDATE feed_events SET post_uuid = posts.id FROM posts WHERE feed_events.post_id = posts.post_id AND feed_events.post_uuid IS NULL;
    ALTER TABLE feed_events ADD COLUMN IF NOT EXISTS entity_type VARCHAR(32) NOT NULL DEFAULT 'post';
    ALTER TABLE feed_events ADD COLUMN IF NOT EXISTS dwell_ms INTEGER;
    ALTER TABLE feed_events ADD COLUMN IF NOT EXISTS weight REAL NOT NULL DEFAULT 1;
    CREATE INDEX IF NOT EXISTS idx_feed_events_uuid_user_created
      ON feed_events (user_uuid, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_feed_events_uuid_post_created
      ON feed_events (post_uuid, created_at DESC);

    ALTER TABLE feed_served_history ADD COLUMN IF NOT EXISTS user_uuid UUID;
    UPDATE feed_served_history SET user_uuid = users.id FROM users WHERE feed_served_history.user_id = users.user_id AND feed_served_history.user_uuid IS NULL;
    ALTER TABLE feed_served_history ADD COLUMN IF NOT EXISTS post_uuid UUID;
    UPDATE feed_served_history SET post_uuid = posts.id FROM posts WHERE feed_served_history.post_id = posts.post_id AND feed_served_history.post_uuid IS NULL;
    ALTER TABLE feed_served_history ADD COLUMN IF NOT EXISTS source VARCHAR(32) NOT NULL DEFAULT 'feed';
    ALTER TABLE feed_served_history ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
    CREATE INDEX IF NOT EXISTS idx_feed_served_history_uuid_user_expires
      ON feed_served_history (user_uuid, expires_at);

    CREATE TABLE IF NOT EXISTS user_interest_profiles (
      user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      interests JSONB NOT NULL DEFAULT '{}'::jsonb,
      embedding_version VARCHAR(64),
      freshness_score REAL NOT NULL DEFAULT 0,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    ALTER TABLE user_topic_affinities ADD COLUMN IF NOT EXISTS user_uuid UUID;
    UPDATE user_topic_affinities SET user_uuid = users.id FROM users WHERE user_topic_affinities.user_id = users.user_id AND user_topic_affinities.user_uuid IS NULL;
    ALTER TABLE user_topic_affinities ADD COLUMN IF NOT EXISTS topic_id UUID REFERENCES topic_catalog(id) ON DELETE SET NULL;
    ALTER TABLE user_topic_affinities ADD COLUMN IF NOT EXISTS affinity_score DOUBLE PRECISION NOT NULL DEFAULT 0;
    ALTER TABLE user_topic_affinities ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
    CREATE INDEX IF NOT EXISTS idx_user_topic_affinities_uuid_score
      ON user_topic_affinities (user_uuid, affinity_score DESC);

    ALTER TABLE user_author_affinities ADD COLUMN IF NOT EXISTS user_uuid UUID;
    UPDATE user_author_affinities SET user_uuid = users.id FROM users WHERE user_author_affinities.user_id = users.user_id AND user_author_affinities.user_uuid IS NULL;
    ALTER TABLE user_author_affinities ADD COLUMN IF NOT EXISTS author_uuid UUID;
    UPDATE user_author_affinities SET author_uuid = users.id FROM users WHERE user_author_affinities.author_id = users.user_id AND user_author_affinities.author_uuid IS NULL;
    ALTER TABLE user_author_affinities ADD COLUMN IF NOT EXISTS affinity_score DOUBLE PRECISION NOT NULL DEFAULT 0;
    ALTER TABLE user_author_affinities ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
    CREATE INDEX IF NOT EXISTS idx_user_author_affinities_uuid_score
      ON user_author_affinities (user_uuid, affinity_score DESC);
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS direct_conversation_pairs (
      lower_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      higher_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      CHECK (lower_user_id < higher_user_id),
      PRIMARY KEY (lower_user_id, higher_user_id)
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_direct_conversation_pairs_conversation
      ON direct_conversation_pairs (conversation_id);

    ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS conversation_uuid UUID;
    UPDATE conversation_members SET conversation_uuid = conversations.id FROM conversations WHERE conversation_members.conversation_id = conversations.conversation_id AND conversation_members.conversation_uuid IS NULL;
    ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS user_uuid UUID;
    UPDATE conversation_members SET user_uuid = users.id FROM users WHERE conversation_members.user_id = users.user_id AND conversation_members.user_uuid IS NULL;
    ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS member_role VARCHAR(24) NOT NULL DEFAULT 'member';
    ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS status VARCHAR(24) NOT NULL DEFAULT 'active';
    ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS last_read_message_uuid UUID;
    ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS last_read_sequence_id BIGINT NOT NULL DEFAULT 0;
    ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS muted_until TIMESTAMPTZ;
    ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;
    CREATE INDEX IF NOT EXISTS idx_conversation_members_uuid_user
      ON conversation_members (user_uuid, status);
    CREATE INDEX IF NOT EXISTS idx_conversation_members_uuid_conversation
      ON conversation_members (conversation_uuid);

    CREATE TABLE IF NOT EXISTS conversation_invites (
      id UUID PRIMARY KEY,
      conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
      inviter_id UUID REFERENCES users(id) ON DELETE SET NULL,
      invitee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      status VARCHAR(24) NOT NULL DEFAULT 'pending',
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      responded_at TIMESTAMPTZ
    );
    CREATE INDEX IF NOT EXISTS idx_conversation_invites_invitee_status
      ON conversation_invites (invitee_id, status, created_at DESC);

    CREATE TABLE IF NOT EXISTS conversation_events (
      id BIGSERIAL PRIMARY KEY,
      conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
      actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
      event_type VARCHAR(64) NOT NULL,
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_conversation_events_conversation_created
      ON conversation_events (conversation_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS message_receipts (
      message_id UUID NOT NULL REFERENCES messages(message_uuid) ON DELETE CASCADE,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      receipt_type VARCHAR(24) NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (message_id, user_id, receipt_type)
    );
    CREATE INDEX IF NOT EXISTS idx_message_receipts_user_created
      ON message_receipts (user_id, created_at DESC);
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS notification_preferences (
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      channel VARCHAR(24) NOT NULL,
      notification_type VARCHAR(64) NOT NULL,
      enabled BOOLEAN NOT NULL DEFAULT true,
      quiet_hours_start TIME,
      quiet_hours_end TIME,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (user_id, channel, notification_type)
    );

    CREATE TABLE IF NOT EXISTS push_subscriptions (
      id UUID PRIMARY KEY,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      device_id UUID REFERENCES user_devices(id) ON DELETE SET NULL,
      platform VARCHAR(32) NOT NULL,
      endpoint TEXT NOT NULL,
      p256dh TEXT,
      auth_secret TEXT,
      token_hash TEXT,
      is_active BOOLEAN NOT NULL DEFAULT true,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      last_used_at TIMESTAMPTZ,
      revoked_at TIMESTAMPTZ
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_push_subscriptions_endpoint_active
      ON push_subscriptions (endpoint)
      WHERE is_active = true;
    CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_active
      ON push_subscriptions (user_id)
      WHERE is_active = true;
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS reports (
      id UUID PRIMARY KEY,
      reporter_id UUID REFERENCES users(id) ON DELETE SET NULL,
      target_type VARCHAR(32) NOT NULL,
      target_uuid UUID NOT NULL,
      reason VARCHAR(64) NOT NULL,
      details TEXT,
      status VARCHAR(24) NOT NULL DEFAULT 'open',
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      resolved_at TIMESTAMPTZ
    );
    CREATE INDEX IF NOT EXISTS idx_reports_target_status
      ON reports (target_type, target_uuid, status, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_reports_reporter_created
      ON reports (reporter_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS moderation_cases (
      id UUID PRIMARY KEY,
      target_type VARCHAR(32) NOT NULL,
      target_uuid UUID NOT NULL,
      status VARCHAR(24) NOT NULL DEFAULT 'open',
      priority INTEGER NOT NULL DEFAULT 0,
      assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
      opened_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      closed_at TIMESTAMPTZ,
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb
    );
    CREATE INDEX IF NOT EXISTS idx_moderation_cases_status_priority
      ON moderation_cases (status, priority DESC, opened_at ASC);

    CREATE TABLE IF NOT EXISTS moderation_case_reports (
      case_id UUID NOT NULL REFERENCES moderation_cases(id) ON DELETE CASCADE,
      report_id UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (case_id, report_id)
    );

    CREATE TABLE IF NOT EXISTS moderation_case_notes (
      id BIGSERIAL PRIMARY KEY,
      case_id UUID NOT NULL REFERENCES moderation_cases(id) ON DELETE CASCADE,
      author_id UUID REFERENCES users(id) ON DELETE SET NULL,
      note TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS moderation_actions (
      id UUID PRIMARY KEY,
      case_id UUID REFERENCES moderation_cases(id) ON DELETE SET NULL,
      actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
      action_type VARCHAR(64) NOT NULL,
      target_type VARCHAR(32) NOT NULL,
      target_uuid UUID NOT NULL,
      reason TEXT,
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_moderation_actions_target_created
      ON moderation_actions (target_type, target_uuid, created_at DESC);

    CREATE TABLE IF NOT EXISTS user_restrictions (
      id UUID PRIMARY KEY,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      restriction_type VARCHAR(64) NOT NULL,
      starts_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      expires_at TIMESTAMPTZ,
      reason TEXT,
      created_by UUID REFERENCES users(id) ON DELETE SET NULL,
      lifted_at TIMESTAMPTZ
    );
    CREATE INDEX IF NOT EXISTS idx_user_restrictions_active
      ON user_restrictions (user_id, restriction_type, expires_at)
      WHERE lifted_at IS NULL;

    CREATE TABLE IF NOT EXISTS content_labels (
      id UUID PRIMARY KEY,
      label_key VARCHAR(64) NOT NULL UNIQUE,
      display_name VARCHAR(120) NOT NULL,
      severity INTEGER NOT NULL DEFAULT 0,
      is_active BOOLEAN NOT NULL DEFAULT true
    );

    CREATE TABLE IF NOT EXISTS post_content_labels (
      post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
      label_id UUID NOT NULL REFERENCES content_labels(id) ON DELETE CASCADE,
      source VARCHAR(32) NOT NULL DEFAULT 'system',
      confidence REAL NOT NULL DEFAULT 1,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (post_id, label_id, source)
    );

    CREATE TABLE IF NOT EXISTS spam_signals (
      id BIGSERIAL PRIMARY KEY,
      user_id UUID REFERENCES users(id) ON DELETE SET NULL,
      entity_type VARCHAR(32) NOT NULL,
      entity_uuid UUID,
      signal_key VARCHAR(64) NOT NULL,
      signal_value DOUBLE PRECISION NOT NULL DEFAULT 1,
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_spam_signals_entity_created
      ON spam_signals (entity_type, entity_uuid, created_at DESC);
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS media_objects (
      id UUID PRIMARY KEY,
      owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
      bucket VARCHAR(96) NOT NULL,
      object_key TEXT NOT NULL,
      media_type VARCHAR(32) NOT NULL,
      mime_type VARCHAR(120) NOT NULL,
      byte_size BIGINT NOT NULL,
      width INTEGER,
      height INTEGER,
      duration_ms INTEGER,
      checksum_sha256 TEXT,
      processing_status VARCHAR(32) NOT NULL DEFAULT 'pending',
      moderation_status VARCHAR(32) NOT NULL DEFAULT 'pending',
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      deleted_at TIMESTAMPTZ
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_media_objects_storage_key
      ON media_objects (bucket, object_key);
    CREATE INDEX IF NOT EXISTS idx_media_objects_owner_created
      ON media_objects (owner_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS upload_sessions (
      id UUID PRIMARY KEY,
      owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      media_object_id UUID REFERENCES media_objects(id) ON DELETE SET NULL,
      upload_type VARCHAR(32) NOT NULL,
      status VARCHAR(32) NOT NULL DEFAULT 'pending',
      expected_byte_size BIGINT,
      expires_at TIMESTAMPTZ NOT NULL,
      completed_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb
    );
    CREATE INDEX IF NOT EXISTS idx_upload_sessions_owner_status
      ON upload_sessions (owner_id, status, created_at DESC);
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS outbox_events (
      id UUID PRIMARY KEY,
      aggregate_type VARCHAR(64) NOT NULL,
      aggregate_uuid UUID,
      event_type VARCHAR(96) NOT NULL,
      payload JSONB NOT NULL,
      status VARCHAR(24) NOT NULL DEFAULT 'pending',
      attempts INTEGER NOT NULL DEFAULT 0,
      available_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      processed_at TIMESTAMPTZ,
      last_error TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_outbox_events_pending
      ON outbox_events (status, available_at, created_at)
      WHERE status = 'pending';

    CREATE TABLE IF NOT EXISTS processed_events (
      consumer_name VARCHAR(96) NOT NULL,
      event_id UUID NOT NULL,
      processed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (consumer_name, event_id)
    );

    CREATE TABLE IF NOT EXISTS dead_letter_events (
      id UUID PRIMARY KEY,
      source_event_id UUID,
      source_table VARCHAR(96) NOT NULL,
      event_type VARCHAR(96) NOT NULL,
      payload JSONB NOT NULL,
      error_message TEXT NOT NULL,
      failed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb
    );

    CREATE TABLE IF NOT EXISTS idempotency_keys (
      key VARCHAR(160) PRIMARY KEY,
      user_id UUID REFERENCES users(id) ON DELETE CASCADE,
      request_hash TEXT NOT NULL,
      response_status INTEGER,
      response_body JSONB,
      locked_until TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      expires_at TIMESTAMPTZ NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_idempotency_keys_expires ON idempotency_keys (expires_at);

    CREATE TABLE IF NOT EXISTS background_job_runs (
      id UUID PRIMARY KEY,
      job_name VARCHAR(96) NOT NULL,
      status VARCHAR(24) NOT NULL DEFAULT 'running',
      started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      finished_at TIMESTAMPTZ,
      duration_ms INTEGER,
      stats JSONB NOT NULL DEFAULT '{}'::jsonb,
      error_message TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_background_job_runs_job_started
      ON background_job_runs (job_name, started_at DESC);

    CREATE TABLE IF NOT EXISTS background_job_locks (
      lock_key VARCHAR(120) PRIMARY KEY,
      owner_id VARCHAR(120) NOT NULL,
      locked_until TIMESTAMPTZ NOT NULL,
      acquired_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS feature_flags (
      key VARCHAR(96) PRIMARY KEY,
      description TEXT,
      enabled BOOLEAN NOT NULL DEFAULT false,
      rollout_percent INTEGER NOT NULL DEFAULT 0,
      rules JSONB NOT NULL DEFAULT '{}'::jsonb,
      updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS app_config_versions (
      id UUID PRIMARY KEY,
      config_key VARCHAR(96) NOT NULL,
      version INTEGER NOT NULL,
      config JSONB NOT NULL,
      is_active BOOLEAN NOT NULL DEFAULT false,
      created_by UUID REFERENCES users(id) ON DELETE SET NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      activated_at TIMESTAMPTZ,
      UNIQUE (config_key, version)
    );

    CREATE TABLE IF NOT EXISTS admin_audit_logs (
      id BIGSERIAL PRIMARY KEY,
      actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
      action VARCHAR(96) NOT NULL,
      target_type VARCHAR(64),
      target_uuid UUID,
      ip_address INET,
      user_agent TEXT,
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
      occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_actor_occurred
      ON admin_audit_logs (actor_id, occurred_at DESC);
    CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_target_occurred
      ON admin_audit_logs (target_type, target_uuid, occurred_at DESC);

    CREATE TABLE IF NOT EXISTS daily_post_metrics (
      metric_date DATE NOT NULL,
      post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
      impressions_count BIGINT NOT NULL DEFAULT 0,
      reads_count BIGINT NOT NULL DEFAULT 0,
      likes_count BIGINT NOT NULL DEFAULT 0,
      comments_count BIGINT NOT NULL DEFAULT 0,
      shares_count BIGINT NOT NULL DEFAULT 0,
      PRIMARY KEY (metric_date, post_id)
    );

    CREATE TABLE IF NOT EXISTS daily_user_metrics (
      metric_date DATE NOT NULL,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      posts_count BIGINT NOT NULL DEFAULT 0,
      profile_views_count BIGINT NOT NULL DEFAULT 0,
      followers_delta BIGINT NOT NULL DEFAULT 0,
      engagement_score DOUBLE PRECISION NOT NULL DEFAULT 0,
      PRIMARY KEY (metric_date, user_id)
    );
  `);

  await runDatabaseDomainMigrations(pool);
  await seedFoundationData(pool);
}

async function isFoundationApplied(pool: pg.Pool): Promise<boolean> {
  const table = await pool.query(
    `SELECT 1
     FROM information_schema.tables
     WHERE table_schema = 'public'
       AND table_name = 'schema_migrations'
     LIMIT 1`
  );
  if (table.rows.length === 0) {
    return false;
  }
  const migration = await pool.query(
    "SELECT 1 FROM schema_migrations WHERE version = '0001_database_foundation' LIMIT 1"
  );
  return migration.rows.length > 0;
}

async function tableExists(pool: pg.Pool, tableName: string): Promise<boolean> {
  const result = await pool.query(
    `SELECT 1
     FROM information_schema.tables
     WHERE table_schema = 'public'
       AND table_name = $1
     LIMIT 1`,
    [tableName]
  );
  return result.rows.length > 0;
}

async function createTableIfMissing(pool: pg.Pool, tableName: string, ddl: string): Promise<void> {
  if (await tableExists(pool, tableName)) {
    return;
  }
  await pool.query(ddl);
}

async function ensureFoundationPrerequisiteTables(pool: pg.Pool): Promise<void> {
  await createTableIfMissing(pool, "user_profiles", `
    CREATE TABLE user_profiles (
      user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      bio TEXT,
      avatar_media_id UUID,
      cover_media_id UUID,
      location_text VARCHAR(120),
      website_url TEXT,
      display_name VARCHAR(100),
      banner_media_id UUID,
      birth_date DATE,
      search_vector TEXT,
      profile_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  await createTableIfMissing(pool, "user_stats", `
    CREATE TABLE user_stats (
      user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      posts_count BIGINT NOT NULL DEFAULT 0,
      followers_count BIGINT NOT NULL DEFAULT 0,
      following_count BIGINT NOT NULL DEFAULT 0,
      friends_count BIGINT NOT NULL DEFAULT 0,
      profile_views_count BIGINT NOT NULL DEFAULT 0,
      unread_notifications_count BIGINT NOT NULL DEFAULT 0,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  await createTableIfMissing(pool, "user_privacy_settings", `
    CREATE TABLE user_privacy_settings (
      user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      profile_visibility VARCHAR(24) NOT NULL DEFAULT 'public',
      message_permission VARCHAR(24) NOT NULL DEFAULT 'friends',
      mention_permission VARCHAR(24) NOT NULL DEFAULT 'everyone',
      activity_visibility VARCHAR(24) NOT NULL DEFAULT 'friends',
      search_discoverable BOOLEAN NOT NULL DEFAULT true,
      personalized_feed_enabled BOOLEAN NOT NULL DEFAULT true,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  await createTableIfMissing(pool, "user_emails", `
    CREATE TABLE user_emails (
      id UUID PRIMARY KEY,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      email TEXT NOT NULL,
      is_primary BOOLEAN NOT NULL DEFAULT false,
      is_verified BOOLEAN NOT NULL DEFAULT false,
      verified_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      deleted_at TIMESTAMPTZ
    )
  `);

  await createTableIfMissing(pool, "user_credentials", `
    CREATE TABLE user_credentials (
      user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      password_hash TEXT NOT NULL,
      password_algo VARCHAR(32) NOT NULL DEFAULT 'bcrypt',
      password_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      must_rotate_password BOOLEAN NOT NULL DEFAULT false
    )
  `);

  await createTableIfMissing(pool, "user_devices", `
    CREATE TABLE user_devices (
      id UUID PRIMARY KEY,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      device_fingerprint TEXT NOT NULL,
      platform VARCHAR(32) NOT NULL,
      app_version VARCHAR(32),
      device_name TEXT,
      trusted_at TIMESTAMPTZ,
      last_seen_at TIMESTAMPTZ,
      revoked_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  await createTableIfMissing(pool, "auth_sessions", `
    CREATE TABLE auth_sessions (
      id UUID PRIMARY KEY,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      device_id UUID REFERENCES user_devices(id) ON DELETE SET NULL,
      session_token_hash TEXT NOT NULL,
      ip_address INET,
      user_agent TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      expires_at TIMESTAMPTZ NOT NULL,
      revoked_at TIMESTAMPTZ,
      last_seen_at TIMESTAMPTZ
    )
  `);

  await createTableIfMissing(pool, "auth_refresh_tokens", `
    CREATE TABLE auth_refresh_tokens (
      id UUID PRIMARY KEY,
      session_id UUID NOT NULL REFERENCES auth_sessions(id) ON DELETE CASCADE,
      token_hash TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      expires_at TIMESTAMPTZ NOT NULL,
      rotated_at TIMESTAMPTZ,
      revoked_at TIMESTAMPTZ
    )
  `);

  await createTableIfMissing(pool, "auth_challenges", `
    CREATE TABLE auth_challenges (
      id UUID PRIMARY KEY,
      user_id UUID REFERENCES users(id) ON DELETE CASCADE,
      channel VARCHAR(24) NOT NULL,
      target TEXT,
      purpose VARCHAR(48) NOT NULL,
      code_hash TEXT NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      max_attempts INTEGER NOT NULL DEFAULT 5,
      expires_at TIMESTAMPTZ NOT NULL,
      consumed_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  await createTableIfMissing(pool, "auth_login_attempts", `
    CREATE TABLE auth_login_attempts (
      id BIGSERIAL PRIMARY KEY,
      identifier TEXT NOT NULL,
      user_id UUID REFERENCES users(id) ON DELETE SET NULL,
      ip_address INET,
      success BOOLEAN NOT NULL,
      failure_reason VARCHAR(64),
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  await createTableIfMissing(pool, "security_events", `
    CREATE TABLE security_events (
      id BIGSERIAL PRIMARY KEY,
      user_id UUID REFERENCES users(id) ON DELETE SET NULL,
      event_type VARCHAR(64) NOT NULL,
      ip_address INET,
      user_agent TEXT,
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  await createTableIfMissing(pool, "roles", `
    CREATE TABLE roles (
      id UUID PRIMARY KEY,
      name VARCHAR(48) NOT NULL UNIQUE,
      description TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  await createTableIfMissing(pool, "permissions", `
    CREATE TABLE permissions (
      id UUID PRIMARY KEY,
      name VARCHAR(96) NOT NULL UNIQUE,
      description TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  await createTableIfMissing(pool, "role_permissions", `
    CREATE TABLE role_permissions (
      role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
      permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (role_id, permission_id)
    )
  `);

  await createTableIfMissing(pool, "user_roles", `
    CREATE TABLE user_roles (
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
      granted_by UUID REFERENCES users(id),
      granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      expires_at TIMESTAMPTZ,
      PRIMARY KEY (user_id, role_id)
    )
  `);

  await createTableIfMissing(pool, "friendships", `
    CREATE TABLE friendships (
      requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      addressee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      status VARCHAR(24) NOT NULL DEFAULT 'pending',
      requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      responded_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      CHECK (requester_id <> addressee_id),
      PRIMARY KEY (requester_id, addressee_id)
    )
  `);

  await createTableIfMissing(pool, "blocks", `
    CREATE TABLE blocks (
      blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      blocked_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      reason VARCHAR(64),
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      CHECK (blocker_id <> blocked_id),
      PRIMARY KEY (blocker_id, blocked_id)
    )
  `);

  await createTableIfMissing(pool, "mutes", `
    CREATE TABLE mutes (
      muter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      muted_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      mute_type VARCHAR(24) NOT NULL DEFAULT 'all',
      expires_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      CHECK (muter_id <> muted_user_id),
      PRIMARY KEY (muter_id, muted_user_id, mute_type)
    )
  `);

  await createTableIfMissing(pool, "topic_catalog", `
    CREATE TABLE topic_catalog (
      id UUID PRIMARY KEY,
      slug VARCHAR(80) NOT NULL UNIQUE,
      name VARCHAR(120) NOT NULL,
      description TEXT,
      parent_topic_id UUID REFERENCES topic_catalog(id) ON DELETE SET NULL,
      is_active BOOLEAN NOT NULL DEFAULT true,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  await createTableIfMissing(pool, "post_stats", `
    CREATE TABLE post_stats (
      post_id UUID PRIMARY KEY REFERENCES posts(id) ON DELETE CASCADE,
      likes_count BIGINT NOT NULL DEFAULT 0,
      comments_count BIGINT NOT NULL DEFAULT 0,
      shares_count BIGINT NOT NULL DEFAULT 0,
      bookmarks_count BIGINT NOT NULL DEFAULT 0,
      impressions_count BIGINT NOT NULL DEFAULT 0,
      reads_count BIGINT NOT NULL DEFAULT 0,
      profile_clicks_count BIGINT NOT NULL DEFAULT 0,
      engagement_score DOUBLE PRECISION NOT NULL DEFAULT 0,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  await createTableIfMissing(pool, "hashtags", `
    CREATE TABLE hashtags (
      id UUID PRIMARY KEY,
      tag VARCHAR(96) NOT NULL,
      tag_normalized VARCHAR(96) NOT NULL UNIQUE,
      posts_count BIGINT NOT NULL DEFAULT 0,
      engagement_score DOUBLE PRECISION NOT NULL DEFAULT 0,
      last_used_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  await createTableIfMissing(pool, "feed_algorithm_versions", `
    CREATE TABLE feed_algorithm_versions (
      id UUID PRIMARY KEY,
      name VARCHAR(96) NOT NULL,
      version VARCHAR(48) NOT NULL,
      config JSONB NOT NULL DEFAULT '{}'::jsonb,
      is_active BOOLEAN NOT NULL DEFAULT false,
      rollout_percent INTEGER NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      activated_at TIMESTAMPTZ,
      UNIQUE (name, version)
    )
  `);

  await createTableIfMissing(pool, "feed_requests", `
    CREATE TABLE feed_requests (
      id UUID PRIMARY KEY,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      algorithm_version_id UUID REFERENCES feed_algorithm_versions(id) ON DELETE SET NULL,
      feed_type VARCHAR(24) NOT NULL,
      cursor_in TEXT,
      cursor_out TEXT,
      request_context JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  await createTableIfMissing(pool, "post_engagement_windows", `
    CREATE TABLE post_engagement_windows (
      post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
      window_start TIMESTAMPTZ NOT NULL,
      window_size_minutes INTEGER NOT NULL,
      impressions_count BIGINT NOT NULL DEFAULT 0,
      likes_count BIGINT NOT NULL DEFAULT 0,
      comments_count BIGINT NOT NULL DEFAULT 0,
      shares_count BIGINT NOT NULL DEFAULT 0,
      reads_count BIGINT NOT NULL DEFAULT 0,
      engagement_score DOUBLE PRECISION NOT NULL DEFAULT 0,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (post_id, window_start, window_size_minutes)
    )
  `);

  await createTableIfMissing(pool, "notification_preferences", `
    CREATE TABLE notification_preferences (
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      channel VARCHAR(24) NOT NULL,
      enabled BOOLEAN NOT NULL DEFAULT true,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (user_id, channel)
    )
  `);

  await createTableIfMissing(pool, "reports", `
    CREATE TABLE reports (
      id UUID PRIMARY KEY,
      reporter_id UUID REFERENCES users(id) ON DELETE SET NULL,
      target_type VARCHAR(32) NOT NULL,
      target_uuid UUID NOT NULL,
      reason VARCHAR(64) NOT NULL,
      details TEXT,
      status VARCHAR(24) NOT NULL DEFAULT 'open',
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      resolved_at TIMESTAMPTZ
    )
  `);

  await createTableIfMissing(pool, "moderation_cases", `
    CREATE TABLE moderation_cases (
      id UUID PRIMARY KEY,
      target_type VARCHAR(32) NOT NULL,
      target_uuid UUID NOT NULL,
      status VARCHAR(24) NOT NULL DEFAULT 'open',
      priority INTEGER NOT NULL DEFAULT 0,
      assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
      opened_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      closed_at TIMESTAMPTZ,
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb
    )
  `);

  await createTableIfMissing(pool, "moderation_case_reports", `
    CREATE TABLE moderation_case_reports (
      case_id UUID NOT NULL REFERENCES moderation_cases(id) ON DELETE CASCADE,
      report_id UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (case_id, report_id)
    )
  `);

  await createTableIfMissing(pool, "moderation_case_notes", `
    CREATE TABLE moderation_case_notes (
      id BIGSERIAL PRIMARY KEY,
      case_id UUID NOT NULL REFERENCES moderation_cases(id) ON DELETE CASCADE,
      author_id UUID REFERENCES users(id) ON DELETE SET NULL,
      note TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  await createTableIfMissing(pool, "moderation_actions", `
    CREATE TABLE moderation_actions (
      id UUID PRIMARY KEY,
      case_id UUID REFERENCES moderation_cases(id) ON DELETE SET NULL,
      actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
      action_type VARCHAR(64) NOT NULL,
      target_type VARCHAR(32) NOT NULL,
      target_uuid UUID NOT NULL,
      reason TEXT,
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  await createTableIfMissing(pool, "user_restrictions", `
    CREATE TABLE user_restrictions (
      id UUID PRIMARY KEY,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      restriction_type VARCHAR(64) NOT NULL,
      starts_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      expires_at TIMESTAMPTZ,
      reason TEXT,
      created_by UUID REFERENCES users(id) ON DELETE SET NULL,
      lifted_at TIMESTAMPTZ
    )
  `);

  await createTableIfMissing(pool, "content_labels", `
    CREATE TABLE content_labels (
      id UUID PRIMARY KEY,
      label_key VARCHAR(64) NOT NULL UNIQUE,
      display_name VARCHAR(120) NOT NULL,
      severity INTEGER NOT NULL DEFAULT 0,
      is_active BOOLEAN NOT NULL DEFAULT true
    )
  `);

  await createTableIfMissing(pool, "post_content_labels", `
    CREATE TABLE post_content_labels (
      post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
      label_id UUID NOT NULL REFERENCES content_labels(id) ON DELETE CASCADE,
      source VARCHAR(32) NOT NULL DEFAULT 'system',
      confidence REAL NOT NULL DEFAULT 1,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (post_id, label_id, source)
    )
  `);

  await createTableIfMissing(pool, "spam_signals", `
    CREATE TABLE spam_signals (
      id BIGSERIAL PRIMARY KEY,
      user_id UUID REFERENCES users(id) ON DELETE SET NULL,
      entity_type VARCHAR(32) NOT NULL,
      entity_uuid UUID,
      signal_key VARCHAR(64) NOT NULL,
      signal_value DOUBLE PRECISION NOT NULL DEFAULT 1,
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  await pool.query(`
    ALTER TABLE reports ADD COLUMN IF NOT EXISTS details TEXT;
    ALTER TABLE moderation_cases ADD COLUMN IF NOT EXISTS assigned_to UUID REFERENCES users(id) ON DELETE SET NULL;
    ALTER TABLE moderation_cases ADD COLUMN IF NOT EXISTS opened_at TIMESTAMPTZ NOT NULL DEFAULT now();
    ALTER TABLE moderation_cases ADD COLUMN IF NOT EXISTS closed_at TIMESTAMPTZ;
    ALTER TABLE moderation_cases ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

    CREATE INDEX IF NOT EXISTS idx_reports_target_status
      ON reports (target_type, target_uuid, status, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_reports_reporter_created
      ON reports (reporter_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_moderation_cases_status_priority
      ON moderation_cases (status, priority DESC, opened_at ASC);
    CREATE INDEX IF NOT EXISTS idx_moderation_actions_target_created
      ON moderation_actions (target_type, target_uuid, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_user_restrictions_active
      ON user_restrictions (user_id, restriction_type, expires_at)
      WHERE lifted_at IS NULL;
    CREATE INDEX IF NOT EXISTS idx_spam_signals_entity_created
      ON spam_signals (entity_type, entity_uuid, created_at DESC);
  `);

  await createTableIfMissing(pool, "media_objects", `
    CREATE TABLE media_objects (
      id UUID PRIMARY KEY,
      owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
      bucket VARCHAR(96) NOT NULL,
      object_key TEXT NOT NULL,
      media_type VARCHAR(32) NOT NULL,
      mime_type VARCHAR(120) NOT NULL,
      byte_size BIGINT NOT NULL,
      width INTEGER,
      height INTEGER,
      duration_ms INTEGER,
      checksum_sha256 TEXT,
      processing_status VARCHAR(32) NOT NULL DEFAULT 'pending',
      moderation_status VARCHAR(32) NOT NULL DEFAULT 'pending',
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      deleted_at TIMESTAMPTZ
    )
  `);

  await createTableIfMissing(pool, "upload_sessions", `
    CREATE TABLE upload_sessions (
      id UUID PRIMARY KEY,
      owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      media_object_id UUID REFERENCES media_objects(id) ON DELETE SET NULL,
      upload_type VARCHAR(32) NOT NULL,
      status VARCHAR(32) NOT NULL DEFAULT 'pending',
      expected_byte_size BIGINT,
      expires_at TIMESTAMPTZ NOT NULL,
      completed_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb
    )
  `);

  await createTableIfMissing(pool, "outbox_events", `
    CREATE TABLE outbox_events (
      id UUID PRIMARY KEY,
      aggregate_type VARCHAR(64) NOT NULL,
      aggregate_uuid UUID,
      event_type VARCHAR(96) NOT NULL,
      payload JSONB NOT NULL,
      status VARCHAR(24) NOT NULL DEFAULT 'pending',
      attempts INTEGER NOT NULL DEFAULT 0,
      available_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      processed_at TIMESTAMPTZ,
      last_error TEXT
    )
  `);

  await createTableIfMissing(pool, "processed_events", `
    CREATE TABLE processed_events (
      consumer_name VARCHAR(96) NOT NULL,
      event_id UUID NOT NULL,
      processed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (consumer_name, event_id)
    )
  `);

  await createTableIfMissing(pool, "dead_letter_events", `
    CREATE TABLE dead_letter_events (
      id UUID PRIMARY KEY,
      source_event_id UUID,
      source_table VARCHAR(96) NOT NULL,
      event_type VARCHAR(96) NOT NULL,
      payload JSONB NOT NULL,
      error_message TEXT NOT NULL,
      failed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb
    )
  `);

  await createTableIfMissing(pool, "idempotency_keys", `
    CREATE TABLE idempotency_keys (
      key VARCHAR(160) PRIMARY KEY,
      user_id UUID REFERENCES users(id) ON DELETE CASCADE,
      request_hash TEXT NOT NULL,
      response_status INTEGER,
      response_body JSONB,
      locked_until TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      expires_at TIMESTAMPTZ NOT NULL
    )
  `);

  await createTableIfMissing(pool, "background_job_runs", `
    CREATE TABLE background_job_runs (
      id UUID PRIMARY KEY,
      job_name VARCHAR(96) NOT NULL,
      status VARCHAR(24) NOT NULL DEFAULT 'running',
      started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      finished_at TIMESTAMPTZ,
      duration_ms INTEGER,
      stats JSONB NOT NULL DEFAULT '{}'::jsonb,
      error_message TEXT
    )
  `);

  await createTableIfMissing(pool, "background_job_locks", `
    CREATE TABLE background_job_locks (
      lock_key VARCHAR(120) PRIMARY KEY,
      owner_id VARCHAR(120) NOT NULL,
      locked_until TIMESTAMPTZ NOT NULL,
      acquired_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  await createTableIfMissing(pool, "feature_flags", `
    CREATE TABLE feature_flags (
      key VARCHAR(96) PRIMARY KEY,
      description TEXT,
      enabled BOOLEAN NOT NULL DEFAULT false,
      rollout_percent INTEGER NOT NULL DEFAULT 0,
      rules JSONB NOT NULL DEFAULT '{}'::jsonb,
      updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  await createTableIfMissing(pool, "app_config_versions", `
    CREATE TABLE app_config_versions (
      id UUID PRIMARY KEY,
      config_key VARCHAR(96) NOT NULL,
      version INTEGER NOT NULL,
      config JSONB NOT NULL,
      is_active BOOLEAN NOT NULL DEFAULT false,
      created_by UUID REFERENCES users(id) ON DELETE SET NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      activated_at TIMESTAMPTZ,
      UNIQUE (config_key, version)
    )
  `);

  await createTableIfMissing(pool, "admin_audit_logs", `
    CREATE TABLE admin_audit_logs (
      id BIGSERIAL PRIMARY KEY,
      actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
      action VARCHAR(96) NOT NULL,
      target_type VARCHAR(64),
      target_uuid UUID,
      ip_address INET,
      user_agent TEXT,
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
      occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
}

async function refreshFoundationBackfills(pool: pg.Pool): Promise<void> {
  await ensureBackfillColumns(pool);
  await backfillPrimaryUuidColumns(pool);
  await remapPrimaryUuidReferences(pool);
  await remapExtendedUuidReferences(pool);
  await refreshCommentUuidReferences(pool);
}

async function ensureBackfillColumns(pool: pg.Pool): Promise<void> {
  await pool.query(`
    ALTER TABLE users ADD COLUMN IF NOT EXISTS id UUID;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS handle VARCHAR(30);
    ALTER TABLE users ADD COLUMN IF NOT EXISTS handle_normalized VARCHAR(30);
    ALTER TABLE users ADD COLUMN IF NOT EXISTS display_name VARCHAR(80);
    ALTER TABLE users ADD COLUMN IF NOT EXISTS account_status VARCHAR(24) NOT NULL DEFAULT 'active';
    ALTER TABLE users ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT false;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS is_private BOOLEAN NOT NULL DEFAULT false;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(32) NOT NULL DEFAULT 'user';
    ALTER TABLE users ADD COLUMN IF NOT EXISTS language_code VARCHAR(12) NOT NULL DEFAULT 'en';
    ALTER TABLE users ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

    ALTER TABLE posts ADD COLUMN IF NOT EXISTS id UUID;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS author_uuid UUID;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS visibility VARCHAR(24) NOT NULL DEFAULT 'public';
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS status VARCHAR(24) NOT NULL DEFAULT 'published';
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS language_code VARCHAR(12);
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS moderation_state VARCHAR(24) NOT NULL DEFAULT 'clean';
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS last_engagement_at TIMESTAMPTZ;

    ALTER TABLE conversations ADD COLUMN IF NOT EXISTS id UUID;
    ALTER TABLE conversations ADD COLUMN IF NOT EXISTS created_by_uuid UUID;
    ALTER TABLE conversations ADD COLUMN IF NOT EXISTS conversation_type VARCHAR(24) NOT NULL DEFAULT 'direct';
    ALTER TABLE conversations ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ;
    ALTER TABLE conversations ADD COLUMN IF NOT EXISTS member_count INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE conversations ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

    ALTER TABLE messages ADD COLUMN IF NOT EXISTS message_uuid UUID;
    ALTER TABLE messages ADD COLUMN IF NOT EXISTS conversation_uuid UUID;
    ALTER TABLE messages ADD COLUMN IF NOT EXISTS sender_uuid UUID;
    ALTER TABLE messages ADD COLUMN IF NOT EXISTS client_message_uuid UUID;
    ALTER TABLE messages ADD COLUMN IF NOT EXISTS message_type VARCHAR(24) NOT NULL DEFAULT 'text';
    ALTER TABLE messages ADD COLUMN IF NOT EXISTS body_text TEXT;
    ALTER TABLE messages ADD COLUMN IF NOT EXISTS sequence_id BIGINT;
    ALTER TABLE messages ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ;
    ALTER TABLE messages ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS notification_uuid UUID;
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS recipient_uuid UUID;
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS actor_uuid UUID;
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS notification_type VARCHAR(48);
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS entity_type VARCHAR(48);
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS entity_uuid UUID;
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS clicked_at TIMESTAMPTZ;
    ALTER TABLE notifications ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

    ALTER TABLE follows ADD COLUMN IF NOT EXISTS follower_uuid UUID;
    ALTER TABLE follows ADD COLUMN IF NOT EXISTS following_uuid UUID;
    ALTER TABLE follows ADD COLUMN IF NOT EXISTS source VARCHAR(32) NOT NULL DEFAULT 'app';

    ALTER TABLE post_likes ADD COLUMN IF NOT EXISTS post_uuid UUID;
    ALTER TABLE post_likes ADD COLUMN IF NOT EXISTS user_uuid UUID;
    ALTER TABLE post_likes ADD COLUMN IF NOT EXISTS reaction_type VARCHAR(24) NOT NULL DEFAULT 'like';

    ALTER TABLE post_topics ADD COLUMN IF NOT EXISTS post_uuid UUID;
    ALTER TABLE post_topics ADD COLUMN IF NOT EXISTS topic_id UUID;
    ALTER TABLE post_topics ADD COLUMN IF NOT EXISTS confidence_score REAL NOT NULL DEFAULT 1;
    ALTER TABLE post_topics ADD COLUMN IF NOT EXISTS source VARCHAR(32) NOT NULL DEFAULT 'legacy';

    ALTER TABLE post_trend_snapshots ADD COLUMN IF NOT EXISTS post_uuid UUID;
    ALTER TABLE post_trend_snapshots ADD COLUMN IF NOT EXISTS scope_type VARCHAR(24) NOT NULL DEFAULT 'global';
    ALTER TABLE post_trend_snapshots ADD COLUMN IF NOT EXISTS scope_key VARCHAR(96) NOT NULL DEFAULT 'global';
    ALTER TABLE post_trend_snapshots ADD COLUMN IF NOT EXISTS trending_score DOUBLE PRECISION NOT NULL DEFAULT 0;

    ALTER TABLE feed_impressions ADD COLUMN IF NOT EXISTS request_uuid UUID;
    ALTER TABLE feed_impressions ADD COLUMN IF NOT EXISTS user_uuid UUID;
    ALTER TABLE feed_impressions ADD COLUMN IF NOT EXISTS post_uuid UUID;
    ALTER TABLE feed_impressions ADD COLUMN IF NOT EXISTS rank_position INTEGER;
    ALTER TABLE feed_impressions ADD COLUMN IF NOT EXISTS score DOUBLE PRECISION;
    ALTER TABLE feed_impressions ADD COLUMN IF NOT EXISTS reason_codes TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];
    ALTER TABLE feed_impressions ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

    ALTER TABLE feed_events ADD COLUMN IF NOT EXISTS request_uuid UUID;
    ALTER TABLE feed_events ADD COLUMN IF NOT EXISTS user_uuid UUID;
    ALTER TABLE feed_events ADD COLUMN IF NOT EXISTS post_uuid UUID;
    ALTER TABLE feed_events ADD COLUMN IF NOT EXISTS entity_type VARCHAR(32) NOT NULL DEFAULT 'post';
    ALTER TABLE feed_events ADD COLUMN IF NOT EXISTS dwell_ms INTEGER;
    ALTER TABLE feed_events ADD COLUMN IF NOT EXISTS weight REAL NOT NULL DEFAULT 1;

    ALTER TABLE feed_served_history ADD COLUMN IF NOT EXISTS user_uuid UUID;
    ALTER TABLE feed_served_history ADD COLUMN IF NOT EXISTS post_uuid UUID;
    ALTER TABLE feed_served_history ADD COLUMN IF NOT EXISTS source VARCHAR(32) NOT NULL DEFAULT 'feed';
    ALTER TABLE feed_served_history ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

    ALTER TABLE user_topic_affinities ADD COLUMN IF NOT EXISTS user_uuid UUID;
    ALTER TABLE user_topic_affinities ADD COLUMN IF NOT EXISTS topic_id UUID;
    ALTER TABLE user_topic_affinities ADD COLUMN IF NOT EXISTS affinity_score DOUBLE PRECISION NOT NULL DEFAULT 0;
    ALTER TABLE user_topic_affinities ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

    ALTER TABLE user_author_affinities ADD COLUMN IF NOT EXISTS user_uuid UUID;
    ALTER TABLE user_author_affinities ADD COLUMN IF NOT EXISTS author_uuid UUID;
    ALTER TABLE user_author_affinities ADD COLUMN IF NOT EXISTS affinity_score DOUBLE PRECISION NOT NULL DEFAULT 0;
    ALTER TABLE user_author_affinities ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

    ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS conversation_uuid UUID;
    ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS user_uuid UUID;
    ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS member_role VARCHAR(24) NOT NULL DEFAULT 'member';
    ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS status VARCHAR(24) NOT NULL DEFAULT 'active';
    ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS last_read_message_uuid UUID;
    ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS last_read_sequence_id BIGINT NOT NULL DEFAULT 0;
    ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS muted_until TIMESTAMPTZ;
    ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;

    ALTER TABLE comments ADD COLUMN IF NOT EXISTS id UUID;
    ALTER TABLE comments ADD COLUMN IF NOT EXISTS post_uuid UUID;
    ALTER TABLE comments ADD COLUMN IF NOT EXISTS author_uuid UUID;
    ALTER TABLE comments ADD COLUMN IF NOT EXISTS parent_comment_uuid UUID;
    ALTER TABLE comments ADD COLUMN IF NOT EXISTS depth INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE comments ADD COLUMN IF NOT EXISTS likes_count BIGINT NOT NULL DEFAULT 0;
    ALTER TABLE comments ADD COLUMN IF NOT EXISTS replies_count BIGINT NOT NULL DEFAULT 0;
    ALTER TABLE comments ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ;
    ALTER TABLE comments ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

    ALTER TABLE comment_likes ADD COLUMN IF NOT EXISTS comment_uuid UUID;
    ALTER TABLE comment_likes ADD COLUMN IF NOT EXISTS user_uuid UUID;

    CREATE UNIQUE INDEX IF NOT EXISTS idx_users_uuid_unique ON users (id);
    CREATE UNIQUE INDEX IF NOT EXISTS idx_posts_uuid_unique ON posts (id);
    CREATE UNIQUE INDEX IF NOT EXISTS idx_conversations_uuid_unique ON conversations (id);
    CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_uuid_unique ON messages (message_uuid);
    CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_uuid_unique ON notifications (notification_uuid);
    CREATE UNIQUE INDEX IF NOT EXISTS idx_comments_uuid_unique ON comments (id);
  `);
}

async function refreshCommentUuidReferences(pool: pg.Pool): Promise<void> {
  await ensureBackfillColumns(pool);
  await backfillUuidColumn(pool, "comments", "comment_id", "id", "comment");
  await pool.query(`
    UPDATE comments SET post_uuid = posts.id FROM posts WHERE comments.post_id = posts.post_id AND comments.post_uuid IS NULL;
    UPDATE comments SET author_uuid = users.id FROM users WHERE comments.author_id = users.user_id AND comments.author_uuid IS NULL;
    UPDATE comments SET parent_comment_uuid = parent.id FROM comments parent WHERE comments.parent_comment_id = parent.comment_id AND comments.parent_comment_uuid IS NULL;
    ALTER TABLE comment_likes ADD COLUMN IF NOT EXISTS comment_uuid UUID;
    UPDATE comment_likes SET comment_uuid = comments.id FROM comments WHERE comment_likes.comment_id = comments.comment_id AND comment_likes.comment_uuid IS NULL;
    ALTER TABLE comment_likes ADD COLUMN IF NOT EXISTS user_uuid UUID;
    UPDATE comment_likes SET user_uuid = users.id FROM users WHERE comment_likes.user_id = users.user_id AND comment_likes.user_uuid IS NULL;
    CREATE UNIQUE INDEX IF NOT EXISTS idx_comment_likes_uuid_unique ON comment_likes (comment_uuid, user_uuid);
  `);
}

function deterministicUuid(namespace: string, value: string): string {
  const bytes = createHash("sha256").update(`${namespace}:${value}`).digest();
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.subarray(0, 16).toString("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`;
}

async function backfillPrimaryUuidColumns(pool: pg.Pool): Promise<void> {
  await backfillUuidColumn(pool, "users", "user_id", "id", "user");
  await backfillUuidColumn(pool, "posts", "post_id", "id", "post");
  await backfillUuidColumn(pool, "conversations", "conversation_id", "id", "conversation");
  await backfillUuidColumn(pool, "messages", "message_id", "message_uuid", "message");
  await backfillUuidColumn(pool, "notifications", "notification_id", "notification_uuid", "notification");
}

async function backfillUuidColumn(
  pool: pg.Pool,
  table: string,
  legacyColumn: string,
  uuidColumn: string,
  namespace: string
): Promise<void> {
  for (;;) {
    const result = await pool.query<{ legacy_value: string }>(
      `SELECT ${legacyColumn} AS legacy_value
       FROM ${table}
       WHERE ${uuidColumn} IS NULL
         AND COALESCE(${legacyColumn}, '') <> ''
       ORDER BY ${legacyColumn}
       LIMIT 500`
    );
    if (result.rows.length === 0) {
      return;
    }
    for (const row of result.rows) {
      await pool.query(
        `UPDATE ${table} SET ${uuidColumn} = $1 WHERE ${legacyColumn} = $2 AND ${uuidColumn} IS NULL`,
        [deterministicUuid(namespace, row.legacy_value), row.legacy_value]
      );
    }
  }
}

async function remapPrimaryUuidReferences(pool: pg.Pool): Promise<void> {
  await pool.query(`
    UPDATE users SET handle = substring(username from 1 for 30) WHERE handle IS NULL;
    UPDATE users SET handle_normalized = lower(handle) WHERE handle_normalized IS NULL AND handle IS NOT NULL;
    UPDATE posts SET author_uuid = users.id FROM users WHERE posts.author_id = users.user_id AND posts.author_uuid IS NULL;
    UPDATE conversations SET created_by_uuid = users.id FROM users WHERE conversations.owner_user_id = users.user_id AND conversations.created_by_uuid IS NULL;
    UPDATE messages SET conversation_uuid = conversations.id FROM conversations WHERE messages.conversation_id = conversations.conversation_id AND messages.conversation_uuid IS NULL;
    UPDATE messages SET sender_uuid = users.id FROM users WHERE messages.sender_user_id = users.user_id AND messages.sender_uuid IS NULL;
    UPDATE messages SET body_text = body WHERE body_text IS NULL AND body IS NOT NULL;
    UPDATE notifications SET recipient_uuid = users.id FROM users WHERE notifications.user_id = users.user_id AND notifications.recipient_uuid IS NULL;
    UPDATE notifications SET actor_uuid = users.id FROM users WHERE notifications.actor_user_id = users.user_id AND notifications.actor_uuid IS NULL;
    UPDATE notifications SET notification_type = type WHERE notification_type IS NULL AND type IS NOT NULL;
  `);
}

async function remapExtendedUuidReferences(pool: pg.Pool): Promise<void> {
  await pool.query(`
    UPDATE follows SET follower_uuid = users.id FROM users WHERE follows.follower_id = users.user_id AND follows.follower_uuid IS NULL;
    UPDATE follows SET following_uuid = users.id FROM users WHERE follows.following_id = users.user_id AND follows.following_uuid IS NULL;
    UPDATE post_likes SET post_uuid = posts.id FROM posts WHERE post_likes.post_id = posts.post_id AND post_likes.post_uuid IS NULL;
    UPDATE post_likes SET user_uuid = users.id FROM users WHERE post_likes.user_id = users.user_id AND post_likes.user_uuid IS NULL;
    UPDATE post_topics SET post_uuid = posts.id FROM posts WHERE post_topics.post_id = posts.post_id AND post_topics.post_uuid IS NULL;
    UPDATE post_trend_snapshots SET post_uuid = posts.id FROM posts WHERE post_trend_snapshots.post_id = posts.post_id AND post_trend_snapshots.post_uuid IS NULL;
    UPDATE feed_impressions SET user_uuid = users.id FROM users WHERE feed_impressions.user_id = users.user_id AND feed_impressions.user_uuid IS NULL;
    UPDATE feed_impressions SET post_uuid = posts.id FROM posts WHERE feed_impressions.post_id = posts.post_id AND feed_impressions.post_uuid IS NULL;
    UPDATE feed_events SET user_uuid = users.id FROM users WHERE feed_events.user_id = users.user_id AND feed_events.user_uuid IS NULL;
    UPDATE feed_events SET post_uuid = posts.id FROM posts WHERE feed_events.post_id = posts.post_id AND feed_events.post_uuid IS NULL;
    UPDATE feed_served_history SET user_uuid = users.id FROM users WHERE feed_served_history.user_id = users.user_id AND feed_served_history.user_uuid IS NULL;
    UPDATE feed_served_history SET post_uuid = posts.id FROM posts WHERE feed_served_history.post_id = posts.post_id AND feed_served_history.post_uuid IS NULL;
    UPDATE user_topic_affinities SET user_uuid = users.id FROM users WHERE user_topic_affinities.user_id = users.user_id AND user_topic_affinities.user_uuid IS NULL;
    UPDATE user_author_affinities SET user_uuid = users.id FROM users WHERE user_author_affinities.user_id = users.user_id AND user_author_affinities.user_uuid IS NULL;
    UPDATE user_author_affinities SET author_uuid = users.id FROM users WHERE user_author_affinities.author_id = users.user_id AND user_author_affinities.author_uuid IS NULL;
    UPDATE conversation_members SET conversation_uuid = conversations.id FROM conversations WHERE conversation_members.conversation_id = conversations.conversation_id AND conversation_members.conversation_uuid IS NULL;
    UPDATE conversation_members SET user_uuid = users.id FROM users WHERE conversation_members.user_id = users.user_id AND conversation_members.user_uuid IS NULL;
  `);
}

async function seedFoundationData(pool: pg.Pool): Promise<void> {
  await pool.query(`
    INSERT INTO roles (id, name, description) VALUES
      ('00000000-0000-0000-0000-000000000101', 'user', 'Default Prava user'),
      ('00000000-0000-0000-0000-000000000102', 'moderator', 'Content moderation operator'),
      ('00000000-0000-0000-0000-000000000103', 'support', 'Customer support operator'),
      ('00000000-0000-0000-0000-000000000104', 'admin', 'Administrative operator'),
      ('00000000-0000-0000-0000-000000000105', 'super_admin', 'Full platform operator')
    ON CONFLICT (name) DO UPDATE SET description = EXCLUDED.description;

    INSERT INTO permissions (id, name, description) VALUES
      ('00000000-0000-0000-0000-000000000201', 'feed:read', 'Read personalized feeds'),
      ('00000000-0000-0000-0000-000000000202', 'post:create', 'Create posts'),
      ('00000000-0000-0000-0000-000000000203', 'post:moderate', 'Moderate posts'),
      ('00000000-0000-0000-0000-000000000204', 'chat:read', 'Read conversations'),
      ('00000000-0000-0000-0000-000000000205', 'chat:write', 'Send conversation messages'),
      ('00000000-0000-0000-0000-000000000206', 'notification:manage', 'Manage notification delivery'),
      ('00000000-0000-0000-0000-000000000207', 'admin:audit:read', 'Read admin audit logs'),
      ('00000000-0000-0000-0000-000000000208', 'config:manage', 'Manage platform configuration')
    ON CONFLICT (name) DO UPDATE SET description = EXCLUDED.description;

    INSERT INTO role_permissions (role_id, permission_id) VALUES
      ('00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000201'),
      ('00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000202'),
      ('00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000204'),
      ('00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000205'),
      ('00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000201'),
      ('00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000202'),
      ('00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000203'),
      ('00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000204'),
      ('00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000205'),
      ('00000000-0000-0000-0000-000000000103', '00000000-0000-0000-0000-000000000201'),
      ('00000000-0000-0000-0000-000000000103', '00000000-0000-0000-0000-000000000204'),
      ('00000000-0000-0000-0000-000000000103', '00000000-0000-0000-0000-000000000206'),
      ('00000000-0000-0000-0000-000000000104', '00000000-0000-0000-0000-000000000201'),
      ('00000000-0000-0000-0000-000000000104', '00000000-0000-0000-0000-000000000202'),
      ('00000000-0000-0000-0000-000000000104', '00000000-0000-0000-0000-000000000203'),
      ('00000000-0000-0000-0000-000000000104', '00000000-0000-0000-0000-000000000204'),
      ('00000000-0000-0000-0000-000000000104', '00000000-0000-0000-0000-000000000205'),
      ('00000000-0000-0000-0000-000000000104', '00000000-0000-0000-0000-000000000206'),
      ('00000000-0000-0000-0000-000000000104', '00000000-0000-0000-0000-000000000207'),
      ('00000000-0000-0000-0000-000000000104', '00000000-0000-0000-0000-000000000208'),
      ('00000000-0000-0000-0000-000000000105', '00000000-0000-0000-0000-000000000201'),
      ('00000000-0000-0000-0000-000000000105', '00000000-0000-0000-0000-000000000202'),
      ('00000000-0000-0000-0000-000000000105', '00000000-0000-0000-0000-000000000203'),
      ('00000000-0000-0000-0000-000000000105', '00000000-0000-0000-0000-000000000204'),
      ('00000000-0000-0000-0000-000000000105', '00000000-0000-0000-0000-000000000205'),
      ('00000000-0000-0000-0000-000000000105', '00000000-0000-0000-0000-000000000206'),
      ('00000000-0000-0000-0000-000000000105', '00000000-0000-0000-0000-000000000207'),
      ('00000000-0000-0000-0000-000000000105', '00000000-0000-0000-0000-000000000208')
    ON CONFLICT DO NOTHING;

    INSERT INTO topic_catalog (id, slug, name, description) VALUES
      ('00000000-0000-0000-0000-000000000301', 'general', 'General', 'General Prava content'),
      ('00000000-0000-0000-0000-000000000302', 'technology', 'Technology', 'Technology and software'),
      ('00000000-0000-0000-0000-000000000303', 'education', 'Education', 'Learning and campus life'),
      ('00000000-0000-0000-0000-000000000304', 'life', 'Life', 'Daily life and personal updates'),
      ('00000000-0000-0000-0000-000000000305', 'creative', 'Creative', 'Art, writing, and creative work')
    ON CONFLICT (slug) DO UPDATE SET
      name = EXCLUDED.name,
      description = EXCLUDED.description,
      is_active = true;

    INSERT INTO feed_algorithm_versions (id, name, version, config, is_active, rollout_percent, activated_at)
    VALUES (
      '00000000-0000-0000-0000-000000000401',
      'prava-personalized-feed',
      '1.0.0',
      '{"ranking":"engagement_recency_affinity","dedupe_window_hours":72}'::jsonb,
      true,
      100,
      now()
    )
    ON CONFLICT (name, version) DO UPDATE SET
      config = EXCLUDED.config,
      is_active = EXCLUDED.is_active,
      rollout_percent = EXCLUDED.rollout_percent,
      activated_at = COALESCE(feed_algorithm_versions.activated_at, EXCLUDED.activated_at);

    INSERT INTO feature_flags (key, description, enabled, rollout_percent, rules)
    VALUES
      ('feed.personalized.v1', 'Enable personalized feed ranking', true, 100, '{}'::jsonb),
      ('notifications.push.v1', 'Enable push notification delivery', true, 100, '{}'::jsonb),
      ('settings.account_center.username_change', 'Enable account center username change flow', true, 100, '{}'::jsonb),
      ('moderation.case_queue.v1', 'Enable moderation case queue', true, 100, '{}'::jsonb)
    ON CONFLICT (key) DO UPDATE SET
      description = EXCLUDED.description,
      enabled = EXCLUDED.enabled,
      rollout_percent = EXCLUDED.rollout_percent,
      rules = EXCLUDED.rules,
      updated_at = now();

    INSERT INTO content_labels (id, label_key, display_name, severity, is_active)
    VALUES
      ('00000000-0000-0000-0000-000000000501', 'spam', 'Spam', 80, true),
      ('00000000-0000-0000-0000-000000000502', 'harassment', 'Harassment', 90, true),
      ('00000000-0000-0000-0000-000000000503', 'sensitive', 'Sensitive content', 50, true),
      ('00000000-0000-0000-0000-000000000504', 'misinformation', 'Misinformation', 70, true)
    ON CONFLICT (label_key) DO UPDATE SET
      display_name = EXCLUDED.display_name,
      severity = EXCLUDED.severity,
      is_active = EXCLUDED.is_active;
  `);
}
