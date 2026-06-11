-- Deterministic seed data for the Prava database foundation.

BEGIN;

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
ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, is_active = true;

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

COMMIT;
