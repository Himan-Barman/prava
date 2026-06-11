-- Roll back Prava operational PostgreSQL functions, triggers and helpers.
-- This rollback removes only objects created by 0003; it does not drop data tables.

BEGIN;

DROP TRIGGER IF EXISTS trg_notifications_unread_count ON notifications;
DROP TRIGGER IF EXISTS trg_blocks_remove_relationships ON blocks;
DROP TRIGGER IF EXISTS trg_follows_sync_friendship ON follows;
DROP TRIGGER IF EXISTS trg_comments_reconcile ON comments;
DROP TRIGGER IF EXISTS trg_post_likes_reconcile ON post_likes;
DROP TRIGGER IF EXISTS trg_feature_flags_updated_at ON feature_flags;
DROP TRIGGER IF EXISTS trg_upload_sessions_updated_at ON upload_sessions;
DROP TRIGGER IF EXISTS trg_media_objects_updated_at ON media_objects;
DROP TRIGGER IF EXISTS trg_user_devices_updated_at ON user_devices;
DROP TRIGGER IF EXISTS trg_user_emails_updated_at ON user_emails;
DROP TRIGGER IF EXISTS trg_user_privacy_settings_updated_at ON user_privacy_settings;
DROP TRIGGER IF EXISTS trg_user_profiles_updated_at ON user_profiles;
DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
DROP TRIGGER IF EXISTS trg_users_normalize_handle ON users;

DROP FUNCTION IF EXISTS prava_validate_database_contract();
DROP FUNCTION IF EXISTS prava_after_notification_insert();
DROP FUNCTION IF EXISTS prava_mark_notification_read(uuid);
DROP FUNCTION IF EXISTS prava_run_retention_policy(text, integer);
DROP FUNCTION IF EXISTS prava_create_future_partitions(integer);
DROP FUNCTION IF EXISTS prava_create_monthly_partition(regclass, text, date);
DROP FUNCTION IF EXISTS prava_complete_idempotency_key(uuid, uuid, integer, jsonb);
DROP FUNCTION IF EXISTS prava_reserve_idempotency_key(uuid, uuid, text, text, interval);
DROP FUNCTION IF EXISTS prava_enqueue_outbox(text, text, uuid, jsonb, timestamptz);
DROP FUNCTION IF EXISTS prava_remove_relationships_after_block();
DROP FUNCTION IF EXISTS prava_sync_friendship_from_follow();
DROP FUNCTION IF EXISTS prava_after_comment_change();
DROP FUNCTION IF EXISTS prava_after_post_like_change();
DROP FUNCTION IF EXISTS prava_reconcile_post_stats(uuid);
DROP FUNCTION IF EXISTS prava_reconcile_user_stats(uuid);
DROP FUNCTION IF EXISTS prava_normalize_handle();
DROP FUNCTION IF EXISTS prava_set_updated_at();

DELETE FROM schema_migrations
WHERE version = '0003_database_functions_triggers_jobs_partitions';

COMMIT;
