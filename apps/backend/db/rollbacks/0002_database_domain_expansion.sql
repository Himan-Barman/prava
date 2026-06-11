-- Conservative rollback for 0002_database_domain_expansion.
-- Drops only newly introduced tables. Additive columns on existing production
-- tables are retained to avoid data loss and code/runtime mismatch.

BEGIN;

DROP TABLE IF EXISTS daily_system_metrics CASCADE;
DROP TABLE IF EXISTS retention_job_runs CASCADE;
DROP TABLE IF EXISTS retention_policies CASCADE;
DROP TABLE IF EXISTS feature_flag_overrides CASCADE;
DROP TABLE IF EXISTS moderation_policy_versions CASCADE;
DROP TABLE IF EXISTS moderation_queues CASCADE;
DROP TABLE IF EXISTS notification_batches CASCADE;
DROP TABLE IF EXISTS notification_delivery_attempts CASCADE;
DROP TABLE IF EXISTS group_role_permissions CASCADE;
DROP TABLE IF EXISTS message_delivery_events CASCADE;
DROP TABLE IF EXISTS topic_trend_windows CASCADE;
DROP TABLE IF EXISTS feed_candidate_sources CASCADE;
DROP TABLE IF EXISTS user_negative_feedback CASCADE;
DROP TABLE IF EXISTS feed_request_items CASCADE;
DROP TABLE IF EXISTS mention_notifications CASCADE;
DROP TABLE IF EXISTS hashtag_topic_edges CASCADE;
DROP TABLE IF EXISTS topic_aliases CASCADE;
DROP TABLE IF EXISTS post_reaction_events CASCADE;
DROP TABLE IF EXISTS post_edits CASCADE;
DROP TABLE IF EXISTS user_muted_topics CASCADE;
DROP TABLE IF EXISTS data_export_requests CASCADE;
DROP TABLE IF EXISTS user_phones CASCADE;

DELETE FROM schema_migrations WHERE version = '0002_database_domain_expansion';

COMMIT;
