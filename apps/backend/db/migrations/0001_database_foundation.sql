-- Prava database foundation migration.
-- Apply after the legacy schema in apps/backend/src/lib/pg.ts exists.
-- This migration is intentionally additive: existing TEXT ids remain valid while
-- UUID-compatible ids and normalized production tables are introduced.

BEGIN;

CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

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
VALUES ('0001_database_foundation', 'manual-sql-v1', 'Prava production database foundation')
ON CONFLICT (version) DO UPDATE SET
  applied_at = EXCLUDED.applied_at,
  checksum = EXCLUDED.checksum,
  description = EXCLUDED.description;

INSERT INTO database_foundation_metadata (key, value)
VALUES
  ('id_strategy', 'uuid-compatible additive columns; legacy text ids retained'),
  ('rollout_mode', 'non-destructive online migration'),
  ('runtime_migration', 'apps/backend/src/lib/database-foundation.ts')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now();

ALTER TABLE users ADD COLUMN IF NOT EXISTS id UUID DEFAULT gen_random_uuid();
ALTER TABLE users ADD COLUMN IF NOT EXISTS handle VARCHAR(30);
ALTER TABLE users ADD COLUMN IF NOT EXISTS handle_normalized VARCHAR(30);
ALTER TABLE users ADD COLUMN IF NOT EXISTS account_status VARCHAR(24) NOT NULL DEFAULT 'active';
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_private BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(32) NOT NULL DEFAULT 'user';
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_uuid_unique ON users (id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_handle_normalized_unique ON users (handle_normalized) WHERE deleted_at IS NULL;

ALTER TABLE posts ADD COLUMN IF NOT EXISTS id UUID DEFAULT gen_random_uuid();
ALTER TABLE posts ADD COLUMN IF NOT EXISTS author_uuid UUID;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS visibility VARCHAR(24) NOT NULL DEFAULT 'public';
ALTER TABLE posts ADD COLUMN IF NOT EXISTS status VARCHAR(24) NOT NULL DEFAULT 'published';
ALTER TABLE posts ADD COLUMN IF NOT EXISTS language_code VARCHAR(12);
ALTER TABLE posts ADD COLUMN IF NOT EXISTS last_engagement_at TIMESTAMPTZ;
CREATE UNIQUE INDEX IF NOT EXISTS idx_posts_uuid_unique ON posts (id);
CREATE INDEX IF NOT EXISTS idx_posts_author_uuid_created ON posts (author_uuid, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_visibility_status_created ON posts (visibility, status, created_at DESC);

ALTER TABLE conversations ADD COLUMN IF NOT EXISTS id UUID DEFAULT gen_random_uuid();
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS created_by_uuid UUID;
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS conversation_type VARCHAR(24) NOT NULL DEFAULT 'direct';
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ;
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS member_count INTEGER NOT NULL DEFAULT 0;
CREATE UNIQUE INDEX IF NOT EXISTS idx_conversations_uuid_unique ON conversations (id);

ALTER TABLE messages ADD COLUMN IF NOT EXISTS message_uuid UUID DEFAULT gen_random_uuid();
ALTER TABLE messages ADD COLUMN IF NOT EXISTS conversation_uuid UUID;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS sender_uuid UUID;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS client_message_uuid UUID;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS message_type VARCHAR(24) NOT NULL DEFAULT 'text';
ALTER TABLE messages ADD COLUMN IF NOT EXISTS body_text TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_uuid_unique ON messages (message_uuid);

ALTER TABLE notifications ADD COLUMN IF NOT EXISTS notification_uuid UUID DEFAULT gen_random_uuid();
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS recipient_uuid UUID;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS actor_uuid UUID;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS notification_type VARCHAR(48);
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS entity_type VARCHAR(48);
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS entity_uuid UUID;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS clicked_at TIMESTAMPTZ;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_uuid_unique ON notifications (notification_uuid);

CREATE TABLE IF NOT EXISTS user_profiles (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  bio TEXT,
  avatar_media_id UUID,
  cover_media_id UUID,
  location_text VARCHAR(120),
  website_url TEXT,
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
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  email CITEXT NOT NULL,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  is_verified BOOLEAN NOT NULL DEFAULT false,
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_emails_email_active ON user_emails (email) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_emails_primary ON user_emails (user_id) WHERE is_primary = true AND deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS user_credentials (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  password_hash TEXT NOT NULL,
  password_algo VARCHAR(32) NOT NULL DEFAULT 'bcrypt',
  password_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  must_rotate_password BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS user_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES auth_sessions(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,
  rotated_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_auth_refresh_tokens_hash ON auth_refresh_tokens (token_hash);

CREATE TABLE IF NOT EXISTS auth_challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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

CREATE TABLE IF NOT EXISTS blocks (
  blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason VARCHAR(64),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (blocker_id <> blocked_id),
  PRIMARY KEY (blocker_id, blocked_id)
);

CREATE TABLE IF NOT EXISTS mutes (
  muter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  muted_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  mute_type VARCHAR(24) NOT NULL DEFAULT 'all',
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (muter_id <> muted_user_id),
  PRIMARY KEY (muter_id, muted_user_id, mute_type)
);

CREATE TABLE IF NOT EXISTS topic_catalog (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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

CREATE TABLE IF NOT EXISTS post_stats (
  post_id UUID PRIMARY KEY REFERENCES posts(id) ON DELETE CASCADE,
  likes_count BIGINT NOT NULL DEFAULT 0,
  comments_count BIGINT NOT NULL DEFAULT 0,
  shares_count BIGINT NOT NULL DEFAULT 0,
  bookmarks_count BIGINT NOT NULL DEFAULT 0,
  impressions_count BIGINT NOT NULL DEFAULT 0,
  reads_count BIGINT NOT NULL DEFAULT 0,
  engagement_score DOUBLE PRECISION NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE post_likes ADD COLUMN IF NOT EXISTS post_uuid UUID;
UPDATE post_likes
SET post_uuid = posts.id
FROM posts
WHERE post_likes.post_id = posts.post_id
  AND post_likes.post_uuid IS NULL;
ALTER TABLE post_likes ADD COLUMN IF NOT EXISTS user_uuid UUID;
UPDATE post_likes
SET user_uuid = users.id
FROM users
WHERE post_likes.user_id = users.user_id
  AND post_likes.user_uuid IS NULL;
ALTER TABLE post_likes ADD COLUMN IF NOT EXISTS reaction_type VARCHAR(24) NOT NULL DEFAULT 'like';
CREATE UNIQUE INDEX IF NOT EXISTS idx_post_likes_uuid_unique ON post_likes (post_uuid, user_uuid, reaction_type);
CREATE INDEX IF NOT EXISTS idx_post_likes_user_uuid_created ON post_likes (user_uuid, created_at DESC);

ALTER TABLE comments ADD COLUMN IF NOT EXISTS id UUID DEFAULT gen_random_uuid();
UPDATE comments SET id = gen_random_uuid() WHERE id IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_comments_uuid_unique ON comments (id);
ALTER TABLE comments ADD COLUMN IF NOT EXISTS post_uuid UUID;
UPDATE comments
SET post_uuid = posts.id
FROM posts
WHERE comments.post_id = posts.post_id
  AND comments.post_uuid IS NULL;
ALTER TABLE comments ADD COLUMN IF NOT EXISTS author_uuid UUID;
UPDATE comments
SET author_uuid = users.id
FROM users
WHERE comments.author_id = users.user_id
  AND comments.author_uuid IS NULL;
ALTER TABLE comments ADD COLUMN IF NOT EXISTS parent_comment_uuid UUID;
UPDATE comments child
SET parent_comment_uuid = parent.id
FROM comments parent
WHERE child.parent_comment_id = parent.comment_id
  AND child.parent_comment_uuid IS NULL;
ALTER TABLE comments ADD COLUMN IF NOT EXISTS depth INTEGER NOT NULL DEFAULT 0;
ALTER TABLE comments ADD COLUMN IF NOT EXISTS likes_count BIGINT NOT NULL DEFAULT 0;
ALTER TABLE comments ADD COLUMN IF NOT EXISTS replies_count BIGINT NOT NULL DEFAULT 0;
ALTER TABLE comments ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ;
ALTER TABLE comments ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS idx_comments_post_uuid_created ON comments (post_uuid, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comments_parent_uuid_created ON comments (parent_comment_uuid, created_at ASC);

ALTER TABLE comment_likes ADD COLUMN IF NOT EXISTS comment_uuid UUID;
UPDATE comment_likes
SET comment_uuid = comments.id
FROM comments
WHERE comment_likes.comment_id = comments.comment_id
  AND comment_likes.comment_uuid IS NULL;
ALTER TABLE comment_likes ADD COLUMN IF NOT EXISTS user_uuid UUID;
UPDATE comment_likes
SET user_uuid = users.id
FROM users
WHERE comment_likes.user_id = users.user_id
  AND comment_likes.user_uuid IS NULL;
ALTER TABLE comment_likes ADD COLUMN IF NOT EXISTS reaction_type VARCHAR(24) NOT NULL DEFAULT 'like';
CREATE UNIQUE INDEX IF NOT EXISTS idx_comment_likes_uuid_unique ON comment_likes (comment_uuid, user_uuid, reaction_type);
CREATE INDEX IF NOT EXISTS idx_comment_likes_user_uuid_created ON comment_likes (user_uuid, created_at DESC);

CREATE TABLE IF NOT EXISTS hashtags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tag VARCHAR(96) NOT NULL,
  tag_normalized VARCHAR(96) NOT NULL UNIQUE,
  posts_count BIGINT NOT NULL DEFAULT 0,
  engagement_score DOUBLE PRECISION NOT NULL DEFAULT 0,
  last_used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS post_hashtags (
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  hashtag_id UUID NOT NULL REFERENCES hashtags(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, hashtag_id)
);

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

CREATE TABLE IF NOT EXISTS hidden_posts (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  reason VARCHAR(64),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, post_id)
);

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

CREATE TABLE IF NOT EXISTS feed_algorithm_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  algorithm_version_id UUID REFERENCES feed_algorithm_versions(id) ON DELETE SET NULL,
  feed_type VARCHAR(24) NOT NULL,
  cursor_in TEXT,
  cursor_out TEXT,
  request_context JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_interest_profiles (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  interests JSONB NOT NULL DEFAULT '{}'::jsonb,
  embedding_version VARCHAR(64),
  freshness_score REAL NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS direct_conversation_pairs (
  lower_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  higher_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (lower_user_id < higher_user_id),
  PRIMARY KEY (lower_user_id, higher_user_id)
);

CREATE TABLE IF NOT EXISTS conversation_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  inviter_id UUID REFERENCES users(id) ON DELETE SET NULL,
  invitee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status VARCHAR(24) NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  responded_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS conversation_events (
  id BIGSERIAL PRIMARY KEY,
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
  event_type VARCHAR(64) NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS message_receipts (
  message_id UUID NOT NULL REFERENCES messages(message_uuid) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receipt_type VARCHAR(24) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id, receipt_type)
);

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
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id UUID,
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
CREATE UNIQUE INDEX IF NOT EXISTS idx_push_subscriptions_endpoint_active ON push_subscriptions (endpoint) WHERE is_active = true;

CREATE TABLE IF NOT EXISTS reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID REFERENCES users(id) ON DELETE SET NULL,
  target_type VARCHAR(32) NOT NULL,
  target_uuid UUID NOT NULL,
  reason VARCHAR(64) NOT NULL,
  details TEXT,
  status VARCHAR(24) NOT NULL DEFAULT 'open',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS moderation_cases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  target_type VARCHAR(32) NOT NULL,
  target_uuid UUID NOT NULL,
  status VARCHAR(24) NOT NULL DEFAULT 'open',
  priority INTEGER NOT NULL DEFAULT 0,
  assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
  opened_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  closed_at TIMESTAMPTZ,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS media_objects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
  bucket VARCHAR(96) NOT NULL,
  object_key TEXT NOT NULL,
  media_type VARCHAR(32) NOT NULL,
  mime_type VARCHAR(120) NOT NULL,
  byte_size BIGINT NOT NULL,
  processing_status VARCHAR(32) NOT NULL DEFAULT 'pending',
  moderation_status VARCHAR(32) NOT NULL DEFAULT 'pending',
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_media_objects_storage_key ON media_objects (bucket, object_key);

CREATE TABLE IF NOT EXISTS upload_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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

CREATE TABLE IF NOT EXISTS outbox_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
CREATE INDEX IF NOT EXISTS idx_outbox_events_pending ON outbox_events (status, available_at, created_at) WHERE status = 'pending';

CREATE TABLE IF NOT EXISTS processed_events (
  consumer_name VARCHAR(96) NOT NULL,
  event_id UUID NOT NULL,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (consumer_name, event_id)
);

CREATE TABLE IF NOT EXISTS dead_letter_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
  id BIGSERIAL,
  actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
  action VARCHAR(96) NOT NULL,
  target_type VARCHAR(64),
  target_uuid UUID,
  ip_address INET,
  user_agent TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (id, occurred_at)
) PARTITION BY RANGE (occurred_at);

CREATE TABLE IF NOT EXISTS admin_audit_logs_default PARTITION OF admin_audit_logs DEFAULT;

COMMIT;
