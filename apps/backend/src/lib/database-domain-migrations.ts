import type pg from "pg";

export async function runDatabaseDomainMigrations(pool: pg.Pool): Promise<void> {
  if (await isDomainExpansionApplied(pool)) {
    await refreshDomainReferences(pool);
    await seedDomainData(pool);
    return;
  }

  await pool.query(`
    INSERT INTO schema_migrations (version, checksum, description)
    VALUES ('0002_database_domain_expansion', 'runtime-additive-v1', 'Prava domain-complete database expansion')
    ON CONFLICT (version) DO UPDATE SET
      applied_at = EXCLUDED.applied_at,
      checksum = EXCLUDED.checksum,
      description = EXCLUDED.description;

    ALTER TABLE users ADD COLUMN IF NOT EXISTS account_visibility VARCHAR(20) NOT NULL DEFAULT 'public';
    ALTER TABLE users ADD COLUMN IF NOT EXISTS primary_email_id UUID;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS primary_phone_id UUID;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS onboarding_completed_at TIMESTAMPTZ;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS updated_at_v2 TIMESTAMPTZ NOT NULL DEFAULT now();
    CREATE INDEX IF NOT EXISTS idx_users_active_visible
      ON users (created_at DESC)
      WHERE deleted_at IS NULL AND account_status = 'active';
    CREATE INDEX IF NOT EXISTS idx_users_account_visibility ON users (account_visibility);

    ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS display_name VARCHAR(100);
    UPDATE user_profiles SET display_name = '' WHERE display_name IS NULL;
    ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS banner_media_id UUID;
    ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS birth_date DATE;
    ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS search_vector TEXT;
    CREATE INDEX IF NOT EXISTS idx_user_profiles_display_name ON user_profiles (display_name);

    ALTER TABLE user_stats ADD COLUMN IF NOT EXISTS replies_count BIGINT NOT NULL DEFAULT 0;
    ALTER TABLE user_stats ADD COLUMN IF NOT EXISTS likes_received BIGINT NOT NULL DEFAULT 0;

    ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS user_uuid UUID;
    UPDATE user_settings SET user_uuid = users.id FROM users WHERE user_settings.user_id = users.user_id AND user_settings.user_uuid IS NULL;
    ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS language_code VARCHAR(10) NOT NULL DEFAULT 'en';
    ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS timezone_name VARCHAR(100);
    ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS theme VARCHAR(20);
    ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS show_online_status BOOLEAN NOT NULL DEFAULT true;
    ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS show_read_receipts BOOLEAN NOT NULL DEFAULT true;
    ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS autoplay_enabled BOOLEAN NOT NULL DEFAULT true;
    ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS content_language_preferences JSONB NOT NULL DEFAULT '[]'::jsonb;
    ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
    CREATE UNIQUE INDEX IF NOT EXISTS idx_user_settings_uuid_unique ON user_settings (user_uuid);

    ALTER TABLE user_privacy_settings ADD COLUMN IF NOT EXISTS dm_policy VARCHAR(30) NOT NULL DEFAULT 'friends';
    ALTER TABLE user_privacy_settings ADD COLUMN IF NOT EXISTS group_invite_policy VARCHAR(30) NOT NULL DEFAULT 'friends';
    ALTER TABLE user_privacy_settings ADD COLUMN IF NOT EXISTS followers_visibility VARCHAR(30) NOT NULL DEFAULT 'public';
    ALTER TABLE user_privacy_settings ADD COLUMN IF NOT EXISTS following_visibility VARCHAR(30) NOT NULL DEFAULT 'public';
    ALTER TABLE user_privacy_settings ADD COLUMN IF NOT EXISTS friends_visibility VARCHAR(30) NOT NULL DEFAULT 'friends';
    ALTER TABLE user_privacy_settings ADD COLUMN IF NOT EXISTS birth_date_visibility VARCHAR(30) NOT NULL DEFAULT 'only_me';
    ALTER TABLE user_privacy_settings ADD COLUMN IF NOT EXISTS location_visibility VARCHAR(30) NOT NULL DEFAULT 'public';
    ALTER TABLE user_privacy_settings ADD COLUMN IF NOT EXISTS allow_profile_discovery BOOLEAN NOT NULL DEFAULT true;
    ALTER TABLE user_privacy_settings ADD COLUMN IF NOT EXISTS allow_search_indexing BOOLEAN NOT NULL DEFAULT true;

    ALTER TABLE user_emails ADD COLUMN IF NOT EXISTS email_normalized VARCHAR(320);
    UPDATE user_emails SET email_normalized = lower(email::text) WHERE email_normalized IS NULL;
    ALTER TABLE user_emails ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
    CREATE UNIQUE INDEX IF NOT EXISTS idx_user_emails_normalized_active
      ON user_emails (email_normalized)
      WHERE deleted_at IS NULL;
    CREATE INDEX IF NOT EXISTS idx_user_emails_user_created ON user_emails (user_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS user_phones (
      id UUID PRIMARY KEY,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      phone_e164 VARCHAR(20) NOT NULL,
      is_primary BOOLEAN NOT NULL DEFAULT false,
      verified_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      deleted_at TIMESTAMPTZ
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_user_phones_phone_active ON user_phones (phone_e164) WHERE deleted_at IS NULL;
    CREATE UNIQUE INDEX IF NOT EXISTS idx_user_phones_primary ON user_phones (user_id) WHERE is_primary = true AND deleted_at IS NULL;

    CREATE TABLE IF NOT EXISTS data_export_requests (
      id UUID PRIMARY KEY,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      status VARCHAR(30) NOT NULL DEFAULT 'requested',
      storage_object_key TEXT,
      requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      completed_at TIMESTAMPTZ,
      expires_at TIMESTAMPTZ
    );
    CREATE INDEX IF NOT EXISTS idx_data_export_requests_user_requested ON data_export_requests (user_id, requested_at DESC);
  `);

  await pool.query(`
    ALTER TABLE user_credentials ADD COLUMN IF NOT EXISTS password_algorithm VARCHAR(30) NOT NULL DEFAULT 'argon2id';
    ALTER TABLE user_credentials ADD COLUMN IF NOT EXISTS password_changed_at TIMESTAMPTZ NOT NULL DEFAULT now();
    ALTER TABLE user_credentials ADD COLUMN IF NOT EXISTS failed_login_count INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE user_credentials ADD COLUMN IF NOT EXISTS locked_until TIMESTAMPTZ;
    ALTER TABLE user_credentials ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
    ALTER TABLE user_credentials ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

    ALTER TABLE user_devices ADD COLUMN IF NOT EXISTS os_version VARCHAR(50);
    ALTER TABLE user_devices ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
    CREATE INDEX IF NOT EXISTS idx_user_devices_user_last_seen ON user_devices (user_id, last_seen_at DESC);

    ALTER TABLE auth_sessions ADD COLUMN IF NOT EXISTS session_family_id UUID;
    ALTER TABLE auth_sessions ADD COLUMN IF NOT EXISTS last_used_at TIMESTAMPTZ;
    ALTER TABLE auth_sessions ADD COLUMN IF NOT EXISTS revoke_reason VARCHAR(100);
    CREATE INDEX IF NOT EXISTS idx_auth_sessions_family ON auth_sessions (session_family_id);
    CREATE INDEX IF NOT EXISTS idx_auth_sessions_expires ON auth_sessions (expires_at);

    ALTER TABLE auth_refresh_tokens ADD COLUMN IF NOT EXISTS parent_token_id UUID;
    ALTER TABLE auth_refresh_tokens ADD COLUMN IF NOT EXISTS replaced_by_token_id UUID;
    ALTER TABLE auth_refresh_tokens ADD COLUMN IF NOT EXISTS issued_at TIMESTAMPTZ NOT NULL DEFAULT now();
    ALTER TABLE auth_refresh_tokens ADD COLUMN IF NOT EXISTS consumed_at TIMESTAMPTZ;
    CREATE INDEX IF NOT EXISTS idx_auth_refresh_tokens_session ON auth_refresh_tokens (session_id);
    CREATE INDEX IF NOT EXISTS idx_auth_refresh_tokens_expires ON auth_refresh_tokens (expires_at);

    ALTER TABLE auth_challenges ADD COLUMN IF NOT EXISTS destination TEXT;
    UPDATE auth_challenges SET destination = target::text WHERE destination IS NULL AND target IS NOT NULL;
    ALTER TABLE auth_challenges ADD COLUMN IF NOT EXISTS challenge_hash TEXT;
    UPDATE auth_challenges SET challenge_hash = code_hash WHERE challenge_hash IS NULL;
    ALTER TABLE auth_challenges ADD COLUMN IF NOT EXISTS attempt_count INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE auth_challenges ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;
    CREATE INDEX IF NOT EXISTS idx_auth_challenges_destination_purpose ON auth_challenges (destination, purpose, created_at DESC);

    ALTER TABLE auth_login_attempts ADD COLUMN IF NOT EXISTS identifier_hash TEXT;
    ALTER TABLE auth_login_attempts ADD COLUMN IF NOT EXISTS occurred_at TIMESTAMPTZ NOT NULL DEFAULT now();
    CREATE INDEX IF NOT EXISTS idx_auth_login_attempts_user_occurred ON auth_login_attempts (user_id, occurred_at DESC);
    CREATE INDEX IF NOT EXISTS idx_auth_login_attempts_occurred ON auth_login_attempts (occurred_at);

    ALTER TABLE security_events ADD COLUMN IF NOT EXISTS severity VARCHAR(20) NOT NULL DEFAULT 'info';
    ALTER TABLE security_events ADD COLUMN IF NOT EXISTS device_id UUID;
    ALTER TABLE security_events ADD COLUMN IF NOT EXISTS occurred_at TIMESTAMPTZ NOT NULL DEFAULT now();
    CREATE INDEX IF NOT EXISTS idx_security_events_occurred ON security_events (occurred_at);

    ALTER TABLE roles ADD COLUMN IF NOT EXISTS role_key VARCHAR(50);
    UPDATE roles SET role_key = name WHERE role_key IS NULL;
    CREATE UNIQUE INDEX IF NOT EXISTS idx_roles_role_key_unique ON roles (role_key);

    ALTER TABLE permissions ADD COLUMN IF NOT EXISTS permission_key VARCHAR(100);
    UPDATE permissions SET permission_key = name WHERE permission_key IS NULL;
    CREATE UNIQUE INDEX IF NOT EXISTS idx_permissions_key_unique ON permissions (permission_key);

    ALTER TABLE user_roles ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMPTZ;
    CREATE INDEX IF NOT EXISTS idx_user_roles_active ON user_roles (user_id, role_id) WHERE revoked_at IS NULL;
  `);

  await pool.query(`
    ALTER TABLE follows ADD COLUMN IF NOT EXISTS follower_uuid UUID;
    ALTER TABLE follows ADD COLUMN IF NOT EXISTS following_uuid UUID;
    ALTER TABLE follows ADD COLUMN IF NOT EXISTS follow_id UUID;
    ALTER TABLE follows ADD COLUMN IF NOT EXISTS status VARCHAR(30) NOT NULL DEFAULT 'active';
    ALTER TABLE follows ADD COLUMN IF NOT EXISTS requested_at TIMESTAMPTZ;
    ALTER TABLE follows ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ;
    ALTER TABLE follows ADD COLUMN IF NOT EXISTS removed_at TIMESTAMPTZ;
    CREATE INDEX IF NOT EXISTS idx_follows_follower_status_created ON follows (follower_uuid, status, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_follows_following_status_created ON follows (following_uuid, status, created_at DESC);

    ALTER TABLE friendships ADD COLUMN IF NOT EXISTS user_low_id UUID;
    ALTER TABLE friendships ADD COLUMN IF NOT EXISTS user_high_id UUID;
    ALTER TABLE friendships ADD COLUMN IF NOT EXISTS formed_at TIMESTAMPTZ;
    CREATE INDEX IF NOT EXISTS idx_friendships_user_low ON friendships (user_low_id);
    CREATE INDEX IF NOT EXISTS idx_friendships_user_high ON friendships (user_high_id);

    ALTER TABLE blocks ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
    ALTER TABLE blocks ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

    ALTER TABLE mutes ADD COLUMN IF NOT EXISTS muted_topic_id UUID;
    ALTER TABLE mutes ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

    CREATE TABLE IF NOT EXISTS user_muted_topics (
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      topic_id UUID NOT NULL REFERENCES topic_catalog(id) ON DELETE CASCADE,
      reason VARCHAR(64),
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      expires_at TIMESTAMPTZ,
      PRIMARY KEY (user_id, topic_id)
    );
  `);

  await pool.query(`
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS post_type VARCHAR(30) NOT NULL DEFAULT 'post';
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS reply_to_post_uuid UUID;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS root_post_uuid UUID;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS repost_of_post_uuid UUID;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS quote_of_post_uuid UUID;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS quote_text TEXT;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS audience VARCHAR(30) NOT NULL DEFAULT 'public';
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS author_visibility_snapshot VARCHAR(20) NOT NULL DEFAULT 'public';
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS search_vector TEXT;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS reply_count BIGINT NOT NULL DEFAULT 0;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS repost_count BIGINT NOT NULL DEFAULT 0;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS quote_count BIGINT NOT NULL DEFAULT 0;
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS bookmark_count BIGINT NOT NULL DEFAULT 0;
    CREATE INDEX IF NOT EXISTS idx_posts_active_author_cursor ON posts (author_uuid, created_at DESC, id) WHERE deleted_at IS NULL;
    CREATE INDEX IF NOT EXISTS idx_posts_public_active_cursor ON posts (created_at DESC, id) WHERE deleted_at IS NULL AND visibility = 'public';
    CREATE INDEX IF NOT EXISTS idx_posts_reply_thread ON posts (root_post_uuid, created_at ASC, id);
    CREATE INDEX IF NOT EXISTS idx_posts_reply_to ON posts (reply_to_post_uuid, created_at ASC, id);
    CREATE UNIQUE INDEX IF NOT EXISTS idx_posts_repost_once ON posts (author_uuid, repost_of_post_uuid) WHERE deleted_at IS NULL AND repost_of_post_uuid IS NOT NULL;

    ALTER TABLE post_stats ADD COLUMN IF NOT EXISTS reply_count BIGINT NOT NULL DEFAULT 0;
    ALTER TABLE post_stats ADD COLUMN IF NOT EXISTS repost_count BIGINT NOT NULL DEFAULT 0;
    ALTER TABLE post_stats ADD COLUMN IF NOT EXISTS quote_count BIGINT NOT NULL DEFAULT 0;
    ALTER TABLE post_stats ADD COLUMN IF NOT EXISTS hide_count BIGINT NOT NULL DEFAULT 0;
    ALTER TABLE post_stats ADD COLUMN IF NOT EXISTS report_count BIGINT NOT NULL DEFAULT 0;
    ALTER TABLE post_stats ADD COLUMN IF NOT EXISTS unique_impressions_count BIGINT NOT NULL DEFAULT 0;
    ALTER TABLE post_stats ADD COLUMN IF NOT EXISTS total_dwell_ms BIGINT NOT NULL DEFAULT 0;

    CREATE TABLE IF NOT EXISTS post_edits (
      id UUID PRIMARY KEY,
      post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
      editor_id UUID REFERENCES users(id) ON DELETE SET NULL,
      previous_body TEXT NOT NULL,
      new_body TEXT NOT NULL,
      edited_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb
    );
    CREATE INDEX IF NOT EXISTS idx_post_edits_post_edited ON post_edits (post_id, edited_at DESC);

    CREATE TABLE IF NOT EXISTS post_reaction_events (
      id BIGSERIAL PRIMARY KEY,
      post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      reaction_type VARCHAR(24) NOT NULL,
      action VARCHAR(24) NOT NULL,
      occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      request_id UUID
    );
    CREATE INDEX IF NOT EXISTS idx_post_reaction_events_post_occurred ON post_reaction_events (post_id, occurred_at DESC);
    CREATE INDEX IF NOT EXISTS idx_post_reaction_events_user_occurred ON post_reaction_events (user_id, occurred_at DESC);

    ALTER TABLE comments ADD COLUMN IF NOT EXISTS status VARCHAR(24) NOT NULL DEFAULT 'active';
    ALTER TABLE comments ADD COLUMN IF NOT EXISTS moderation_state VARCHAR(24) NOT NULL DEFAULT 'clean';
    ALTER TABLE comments ADD COLUMN IF NOT EXISTS path TEXT;
  `);

  await pool.query(`
    ALTER TABLE hashtags ADD COLUMN IF NOT EXISTS description TEXT;
    ALTER TABLE hashtags ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN NOT NULL DEFAULT false;
    ALTER TABLE hashtags ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

    CREATE TABLE IF NOT EXISTS topic_aliases (
      id UUID PRIMARY KEY,
      topic_id UUID NOT NULL REFERENCES topic_catalog(id) ON DELETE CASCADE,
      alias VARCHAR(120) NOT NULL,
      alias_normalized VARCHAR(120) NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      UNIQUE (topic_id, alias_normalized)
    );

    CREATE TABLE IF NOT EXISTS hashtag_topic_edges (
      hashtag_id UUID NOT NULL REFERENCES hashtags(id) ON DELETE CASCADE,
      topic_id UUID NOT NULL REFERENCES topic_catalog(id) ON DELETE CASCADE,
      confidence_score REAL NOT NULL DEFAULT 1,
      source VARCHAR(32) NOT NULL DEFAULT 'system',
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (hashtag_id, topic_id)
    );

    CREATE TABLE IF NOT EXISTS mention_notifications (
      post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
      mentioned_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      notification_id UUID REFERENCES notifications(notification_uuid) ON DELETE SET NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      delivered_at TIMESTAMPTZ,
      PRIMARY KEY (post_id, mentioned_user_id)
    );
  `);

  await pool.query(`
    ALTER TABLE feed_requests ADD COLUMN IF NOT EXISTS request_uuid UUID;
    ALTER TABLE feed_requests ADD COLUMN IF NOT EXISTS algorithm_name VARCHAR(96);
    ALTER TABLE feed_requests ADD COLUMN IF NOT EXISTS algorithm_version VARCHAR(48);
    ALTER TABLE feed_requests ADD COLUMN IF NOT EXISTS limit_requested INTEGER;
    ALTER TABLE feed_requests ADD COLUMN IF NOT EXISTS result_count INTEGER;
    ALTER TABLE feed_requests ADD COLUMN IF NOT EXISTS latency_ms INTEGER;

    CREATE TABLE IF NOT EXISTS feed_request_items (
      request_id UUID NOT NULL REFERENCES feed_requests(id) ON DELETE CASCADE,
      post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
      rank_position INTEGER NOT NULL,
      score DOUBLE PRECISION NOT NULL,
      candidate_source VARCHAR(64) NOT NULL,
      reason_codes TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
      feature_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (request_id, post_id)
    );
    CREATE INDEX IF NOT EXISTS idx_feed_request_items_post ON feed_request_items (post_id, created_at DESC);

    ALTER TABLE feed_impressions ADD COLUMN IF NOT EXISTS occurred_at TIMESTAMPTZ;
    UPDATE feed_impressions SET occurred_at = COALESCE(created_at, last_seen_at, first_seen_at, now()) WHERE occurred_at IS NULL;
    ALTER TABLE feed_impressions ADD COLUMN IF NOT EXISTS algorithm_version_id UUID;
    ALTER TABLE feed_impressions ADD COLUMN IF NOT EXISTS candidate_source VARCHAR(64);
    CREATE INDEX IF NOT EXISTS idx_feed_impressions_uuid_occurred ON feed_impressions (user_uuid, occurred_at DESC);

    ALTER TABLE feed_events ADD COLUMN IF NOT EXISTS occurred_at TIMESTAMPTZ;
    UPDATE feed_events SET occurred_at = created_at WHERE occurred_at IS NULL;
    ALTER TABLE feed_events ADD COLUMN IF NOT EXISTS idempotency_key UUID;
    ALTER TABLE feed_events ADD COLUMN IF NOT EXISTS feature_context JSONB NOT NULL DEFAULT '{}'::jsonb;
    CREATE INDEX IF NOT EXISTS idx_feed_events_uuid_occurred ON feed_events (user_uuid, occurred_at DESC);

    CREATE TABLE IF NOT EXISTS user_negative_feedback (
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      entity_type VARCHAR(32) NOT NULL,
      entity_uuid UUID NOT NULL,
      feedback_type VARCHAR(48) NOT NULL,
      weight REAL NOT NULL DEFAULT 1,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      expires_at TIMESTAMPTZ,
      PRIMARY KEY (user_id, entity_type, entity_uuid, feedback_type)
    );

    CREATE TABLE IF NOT EXISTS feed_candidate_sources (
      id UUID PRIMARY KEY,
      source_key VARCHAR(64) NOT NULL UNIQUE,
      description TEXT,
      enabled BOOLEAN NOT NULL DEFAULT true,
      weight DOUBLE PRECISION NOT NULL DEFAULT 1,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  await pool.query(`
    ALTER TABLE post_engagement_windows ADD COLUMN IF NOT EXISTS unique_users_count BIGINT NOT NULL DEFAULT 0;
    ALTER TABLE post_engagement_windows ADD COLUMN IF NOT EXISTS velocity_score DOUBLE PRECISION NOT NULL DEFAULT 0;
    ALTER TABLE post_engagement_windows ADD COLUMN IF NOT EXISTS quality_adjusted_score DOUBLE PRECISION NOT NULL DEFAULT 0;

    CREATE TABLE IF NOT EXISTS topic_trend_windows (
      topic_id UUID NOT NULL REFERENCES topic_catalog(id) ON DELETE CASCADE,
      scope_type VARCHAR(24) NOT NULL DEFAULT 'global',
      scope_key VARCHAR(96) NOT NULL DEFAULT 'global',
      window_start TIMESTAMPTZ NOT NULL,
      window_size_minutes INTEGER NOT NULL,
      posts_count BIGINT NOT NULL DEFAULT 0,
      engagement_count BIGINT NOT NULL DEFAULT 0,
      velocity_score DOUBLE PRECISION NOT NULL DEFAULT 0,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (topic_id, scope_type, scope_key, window_start, window_size_minutes)
    );
    CREATE INDEX IF NOT EXISTS idx_topic_trend_windows_rank ON topic_trend_windows (scope_type, scope_key, window_size_minutes, velocity_score DESC);

    CREATE TABLE IF NOT EXISTS retention_policies (
      policy_key VARCHAR(100) PRIMARY KEY,
      table_name VARCHAR(100) NOT NULL,
      retention_days INTEGER NOT NULL,
      action VARCHAR(30) NOT NULL DEFAULT 'delete',
      enabled BOOLEAN NOT NULL DEFAULT true,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS retention_job_runs (
      id BIGSERIAL PRIMARY KEY,
      policy_key VARCHAR(100) NOT NULL REFERENCES retention_policies(policy_key),
      status VARCHAR(24) NOT NULL,
      started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      completed_at TIMESTAMPTZ,
      rows_affected BIGINT NOT NULL DEFAULT 0,
      error_message TEXT
    );
  `);

  await pool.query(`
    ALTER TABLE conversations ADD COLUMN IF NOT EXISTS status VARCHAR(24) NOT NULL DEFAULT 'active';
    ALTER TABLE conversations ADD COLUMN IF NOT EXISTS last_message_uuid UUID;
    ALTER TABLE conversations ADD COLUMN IF NOT EXISTS last_message_sequence_id BIGINT;
    ALTER TABLE conversations ADD COLUMN IF NOT EXISTS max_members INTEGER;
    CREATE INDEX IF NOT EXISTS idx_conversations_type_status_last ON conversations (conversation_type, status, last_message_at DESC);

    ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS invited_by_uuid UUID;
    ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS invited_at TIMESTAMPTZ;
    ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS last_delivered_sequence_id BIGINT NOT NULL DEFAULT 0;
    ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS notification_level VARCHAR(24) NOT NULL DEFAULT 'all';

    ALTER TABLE messages ADD COLUMN IF NOT EXISTS client_message_id UUID;
    ALTER TABLE messages ADD COLUMN IF NOT EXISTS delivery_state VARCHAR(24) NOT NULL DEFAULT 'sent';
    ALTER TABLE messages ADD COLUMN IF NOT EXISTS reply_to_message_uuid UUID;
    ALTER TABLE messages ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;
    CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_client_dedupe
      ON messages (conversation_uuid, sender_uuid, client_message_id)
      WHERE client_message_id IS NOT NULL;
    CREATE INDEX IF NOT EXISTS idx_messages_conversation_sequence ON messages (conversation_uuid, sequence_id DESC);

    CREATE TABLE IF NOT EXISTS message_delivery_events (
      id BIGSERIAL PRIMARY KEY,
      message_id UUID NOT NULL REFERENCES messages(message_uuid) ON DELETE CASCADE,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      delivery_state VARCHAR(24) NOT NULL,
      occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb
    );
    CREATE INDEX IF NOT EXISTS idx_message_delivery_events_message ON message_delivery_events (message_id, occurred_at DESC);

    CREATE TABLE IF NOT EXISTS group_role_permissions (
      conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
      role_key VARCHAR(32) NOT NULL,
      permission_key VARCHAR(64) NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (conversation_id, role_key, permission_key)
    );
  `);

  await pool.query(`
    ALTER TABLE notification_preferences ADD COLUMN IF NOT EXISTS digest_frequency VARCHAR(24) NOT NULL DEFAULT 'immediate';
    ALTER TABLE notification_preferences ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

    CREATE TABLE IF NOT EXISTS notification_delivery_attempts (
      id BIGSERIAL PRIMARY KEY,
      notification_id UUID NOT NULL REFERENCES notifications(notification_uuid) ON DELETE CASCADE,
      channel VARCHAR(24) NOT NULL,
      provider VARCHAR(48),
      status VARCHAR(24) NOT NULL,
      provider_message_id TEXT,
      error_message TEXT,
      attempted_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_notification_delivery_attempts_notification ON notification_delivery_attempts (notification_id, attempted_at DESC);

    CREATE TABLE IF NOT EXISTS notification_batches (
      id UUID PRIMARY KEY,
      recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      batch_type VARCHAR(48) NOT NULL,
      status VARCHAR(24) NOT NULL DEFAULT 'pending',
      payload JSONB NOT NULL DEFAULT '{}'::jsonb,
      scheduled_for TIMESTAMPTZ NOT NULL,
      sent_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_notification_batches_due ON notification_batches (status, scheduled_for);
  `);

  await pool.query(`
    ALTER TABLE reports ADD COLUMN IF NOT EXISTS severity VARCHAR(24) NOT NULL DEFAULT 'medium';
    ALTER TABLE reports ADD COLUMN IF NOT EXISTS duplicate_of_report_id UUID;
    ALTER TABLE reports ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

    ALTER TABLE moderation_cases ADD COLUMN IF NOT EXISTS queue_key VARCHAR(64) NOT NULL DEFAULT 'default';
    ALTER TABLE moderation_cases ADD COLUMN IF NOT EXISTS decision VARCHAR(64);
    ALTER TABLE moderation_cases ADD COLUMN IF NOT EXISTS due_at TIMESTAMPTZ;

    CREATE TABLE IF NOT EXISTS moderation_queues (
      queue_key VARCHAR(64) PRIMARY KEY,
      display_name VARCHAR(120) NOT NULL,
      description TEXT,
      is_active BOOLEAN NOT NULL DEFAULT true,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS moderation_policy_versions (
      id UUID PRIMARY KEY,
      policy_key VARCHAR(80) NOT NULL,
      version VARCHAR(40) NOT NULL,
      rules JSONB NOT NULL DEFAULT '{}'::jsonb,
      is_active BOOLEAN NOT NULL DEFAULT false,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      UNIQUE (policy_key, version)
    );
  `);

  await pool.query(`
    ALTER TABLE media_objects ADD COLUMN IF NOT EXISTS variants JSONB NOT NULL DEFAULT '[]'::jsonb;
    ALTER TABLE media_objects ADD COLUMN IF NOT EXISTS blurhash TEXT;
    ALTER TABLE media_objects ADD COLUMN IF NOT EXISTS alt_text TEXT;
    ALTER TABLE media_objects ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

    ALTER TABLE upload_sessions ADD COLUMN IF NOT EXISTS upload_url TEXT;
    ALTER TABLE upload_sessions ADD COLUMN IF NOT EXISTS parts JSONB NOT NULL DEFAULT '[]'::jsonb;
    ALTER TABLE upload_sessions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
  `);

  await pool.query(`
    ALTER TABLE outbox_events ADD COLUMN IF NOT EXISTS aggregate_id UUID;
    ALTER TABLE outbox_events ADD COLUMN IF NOT EXISTS attempt_count INTEGER NOT NULL DEFAULT 0;
    UPDATE outbox_events SET attempt_count = attempts WHERE attempt_count = 0 AND attempts > 0;
    CREATE INDEX IF NOT EXISTS idx_outbox_events_aggregate ON outbox_events (aggregate_type, aggregate_uuid);
    CREATE INDEX IF NOT EXISTS idx_outbox_events_aggregate_id ON outbox_events (aggregate_type, aggregate_id);

    ALTER TABLE processed_events ADD COLUMN IF NOT EXISTS source_event_type VARCHAR(96);

    ALTER TABLE dead_letter_events ADD COLUMN IF NOT EXISTS original_event_id UUID;
    ALTER TABLE dead_letter_events ADD COLUMN IF NOT EXISTS consumer_name VARCHAR(100);
    ALTER TABLE dead_letter_events ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ;

    ALTER TABLE idempotency_keys ADD COLUMN IF NOT EXISTS idempotency_key UUID;
    ALTER TABLE idempotency_keys ADD COLUMN IF NOT EXISTS route_key VARCHAR(150);
    ALTER TABLE idempotency_keys ADD COLUMN IF NOT EXISTS response_snapshot JSONB;
    CREATE INDEX IF NOT EXISTS idx_idempotency_keys_user_expires ON idempotency_keys (user_id, expires_at);

    ALTER TABLE background_job_runs ADD COLUMN IF NOT EXISTS run_key VARCHAR(150);
    ALTER TABLE background_job_runs ADD COLUMN IF NOT EXISTS processed_count INTEGER;
    ALTER TABLE background_job_runs ADD COLUMN IF NOT EXISTS failure_count INTEGER;
    ALTER TABLE background_job_runs ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

    ALTER TABLE background_job_locks ADD COLUMN IF NOT EXISTS job_name VARCHAR(100);
    ALTER TABLE background_job_locks ADD COLUMN IF NOT EXISTS lock_owner VARCHAR(150);
    ALTER TABLE background_job_locks ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
  `);

  await pool.query(`
    ALTER TABLE feature_flags ADD COLUMN IF NOT EXISTS id UUID;
    ALTER TABLE feature_flags ADD COLUMN IF NOT EXISTS flag_key VARCHAR(100);
    UPDATE feature_flags SET flag_key = key WHERE flag_key IS NULL;
    ALTER TABLE feature_flags ADD COLUMN IF NOT EXISTS enabled_by_default BOOLEAN NOT NULL DEFAULT false;
    ALTER TABLE feature_flags ADD COLUMN IF NOT EXISTS config_json JSONB NOT NULL DEFAULT '{}'::jsonb;
    CREATE UNIQUE INDEX IF NOT EXISTS idx_feature_flags_flag_key_unique ON feature_flags (flag_key);

    CREATE TABLE IF NOT EXISTS feature_flag_overrides (
      flag_id UUID,
      flag_key VARCHAR(100) NOT NULL,
      subject_type VARCHAR(30) NOT NULL,
      subject_key VARCHAR(100) NOT NULL,
      enabled BOOLEAN NOT NULL,
      config_json JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (flag_key, subject_type, subject_key)
    );

    ALTER TABLE app_config_versions ADD COLUMN IF NOT EXISTS config_json JSONB;
    UPDATE app_config_versions SET config_json = config WHERE config_json IS NULL;
    ALTER TABLE app_config_versions ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'draft';

    ALTER TABLE admin_audit_logs ADD COLUMN IF NOT EXISTS actor_user_id UUID;
    ALTER TABLE admin_audit_logs ADD COLUMN IF NOT EXISTS actor_role_key VARCHAR(50);
    ALTER TABLE admin_audit_logs ADD COLUMN IF NOT EXISTS entity_type VARCHAR(50);
    ALTER TABLE admin_audit_logs ADD COLUMN IF NOT EXISTS entity_id UUID;
    CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_action_occurred ON admin_audit_logs (action, occurred_at DESC);

    CREATE TABLE IF NOT EXISTS daily_system_metrics (
      metric_date DATE NOT NULL,
      metric_key VARCHAR(100) NOT NULL,
      metric_value NUMERIC NOT NULL,
      dimensions JSONB NOT NULL DEFAULT '{}'::jsonb,
      PRIMARY KEY (metric_date, metric_key)
    );
  `);

  await seedDomainData(pool);
}

async function isDomainExpansionApplied(pool: pg.Pool): Promise<boolean> {
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
    "SELECT 1 FROM schema_migrations WHERE version = '0002_database_domain_expansion' LIMIT 1"
  );
  if (migration.rows.length === 0) {
    return false;
  }

  const requiredTables = await pool.query<{ table_name: string }>(
    `SELECT table_name
     FROM information_schema.tables
     WHERE table_schema = 'public'
       AND table_name IN (
         'feed_candidate_sources',
         'retention_policies',
         'message_delivery_events',
         'notification_delivery_attempts',
         'moderation_queues',
         'feature_flag_overrides',
         'daily_system_metrics'
       )`
  );
  const found = new Set(requiredTables.rows.map((row) => row.table_name));
  return [
    "feed_candidate_sources",
    "retention_policies",
    "message_delivery_events",
    "notification_delivery_attempts",
    "moderation_queues",
    "feature_flag_overrides",
    "daily_system_metrics",
  ].every((tableName) => found.has(tableName));
}

async function refreshDomainReferences(pool: pg.Pool): Promise<void> {
  await pool.query(`
    ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS display_name VARCHAR(100);
    ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS banner_media_id UUID;
    ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS birth_date DATE;
    ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS search_vector TEXT;

    ALTER TABLE user_stats ADD COLUMN IF NOT EXISTS replies_count BIGINT NOT NULL DEFAULT 0;
    ALTER TABLE user_stats ADD COLUMN IF NOT EXISTS likes_received BIGINT NOT NULL DEFAULT 0;

    ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS user_uuid UUID;
    ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS language_code VARCHAR(10) NOT NULL DEFAULT 'en';
    ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS timezone_name VARCHAR(100);
    ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS theme VARCHAR(20);
    ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS show_online_status BOOLEAN NOT NULL DEFAULT true;
    ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS show_read_receipts BOOLEAN NOT NULL DEFAULT true;
    ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS autoplay_enabled BOOLEAN NOT NULL DEFAULT true;
    ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS content_language_preferences JSONB NOT NULL DEFAULT '[]'::jsonb;
    ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

    ALTER TABLE user_privacy_settings ADD COLUMN IF NOT EXISTS dm_policy VARCHAR(30) NOT NULL DEFAULT 'friends';
    ALTER TABLE user_privacy_settings ADD COLUMN IF NOT EXISTS group_invite_policy VARCHAR(30) NOT NULL DEFAULT 'friends';
    ALTER TABLE user_privacy_settings ADD COLUMN IF NOT EXISTS followers_visibility VARCHAR(30) NOT NULL DEFAULT 'public';
    ALTER TABLE user_privacy_settings ADD COLUMN IF NOT EXISTS following_visibility VARCHAR(30) NOT NULL DEFAULT 'public';
    ALTER TABLE user_privacy_settings ADD COLUMN IF NOT EXISTS friends_visibility VARCHAR(30) NOT NULL DEFAULT 'friends';
    ALTER TABLE user_privacy_settings ADD COLUMN IF NOT EXISTS birth_date_visibility VARCHAR(30) NOT NULL DEFAULT 'only_me';
    ALTER TABLE user_privacy_settings ADD COLUMN IF NOT EXISTS location_visibility VARCHAR(30) NOT NULL DEFAULT 'public';
    ALTER TABLE user_privacy_settings ADD COLUMN IF NOT EXISTS allow_profile_discovery BOOLEAN NOT NULL DEFAULT true;
    ALTER TABLE user_privacy_settings ADD COLUMN IF NOT EXISTS allow_search_indexing BOOLEAN NOT NULL DEFAULT true;

    ALTER TABLE user_emails ADD COLUMN IF NOT EXISTS email_normalized VARCHAR(320);
    ALTER TABLE user_emails ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

    ALTER TABLE user_credentials ADD COLUMN IF NOT EXISTS password_algorithm VARCHAR(30) NOT NULL DEFAULT 'argon2id';
    ALTER TABLE user_credentials ADD COLUMN IF NOT EXISTS password_changed_at TIMESTAMPTZ NOT NULL DEFAULT now();
    ALTER TABLE user_credentials ADD COLUMN IF NOT EXISTS failed_login_count INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE user_credentials ADD COLUMN IF NOT EXISTS locked_until TIMESTAMPTZ;
    ALTER TABLE user_credentials ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
    ALTER TABLE user_credentials ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

    ALTER TABLE feature_flags ADD COLUMN IF NOT EXISTS flag_key VARCHAR(120);
    ALTER TABLE roles ADD COLUMN IF NOT EXISTS role_key VARCHAR(50);
    ALTER TABLE permissions ADD COLUMN IF NOT EXISTS permission_key VARCHAR(100);

    CREATE INDEX IF NOT EXISTS idx_user_profiles_display_name ON user_profiles (display_name);
    CREATE INDEX IF NOT EXISTS idx_user_emails_user_created ON user_emails (user_id, created_at DESC);

    UPDATE user_settings SET user_uuid = users.id FROM users WHERE user_settings.user_id = users.user_id AND user_settings.user_uuid IS NULL;
    UPDATE user_emails SET email_normalized = lower(email::text) WHERE email_normalized IS NULL;
    UPDATE feature_flags SET flag_key = key WHERE flag_key IS NULL;
    UPDATE roles SET role_key = name WHERE role_key IS NULL;
    UPDATE permissions SET permission_key = name WHERE permission_key IS NULL;
  `);
}

async function seedDomainData(pool: pg.Pool): Promise<void> {
  await pool.query(`
    INSERT INTO feed_candidate_sources (id, source_key, description, enabled, weight)
    VALUES
      ('00000000-0000-0000-0000-000000000601', 'following_recent', 'Recent posts from followed users', true, 1.25),
      ('00000000-0000-0000-0000-000000000602', 'topic_affinity', 'Posts matching user topic affinity', true, 1.00),
      ('00000000-0000-0000-0000-000000000603', 'author_affinity', 'Posts from authors with strong affinity', true, 1.10),
      ('00000000-0000-0000-0000-000000000604', 'trending_quality', 'Quality-adjusted trending posts', true, 0.85),
      ('00000000-0000-0000-0000-000000000605', 'exploration', 'Bounded exploration candidates', true, 0.35)
    ON CONFLICT (source_key) DO UPDATE SET
      description = EXCLUDED.description,
      enabled = EXCLUDED.enabled,
      weight = EXCLUDED.weight,
      updated_at = now();

    INSERT INTO moderation_queues (queue_key, display_name, description, is_active)
    VALUES
      ('default', 'Default review', 'General moderation review queue', true),
      ('reported_posts', 'Reported posts', 'User-reported post queue', true),
      ('reported_accounts', 'Reported accounts', 'User-reported account queue', true),
      ('spam', 'Spam review', 'Automated spam and abuse queue', true),
      ('appeals', 'Appeals', 'User appeal review queue', true)
    ON CONFLICT (queue_key) DO UPDATE SET
      display_name = EXCLUDED.display_name,
      description = EXCLUDED.description,
      is_active = EXCLUDED.is_active;

    INSERT INTO moderation_policy_versions (id, policy_key, version, rules, is_active)
    VALUES
      ('00000000-0000-0000-0000-000000000701', 'post_safety', '1.0.0', '{"spam_threshold":0.9,"hide_threshold":0.98}'::jsonb, true),
      ('00000000-0000-0000-0000-000000000702', 'account_abuse', '1.0.0', '{"report_threshold":5,"cooldown_hours":24}'::jsonb, true),
      ('00000000-0000-0000-0000-000000000703', 'dm_safety', '1.0.0', '{"block_report_boost":2}'::jsonb, true)
    ON CONFLICT (policy_key, version) DO UPDATE SET
      rules = EXCLUDED.rules,
      is_active = EXCLUDED.is_active;

    INSERT INTO retention_policies (policy_key, table_name, retention_days, action, enabled)
    VALUES
      ('feed_events_raw', 'feed_events', 180, 'delete', true),
      ('feed_impressions_raw', 'feed_impressions', 180, 'delete', true),
      ('login_attempts', 'auth_login_attempts', 180, 'delete', true),
      ('processed_outbox_events', 'processed_events', 180, 'delete', true),
      ('dead_letter_events', 'dead_letter_events', 365, 'review_then_delete', true),
      ('admin_audit_logs', 'admin_audit_logs', 2555, 'archive', true)
    ON CONFLICT (policy_key) DO UPDATE SET
      table_name = EXCLUDED.table_name,
      retention_days = EXCLUDED.retention_days,
      action = EXCLUDED.action,
      enabled = EXCLUDED.enabled,
      updated_at = now();

    INSERT INTO feature_flags (key, flag_key, description, enabled, enabled_by_default, rollout_percent, rules, config_json)
    VALUES
      ('feed.for_you.v1', 'feed.for_you.v1', 'Enable For You feed', true, true, 100, '{}'::jsonb, '{}'::jsonb),
      ('post.repost_quote.v1', 'post.repost_quote.v1', 'Enable repost and quote post support', true, true, 100, '{}'::jsonb, '{}'::jsonb),
      ('chat.group_roles.v1', 'chat.group_roles.v1', 'Enable group role permissions', true, true, 100, '{}'::jsonb, '{}'::jsonb),
      ('notifications.digest.v1', 'notifications.digest.v1', 'Enable notification digest batching', true, false, 25, '{}'::jsonb, '{}'::jsonb),
      ('moderation.policy.v1', 'moderation.policy.v1', 'Enable moderation policy versions', true, true, 100, '{}'::jsonb, '{}'::jsonb)
    ON CONFLICT (key) DO UPDATE SET
      flag_key = EXCLUDED.flag_key,
      description = EXCLUDED.description,
      enabled = EXCLUDED.enabled,
      enabled_by_default = EXCLUDED.enabled_by_default,
      rollout_percent = EXCLUDED.rollout_percent,
      rules = EXCLUDED.rules,
      config_json = EXCLUDED.config_json,
      updated_at = now();

    INSERT INTO app_config_versions (id, config_key, version, config, config_json, is_active, status, activated_at)
    VALUES
      ('00000000-0000-0000-0000-000000000801', 'feed.weights', 1, '{"recency":0.35,"affinity":0.3,"engagement":0.2,"quality":0.1,"exploration":0.05}'::jsonb, '{"recency":0.35,"affinity":0.3,"engagement":0.2,"quality":0.1,"exploration":0.05}'::jsonb, true, 'active', now()),
      ('00000000-0000-0000-0000-000000000802', 'rate_limits.default', 1, '{"post_create_per_hour":60,"message_send_per_minute":60,"login_attempts_per_hour":20}'::jsonb, '{"post_create_per_hour":60,"message_send_per_minute":60,"login_attempts_per_hour":20}'::jsonb, true, 'active', now()),
      ('00000000-0000-0000-0000-000000000803', 'retention.default', 1, '{"feed_events_days":180,"audit_days":2555,"processed_events_days":180}'::jsonb, '{"feed_events_days":180,"audit_days":2555,"processed_events_days":180}'::jsonb, true, 'active', now())
    ON CONFLICT (config_key, version) DO UPDATE SET
      config = EXCLUDED.config,
      config_json = EXCLUDED.config_json,
      is_active = EXCLUDED.is_active,
      status = EXCLUDED.status,
      activated_at = COALESCE(app_config_versions.activated_at, EXCLUDED.activated_at);
  `);
}
