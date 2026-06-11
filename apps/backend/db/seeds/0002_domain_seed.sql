-- Deterministic domain seed data for 0002_database_domain_expansion.
-- Apply after 0001_foundation_seed.sql and 0002_database_domain_expansion.sql.

BEGIN;

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

COMMIT;
