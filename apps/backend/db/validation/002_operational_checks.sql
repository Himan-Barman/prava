-- Prava operational validation checks.
-- These checks cover relation safety, idempotency, feed configuration and delivery state.

\set ON_ERROR_STOP on

DO $$
DECLARE
  missing_indexes text;
  missing_tables text;
  missing_functions text;
BEGIN
  SELECT string_agg(index_name, ', ' ORDER BY index_name)
  INTO missing_indexes
  FROM (
    VALUES
      ('idx_users_handle_normalized_unique'),
      ('idx_posts_public_active_cursor'),
      ('idx_posts_repost_once'),
      ('idx_post_likes_uuid_unique'),
      ('idx_comment_likes_uuid_unique'),
      ('idx_messages_client_dedupe'),
      ('idx_notifications_uuid_unique'),
      ('idx_outbox_events_pending'),
      ('idx_auth_sessions_token_hash'),
      ('idx_user_devices_fingerprint_active'),
      ('idx_upload_sessions_owner_status'),
      ('idx_idempotency_keys_expires'),
      ('idx_background_job_runs_job_started')
  ) AS required(index_name)
  WHERE NOT EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = required.index_name
  );

  IF missing_indexes IS NOT NULL THEN
    RAISE EXCEPTION 'Missing required Prava indexes: %', missing_indexes;
  END IF;

  SELECT string_agg(table_name, ', ' ORDER BY table_name)
  INTO missing_tables
  FROM (
    VALUES
      ('feed_candidate_sources'),
      ('feed_request_items'),
      ('notification_delivery_attempts'),
      ('notification_batches'),
      ('moderation_queues'),
      ('moderation_policy_versions'),
      ('auth_sessions'),
      ('auth_refresh_tokens'),
      ('auth_challenges'),
      ('auth_login_attempts'),
      ('security_events'),
      ('user_devices'),
      ('upload_sessions'),
      ('dead_letter_events'),
      ('background_job_runs'),
      ('background_job_locks'),
      ('retention_policies'),
      ('retention_job_runs'),
      ('daily_system_metrics')
  ) AS required(table_name)
  WHERE NOT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = required.table_name
  );

  IF missing_tables IS NOT NULL THEN
    RAISE EXCEPTION 'Missing required Prava tables: %', missing_tables;
  END IF;

  SELECT string_agg(function_name, ', ' ORDER BY function_name)
  INTO missing_functions
  FROM (
    VALUES
      ('prava_reconcile_user_stats'),
      ('prava_reconcile_post_stats'),
      ('prava_enqueue_outbox'),
      ('prava_reserve_idempotency_key'),
      ('prava_complete_idempotency_key'),
      ('prava_run_retention_policy'),
      ('prava_mark_notification_read'),
      ('prava_validate_database_contract')
  ) AS required(function_name)
  WHERE NOT EXISTS (
    SELECT 1
    FROM pg_proc
    JOIN pg_namespace ON pg_namespace.oid = pg_proc.pronamespace
    WHERE pg_namespace.nspname = 'public'
      AND pg_proc.proname = required.function_name
  );

  IF missing_functions IS NOT NULL THEN
    RAISE EXCEPTION 'Missing required Prava database functions: %', missing_functions;
  END IF;
END;
$$;
