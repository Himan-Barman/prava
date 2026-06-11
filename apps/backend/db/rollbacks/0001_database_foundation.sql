-- Rollback for 0001_database_foundation.
-- This is intentionally conservative. Legacy app tables and additive UUID columns
-- are retained to avoid data loss. Use this only to remove new foundation tables
-- before any application code depends on them.

BEGIN;

DROP TABLE IF EXISTS daily_user_metrics CASCADE;
DROP TABLE IF EXISTS daily_post_metrics CASCADE;
DROP TABLE IF EXISTS admin_audit_logs_default CASCADE;
DROP TABLE IF EXISTS admin_audit_logs CASCADE;
DROP TABLE IF EXISTS app_config_versions CASCADE;
DROP TABLE IF EXISTS feature_flags CASCADE;
DROP TABLE IF EXISTS background_job_locks CASCADE;
DROP TABLE IF EXISTS background_job_runs CASCADE;
DROP TABLE IF EXISTS idempotency_keys CASCADE;
DROP TABLE IF EXISTS dead_letter_events CASCADE;
DROP TABLE IF EXISTS processed_events CASCADE;
DROP TABLE IF EXISTS outbox_events CASCADE;
DROP TABLE IF EXISTS upload_sessions CASCADE;
DROP TABLE IF EXISTS media_objects CASCADE;
DROP TABLE IF EXISTS spam_signals CASCADE;
DROP TABLE IF EXISTS post_content_labels CASCADE;
DROP TABLE IF EXISTS content_labels CASCADE;
DROP TABLE IF EXISTS user_restrictions CASCADE;
DROP TABLE IF EXISTS moderation_actions CASCADE;
DROP TABLE IF EXISTS moderation_case_notes CASCADE;
DROP TABLE IF EXISTS moderation_case_reports CASCADE;
DROP TABLE IF EXISTS moderation_cases CASCADE;
DROP TABLE IF EXISTS reports CASCADE;
DROP TABLE IF EXISTS push_subscriptions CASCADE;
DROP TABLE IF EXISTS notification_preferences CASCADE;
DROP TABLE IF EXISTS message_receipts CASCADE;
DROP TABLE IF EXISTS conversation_events CASCADE;
DROP TABLE IF EXISTS conversation_invites CASCADE;
DROP TABLE IF EXISTS direct_conversation_pairs CASCADE;
DROP TABLE IF EXISTS feed_requests CASCADE;
DROP TABLE IF EXISTS feed_algorithm_versions CASCADE;
DROP TABLE IF EXISTS user_interest_profiles CASCADE;
DROP TABLE IF EXISTS post_engagement_windows CASCADE;
DROP TABLE IF EXISTS post_quality_scores CASCADE;
DROP TABLE IF EXISTS hidden_posts CASCADE;
DROP TABLE IF EXISTS post_mentions CASCADE;
DROP TABLE IF EXISTS post_hashtags CASCADE;
DROP TABLE IF EXISTS hashtags CASCADE;
DROP TABLE IF EXISTS post_shares CASCADE;
DROP TABLE IF EXISTS post_bookmarks CASCADE;
DROP TABLE IF EXISTS post_stats CASCADE;
DROP TABLE IF EXISTS user_recommendation_dismissals CASCADE;
DROP TABLE IF EXISTS user_selected_topics CASCADE;
DROP TABLE IF EXISTS topic_catalog CASCADE;
DROP TABLE IF EXISTS mutes CASCADE;
DROP TABLE IF EXISTS blocks CASCADE;
DROP TABLE IF EXISTS friendships CASCADE;
DROP TABLE IF EXISTS user_roles CASCADE;
DROP TABLE IF EXISTS role_permissions CASCADE;
DROP TABLE IF EXISTS permissions CASCADE;
DROP TABLE IF EXISTS roles CASCADE;
DROP TABLE IF EXISTS security_events CASCADE;
DROP TABLE IF EXISTS auth_login_attempts CASCADE;
DROP TABLE IF EXISTS auth_challenges CASCADE;
DROP TABLE IF EXISTS auth_refresh_tokens CASCADE;
DROP TABLE IF EXISTS auth_sessions CASCADE;
DROP TABLE IF EXISTS user_devices CASCADE;
DROP TABLE IF EXISTS user_credentials CASCADE;
DROP TABLE IF EXISTS account_deletion_requests CASCADE;
DROP TABLE IF EXISTS user_consents CASCADE;
DROP TABLE IF EXISTS user_handle_history CASCADE;
DROP TABLE IF EXISTS user_emails CASCADE;
DROP TABLE IF EXISTS user_privacy_settings CASCADE;
DROP TABLE IF EXISTS user_stats CASCADE;
DROP TABLE IF EXISTS user_profiles CASCADE;

DELETE FROM schema_migrations WHERE version = '0001_database_foundation';
DELETE FROM database_foundation_metadata WHERE key IN ('id_strategy', 'rollout_mode', 'runtime_migration', 'spec_status');

COMMIT;
