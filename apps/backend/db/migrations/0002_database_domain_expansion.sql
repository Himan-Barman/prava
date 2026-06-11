-- Prava domain-complete expansion.
-- Apply after 0001_database_foundation.sql.
-- This is additive and preserves existing production data.

BEGIN;

INSERT INTO schema_migrations (version, checksum, description)
VALUES ('0002_database_domain_expansion', 'manual-sql-v1', 'Prava domain-complete database expansion')
ON CONFLICT (version) DO UPDATE SET
  applied_at = EXCLUDED.applied_at,
  checksum = EXCLUDED.checksum,
  description = EXCLUDED.description;

-- Core identity expansion
ALTER TABLE users ADD COLUMN IF NOT EXISTS account_visibility VARCHAR(20) NOT NULL DEFAULT 'public';
ALTER TABLE users ADD COLUMN IF NOT EXISTS primary_email_id UUID;
ALTER TABLE users ADD COLUMN IF NOT EXISTS primary_phone_id UUID;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS onboarding_completed_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS idx_users_active_visible ON users (created_at DESC) WHERE deleted_at IS NULL AND account_status = 'active';

ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS display_name VARCHAR(100) NOT NULL DEFAULT '';
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS banner_media_id UUID;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS birth_date DATE;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_user_profiles_search_vector ON user_profiles USING GIN (search_vector);
CREATE INDEX IF NOT EXISTS idx_user_profiles_display_name_lower ON user_profiles (lower(display_name));

ALTER TABLE user_stats ADD COLUMN IF NOT EXISTS replies_count BIGINT NOT NULL DEFAULT 0 CHECK (replies_count >= 0);
ALTER TABLE user_stats ADD COLUMN IF NOT EXISTS likes_received BIGINT NOT NULL DEFAULT 0 CHECK (likes_received >= 0);

ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS user_uuid UUID REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS language_code VARCHAR(10) NOT NULL DEFAULT 'en';
ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS timezone_name VARCHAR(100);
ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS theme VARCHAR(20);
ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS show_online_status BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS show_read_receipts BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS autoplay_enabled BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS content_language_preferences JSONB NOT NULL DEFAULT '[]'::jsonb;
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
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_emails_normalized_active ON user_emails (email_normalized) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS user_phones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status VARCHAR(30) NOT NULL DEFAULT 'requested',
  storage_object_key TEXT,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ
);

-- Authentication and security expansion
ALTER TABLE user_credentials ADD COLUMN IF NOT EXISTS password_algorithm VARCHAR(30) NOT NULL DEFAULT 'argon2id';
ALTER TABLE user_credentials ADD COLUMN IF NOT EXISTS password_changed_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE user_credentials ADD COLUMN IF NOT EXISTS failed_login_count INTEGER NOT NULL DEFAULT 0 CHECK (failed_login_count >= 0);
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

ALTER TABLE auth_refresh_tokens ADD COLUMN IF NOT EXISTS parent_token_id UUID REFERENCES auth_refresh_tokens(id);
ALTER TABLE auth_refresh_tokens ADD COLUMN IF NOT EXISTS replaced_by_token_id UUID REFERENCES auth_refresh_tokens(id);
ALTER TABLE auth_refresh_tokens ADD COLUMN IF NOT EXISTS issued_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE auth_refresh_tokens ADD COLUMN IF NOT EXISTS consumed_at TIMESTAMPTZ;

ALTER TABLE auth_challenges ADD COLUMN IF NOT EXISTS destination TEXT;
ALTER TABLE auth_challenges ADD COLUMN IF NOT EXISTS challenge_hash TEXT;
ALTER TABLE auth_challenges ADD COLUMN IF NOT EXISTS attempt_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE auth_challenges ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE auth_login_attempts ADD COLUMN IF NOT EXISTS identifier_hash TEXT;
ALTER TABLE auth_login_attempts ADD COLUMN IF NOT EXISTS occurred_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE security_events ADD COLUMN IF NOT EXISTS severity VARCHAR(20) NOT NULL DEFAULT 'info';
ALTER TABLE security_events ADD COLUMN IF NOT EXISTS device_id UUID REFERENCES user_devices(id) ON DELETE SET NULL;
ALTER TABLE security_events ADD COLUMN IF NOT EXISTS occurred_at TIMESTAMPTZ NOT NULL DEFAULT now();

ALTER TABLE roles ADD COLUMN IF NOT EXISTS role_key VARCHAR(50);
UPDATE roles SET role_key = name WHERE role_key IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_roles_role_key_unique ON roles (role_key);
ALTER TABLE permissions ADD COLUMN IF NOT EXISTS permission_key VARCHAR(100);
UPDATE permissions SET permission_key = name WHERE permission_key IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_permissions_key_unique ON permissions (permission_key);
ALTER TABLE user_roles ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMPTZ;

-- Social graph expansion
ALTER TABLE follows ADD COLUMN IF NOT EXISTS follow_id UUID DEFAULT gen_random_uuid();
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

CREATE TABLE IF NOT EXISTS user_muted_topics (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  topic_id UUID NOT NULL REFERENCES topic_catalog(id) ON DELETE CASCADE,
  reason VARCHAR(64),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ,
  PRIMARY KEY (user_id, topic_id)
);

-- Posts, replies, reposts, quotes and comments
ALTER TABLE posts ADD COLUMN IF NOT EXISTS post_type VARCHAR(30) NOT NULL DEFAULT 'post';
ALTER TABLE posts ADD COLUMN IF NOT EXISTS reply_to_post_uuid UUID REFERENCES posts(id) ON DELETE SET NULL;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS root_post_uuid UUID REFERENCES posts(id) ON DELETE SET NULL;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS repost_of_post_uuid UUID REFERENCES posts(id) ON DELETE SET NULL;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS quote_of_post_uuid UUID REFERENCES posts(id) ON DELETE SET NULL;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS quote_text TEXT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS audience VARCHAR(30) NOT NULL DEFAULT 'public';
ALTER TABLE posts ADD COLUMN IF NOT EXISTS author_visibility_snapshot VARCHAR(20) NOT NULL DEFAULT 'public';
ALTER TABLE posts ADD COLUMN IF NOT EXISTS search_vector TSVECTOR;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS reply_count BIGINT NOT NULL DEFAULT 0;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS repost_count BIGINT NOT NULL DEFAULT 0;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS quote_count BIGINT NOT NULL DEFAULT 0;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS bookmark_count BIGINT NOT NULL DEFAULT 0;
CREATE INDEX IF NOT EXISTS idx_posts_search_vector ON posts USING GIN (search_vector);
CREATE INDEX IF NOT EXISTS idx_posts_active_author_cursor ON posts (author_uuid, created_at DESC, id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_posts_public_active_cursor ON posts (created_at DESC, id) WHERE deleted_at IS NULL AND visibility = 'public';
CREATE INDEX IF NOT EXISTS idx_posts_reply_thread ON posts (root_post_uuid, created_at ASC, id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_posts_repost_once ON posts (author_uuid, repost_of_post_uuid) WHERE deleted_at IS NULL AND repost_of_post_uuid IS NOT NULL;

CREATE TABLE IF NOT EXISTS post_edits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  editor_id UUID REFERENCES users(id) ON DELETE SET NULL,
  previous_body TEXT NOT NULL,
  new_body TEXT NOT NULL,
  edited_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS post_reaction_events (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reaction_type VARCHAR(24) NOT NULL,
  action VARCHAR(24) NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  request_id UUID
);

ALTER TABLE comments ADD COLUMN IF NOT EXISTS status VARCHAR(24) NOT NULL DEFAULT 'active';
ALTER TABLE comments ADD COLUMN IF NOT EXISTS moderation_state VARCHAR(24) NOT NULL DEFAULT 'clean';
ALTER TABLE comments ADD COLUMN IF NOT EXISTS path TEXT;

-- Hashtags, mentions and topics
ALTER TABLE hashtags ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE hashtags ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE hashtags ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE TABLE IF NOT EXISTS topic_aliases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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

-- Feed, ranking and trends
ALTER TABLE feed_requests ADD COLUMN IF NOT EXISTS request_uuid UUID DEFAULT gen_random_uuid();
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

ALTER TABLE feed_impressions ADD COLUMN IF NOT EXISTS occurred_at TIMESTAMPTZ;
ALTER TABLE feed_impressions ADD COLUMN IF NOT EXISTS algorithm_version_id UUID REFERENCES feed_algorithm_versions(id) ON DELETE SET NULL;
ALTER TABLE feed_impressions ADD COLUMN IF NOT EXISTS candidate_source VARCHAR(64);
CREATE INDEX IF NOT EXISTS idx_feed_impressions_uuid_occurred ON feed_impressions (user_uuid, occurred_at DESC);

ALTER TABLE feed_events ADD COLUMN IF NOT EXISTS occurred_at TIMESTAMPTZ;
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
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_key VARCHAR(64) NOT NULL UNIQUE,
  description TEXT,
  enabled BOOLEAN NOT NULL DEFAULT true,
  weight DOUBLE PRECISION NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

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

-- Chat and message consistency
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS status VARCHAR(24) NOT NULL DEFAULT 'active';
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS last_message_uuid UUID;
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS last_message_sequence_id BIGINT;
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS max_members INTEGER;

ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS invited_by_uuid UUID;
ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS invited_at TIMESTAMPTZ;
ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS last_delivered_sequence_id BIGINT NOT NULL DEFAULT 0;
ALTER TABLE conversation_members ADD COLUMN IF NOT EXISTS notification_level VARCHAR(24) NOT NULL DEFAULT 'all';

ALTER TABLE messages ADD COLUMN IF NOT EXISTS client_message_id UUID;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS delivery_state VARCHAR(24) NOT NULL DEFAULT 'sent';
ALTER TABLE messages ADD COLUMN IF NOT EXISTS reply_to_message_uuid UUID;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;
CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_client_dedupe ON messages (conversation_uuid, sender_uuid, client_message_id) WHERE client_message_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_messages_conversation_sequence ON messages (conversation_uuid, sequence_id DESC);

CREATE TABLE IF NOT EXISTS message_delivery_events (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  message_id UUID NOT NULL REFERENCES messages(message_uuid) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  delivery_state VARCHAR(24) NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS group_role_permissions (
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  role_key VARCHAR(32) NOT NULL,
  permission_key VARCHAR(64) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (conversation_id, role_key, permission_key)
);

-- Notifications
ALTER TABLE notification_preferences ADD COLUMN IF NOT EXISTS digest_frequency VARCHAR(24) NOT NULL DEFAULT 'immediate';
ALTER TABLE notification_preferences ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE TABLE IF NOT EXISTS notification_delivery_attempts (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  notification_id UUID NOT NULL REFERENCES notifications(notification_uuid) ON DELETE CASCADE,
  channel VARCHAR(24) NOT NULL,
  provider VARCHAR(48),
  status VARCHAR(24) NOT NULL,
  provider_message_id TEXT,
  error_message TEXT,
  attempted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notification_batches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  batch_type VARCHAR(48) NOT NULL,
  status VARCHAR(24) NOT NULL DEFAULT 'pending',
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  scheduled_for TIMESTAMPTZ NOT NULL,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Moderation, media, reliability, config and retention
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
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_key VARCHAR(80) NOT NULL,
  version VARCHAR(40) NOT NULL,
  rules JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_active BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (policy_key, version)
);

ALTER TABLE media_objects ADD COLUMN IF NOT EXISTS variants JSONB NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE media_objects ADD COLUMN IF NOT EXISTS blurhash TEXT;
ALTER TABLE media_objects ADD COLUMN IF NOT EXISTS alt_text TEXT;
ALTER TABLE media_objects ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE upload_sessions ADD COLUMN IF NOT EXISTS upload_url TEXT;
ALTER TABLE upload_sessions ADD COLUMN IF NOT EXISTS parts JSONB NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE upload_sessions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

ALTER TABLE outbox_events ADD COLUMN IF NOT EXISTS aggregate_id UUID;
ALTER TABLE outbox_events ADD COLUMN IF NOT EXISTS attempt_count INTEGER NOT NULL DEFAULT 0;
CREATE INDEX IF NOT EXISTS idx_outbox_events_aggregate_id ON outbox_events (aggregate_type, aggregate_id);
ALTER TABLE processed_events ADD COLUMN IF NOT EXISTS source_event_type VARCHAR(96);
ALTER TABLE dead_letter_events ADD COLUMN IF NOT EXISTS original_event_id UUID;
ALTER TABLE dead_letter_events ADD COLUMN IF NOT EXISTS consumer_name VARCHAR(100);
ALTER TABLE dead_letter_events ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ;
ALTER TABLE idempotency_keys ADD COLUMN IF NOT EXISTS idempotency_key UUID;
ALTER TABLE idempotency_keys ADD COLUMN IF NOT EXISTS route_key VARCHAR(150);
ALTER TABLE idempotency_keys ADD COLUMN IF NOT EXISTS response_snapshot JSONB;

ALTER TABLE feature_flags ADD COLUMN IF NOT EXISTS id UUID DEFAULT gen_random_uuid();
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

CREATE TABLE IF NOT EXISTS retention_policies (
  policy_key VARCHAR(100) PRIMARY KEY,
  table_name VARCHAR(100) NOT NULL,
  retention_days INTEGER NOT NULL,
  action VARCHAR(30) NOT NULL DEFAULT 'delete',
  enabled BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS retention_job_runs (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  policy_key VARCHAR(100) NOT NULL REFERENCES retention_policies(policy_key),
  status VARCHAR(24) NOT NULL,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  rows_affected BIGINT NOT NULL DEFAULT 0,
  error_message TEXT
);

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

COMMIT;
