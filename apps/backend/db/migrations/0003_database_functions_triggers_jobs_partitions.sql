-- Prava PostgreSQL functions, triggers, jobs and partition helpers.
-- Apply after 0002_database_domain_expansion.sql.

BEGIN;

INSERT INTO schema_migrations (version, checksum, description)
VALUES ('0003_database_functions_triggers_jobs_partitions', 'manual-sql-v1', 'Prava database functions, triggers, jobs and partitions')
ON CONFLICT (version) DO UPDATE SET
  applied_at = EXCLUDED.applied_at,
  checksum = EXCLUDED.checksum,
  description = EXCLUDED.description;

CREATE OR REPLACE FUNCTION prava_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION prava_normalize_handle()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.handle IS NOT NULL THEN
    NEW.handle_normalized = lower(NEW.handle);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_normalize_handle ON users;
CREATE TRIGGER trg_users_normalize_handle
BEFORE INSERT OR UPDATE OF handle ON users
FOR EACH ROW
EXECUTE FUNCTION prava_normalize_handle();

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION prava_set_updated_at();

DROP TRIGGER IF EXISTS trg_user_profiles_updated_at ON user_profiles;
CREATE TRIGGER trg_user_profiles_updated_at
BEFORE UPDATE ON user_profiles
FOR EACH ROW
EXECUTE FUNCTION prava_set_updated_at();

DROP TRIGGER IF EXISTS trg_user_privacy_settings_updated_at ON user_privacy_settings;
CREATE TRIGGER trg_user_privacy_settings_updated_at
BEFORE UPDATE ON user_privacy_settings
FOR EACH ROW
EXECUTE FUNCTION prava_set_updated_at();

DROP TRIGGER IF EXISTS trg_user_emails_updated_at ON user_emails;
CREATE TRIGGER trg_user_emails_updated_at
BEFORE UPDATE ON user_emails
FOR EACH ROW
EXECUTE FUNCTION prava_set_updated_at();

DROP TRIGGER IF EXISTS trg_user_devices_updated_at ON user_devices;
CREATE TRIGGER trg_user_devices_updated_at
BEFORE UPDATE ON user_devices
FOR EACH ROW
EXECUTE FUNCTION prava_set_updated_at();

DROP TRIGGER IF EXISTS trg_media_objects_updated_at ON media_objects;
CREATE TRIGGER trg_media_objects_updated_at
BEFORE UPDATE ON media_objects
FOR EACH ROW
EXECUTE FUNCTION prava_set_updated_at();

DROP TRIGGER IF EXISTS trg_upload_sessions_updated_at ON upload_sessions;
CREATE TRIGGER trg_upload_sessions_updated_at
BEFORE UPDATE ON upload_sessions
FOR EACH ROW
EXECUTE FUNCTION prava_set_updated_at();

DROP TRIGGER IF EXISTS trg_feature_flags_updated_at ON feature_flags;
CREATE TRIGGER trg_feature_flags_updated_at
BEFORE UPDATE ON feature_flags
FOR EACH ROW
EXECUTE FUNCTION prava_set_updated_at();

CREATE OR REPLACE FUNCTION prava_reconcile_user_stats(target_user_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO user_stats (
    user_id,
    followers_count,
    following_count,
    friends_count,
    posts_count,
    replies_count,
    likes_received,
    updated_at
  )
  VALUES (
    target_user_id,
    0,
    0,
    0,
    0,
    0,
    0,
    now()
  )
  ON CONFLICT (user_id) DO NOTHING;

  UPDATE user_stats
  SET
    followers_count = COALESCE((
      SELECT count(*)::bigint FROM follows
      WHERE following_uuid = target_user_id
        AND COALESCE(status, 'active') = 'active'
        AND removed_at IS NULL
    ), 0),
    following_count = COALESCE((
      SELECT count(*)::bigint FROM follows
      WHERE follower_uuid = target_user_id
        AND COALESCE(status, 'active') = 'active'
        AND removed_at IS NULL
    ), 0),
    friends_count = COALESCE((
      SELECT count(*)::bigint FROM friendships
      WHERE status = 'accepted'
        AND (
          requester_id = target_user_id
          OR addressee_id = target_user_id
          OR user_low_id = target_user_id
          OR user_high_id = target_user_id
        )
    ), 0),
    posts_count = COALESCE((
      SELECT count(*)::bigint FROM posts
      WHERE author_uuid = target_user_id
        AND deleted_at IS NULL
        AND COALESCE(post_type, 'post') IN ('post', 'quote', 'repost')
    ), 0),
    replies_count = COALESCE((
      SELECT count(*)::bigint FROM posts
      WHERE author_uuid = target_user_id
        AND deleted_at IS NULL
        AND COALESCE(post_type, 'post') = 'reply'
    ), 0),
    likes_received = COALESCE((
      SELECT count(*)::bigint
      FROM post_likes pl
      JOIN posts p ON p.id = pl.post_uuid
      WHERE p.author_uuid = target_user_id
    ), 0),
    updated_at = now()
  WHERE user_id = target_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION prava_reconcile_post_stats(target_post_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO post_stats (post_id, updated_at)
  VALUES (target_post_id, now())
  ON CONFLICT (post_id) DO NOTHING;

  UPDATE post_stats
  SET
    likes_count = COALESCE((
      SELECT count(*)::bigint FROM post_likes
      WHERE post_uuid = target_post_id
    ), 0),
    comments_count = COALESCE((
      SELECT count(*)::bigint FROM comments
      WHERE post_uuid = target_post_id
        AND deleted_at IS NULL
        AND COALESCE(status, 'active') = 'active'
    ), 0),
    reply_count = COALESCE((
      SELECT count(*)::bigint FROM posts
      WHERE reply_to_post_uuid = target_post_id
        AND deleted_at IS NULL
    ), 0),
    repost_count = COALESCE((
      SELECT count(*)::bigint FROM posts
      WHERE repost_of_post_uuid = target_post_id
        AND deleted_at IS NULL
    ), 0),
    quote_count = COALESCE((
      SELECT count(*)::bigint FROM posts
      WHERE quote_of_post_uuid = target_post_id
        AND deleted_at IS NULL
    ), 0),
    bookmarks_count = COALESCE((
      SELECT count(*)::bigint FROM post_bookmarks
      WHERE post_id = target_post_id
    ), 0),
    shares_count = COALESCE((
      SELECT count(*)::bigint FROM post_shares
      WHERE post_id = target_post_id
    ), 0),
    reads_count = COALESCE((
      SELECT count(*)::bigint FROM post_reads pr
      JOIN posts p ON p.post_id = pr.post_id
      WHERE p.id = target_post_id
    ), 0),
    updated_at = now()
  WHERE post_id = target_post_id;

  UPDATE posts
  SET
    like_count = COALESCE((SELECT likes_count FROM post_stats WHERE post_id = target_post_id), 0),
    comment_count = COALESCE((SELECT comments_count FROM post_stats WHERE post_id = target_post_id), 0),
    share_count = COALESCE((SELECT shares_count FROM post_stats WHERE post_id = target_post_id), 0),
    reply_count = COALESCE((SELECT reply_count FROM post_stats WHERE post_id = target_post_id), 0),
    repost_count = COALESCE((SELECT repost_count FROM post_stats WHERE post_id = target_post_id), 0),
    quote_count = COALESCE((SELECT quote_count FROM post_stats WHERE post_id = target_post_id), 0),
    bookmark_count = COALESCE((SELECT bookmarks_count FROM post_stats WHERE post_id = target_post_id), 0),
    updated_at = now()
  WHERE id = target_post_id;
END;
$$;

CREATE OR REPLACE FUNCTION prava_after_post_like_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  target_post uuid;
BEGIN
  target_post = COALESCE(NEW.post_uuid, OLD.post_uuid);
  IF target_post IS NOT NULL THEN
    PERFORM prava_reconcile_post_stats(target_post);
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_post_likes_reconcile ON post_likes;
CREATE TRIGGER trg_post_likes_reconcile
AFTER INSERT OR DELETE ON post_likes
FOR EACH ROW
EXECUTE FUNCTION prava_after_post_like_change();

CREATE OR REPLACE FUNCTION prava_after_comment_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  target_post uuid;
BEGIN
  target_post = COALESCE(NEW.post_uuid, OLD.post_uuid);
  IF target_post IS NOT NULL THEN
    PERFORM prava_reconcile_post_stats(target_post);
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_comments_reconcile ON comments;
CREATE TRIGGER trg_comments_reconcile
AFTER INSERT OR UPDATE OF deleted_at, status OR DELETE ON comments
FOR EACH ROW
EXECUTE FUNCTION prava_after_comment_change();

CREATE OR REPLACE FUNCTION prava_sync_friendship_from_follow()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  low_id uuid;
  high_id uuid;
BEGIN
  IF NEW.follower_uuid IS NULL OR NEW.following_uuid IS NULL THEN
    RETURN NEW;
  END IF;

  IF COALESCE(NEW.status, 'active') <> 'active' OR NEW.removed_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM follows reciprocal
    WHERE reciprocal.follower_uuid = NEW.following_uuid
      AND reciprocal.following_uuid = NEW.follower_uuid
      AND COALESCE(reciprocal.status, 'active') = 'active'
      AND reciprocal.removed_at IS NULL
  ) THEN
    low_id = LEAST(NEW.follower_uuid, NEW.following_uuid);
    high_id = GREATEST(NEW.follower_uuid, NEW.following_uuid);

    INSERT INTO friendships (
      requester_id,
      addressee_id,
      user_low_id,
      user_high_id,
      status,
      requested_at,
      responded_at,
      formed_at,
      created_at,
      updated_at
    )
    VALUES (
      NEW.follower_uuid,
      NEW.following_uuid,
      low_id,
      high_id,
      'accepted',
      COALESCE(NEW.requested_at, NEW.created_at, now()),
      now(),
      now(),
      now(),
      now()
    )
    ON CONFLICT (requester_id, addressee_id) DO UPDATE SET
      status = 'accepted',
      user_low_id = EXCLUDED.user_low_id,
      user_high_id = EXCLUDED.user_high_id,
      responded_at = now(),
      formed_at = COALESCE(friendships.formed_at, now()),
      updated_at = now();
  END IF;

  PERFORM prava_reconcile_user_stats(NEW.follower_uuid);
  PERFORM prava_reconcile_user_stats(NEW.following_uuid);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_follows_sync_friendship ON follows;
CREATE TRIGGER trg_follows_sync_friendship
AFTER INSERT OR UPDATE OF status, removed_at, follower_uuid, following_uuid ON follows
FOR EACH ROW
EXECUTE FUNCTION prava_sync_friendship_from_follow();

CREATE OR REPLACE FUNCTION prava_remove_relationships_after_block()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE follows
  SET status = 'removed',
      removed_at = now()
  WHERE (
      follower_uuid = NEW.blocker_id AND following_uuid = NEW.blocked_id
    ) OR (
      follower_uuid = NEW.blocked_id AND following_uuid = NEW.blocker_id
    );

  UPDATE friendships
  SET status = 'blocked',
      updated_at = now()
  WHERE (
      requester_id = NEW.blocker_id AND addressee_id = NEW.blocked_id
    ) OR (
      requester_id = NEW.blocked_id AND addressee_id = NEW.blocker_id
    ) OR (
      user_low_id = LEAST(NEW.blocker_id, NEW.blocked_id)
      AND user_high_id = GREATEST(NEW.blocker_id, NEW.blocked_id)
    );

  PERFORM prava_reconcile_user_stats(NEW.blocker_id);
  PERFORM prava_reconcile_user_stats(NEW.blocked_id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_blocks_remove_relationships ON blocks;
CREATE TRIGGER trg_blocks_remove_relationships
AFTER INSERT ON blocks
FOR EACH ROW
EXECUTE FUNCTION prava_remove_relationships_after_block();

CREATE OR REPLACE FUNCTION prava_enqueue_outbox(
  event_type text,
  aggregate_type text,
  aggregate_id uuid,
  payload jsonb DEFAULT '{}'::jsonb,
  available_at timestamptz DEFAULT now()
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  outbox_id uuid;
BEGIN
  outbox_id = gen_random_uuid();
  INSERT INTO outbox_events (
    id,
    event_type,
    aggregate_type,
    aggregate_uuid,
    aggregate_id,
    payload,
    status,
    available_at,
    created_at
  )
  VALUES (
    outbox_id,
    event_type,
    aggregate_type,
    aggregate_id,
    aggregate_id,
    payload,
    'pending',
    available_at,
    now()
  );
  RETURN outbox_id;
END;
$$;

CREATE OR REPLACE FUNCTION prava_reserve_idempotency_key(
  actor_user_id uuid,
  request_key uuid,
  route text,
  request_hash text,
  ttl interval DEFAULT interval '24 hours'
)
RETURNS TABLE(existing boolean, response_status integer, response_body jsonb)
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO idempotency_keys (
    key,
    user_id,
    idempotency_key,
    route_key,
    request_hash,
    expires_at,
    created_at
  )
  VALUES (
    actor_user_id::text || ':' || request_key::text,
    actor_user_id,
    request_key,
    route,
    request_hash,
    now() + ttl,
    now()
  )
  ON CONFLICT (key) DO NOTHING;

  RETURN QUERY
  SELECT
    response_status IS NOT NULL AS existing,
    idempotency_keys.response_status,
    COALESCE(idempotency_keys.response_snapshot, idempotency_keys.response_body)
  FROM idempotency_keys
  WHERE key = actor_user_id::text || ':' || request_key::text;
END;
$$;

CREATE OR REPLACE FUNCTION prava_complete_idempotency_key(
  actor_user_id uuid,
  request_key uuid,
  status integer,
  response jsonb
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE idempotency_keys
  SET response_status = status,
      response_body = response,
      response_snapshot = response
  WHERE key = actor_user_id::text || ':' || request_key::text;
END;
$$;

CREATE OR REPLACE FUNCTION prava_create_monthly_partition(
  parent_table regclass,
  partition_prefix text,
  month_start date
)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  partition_name text;
  start_ts text;
  end_ts text;
BEGIN
  partition_name = format('%s_%s', partition_prefix, to_char(month_start, 'YYYY_MM'));
  start_ts = month_start::text;
  end_ts = (month_start + interval '1 month')::date::text;

  EXECUTE format(
    'CREATE TABLE IF NOT EXISTS %I PARTITION OF %s FOR VALUES FROM (%L) TO (%L)',
    partition_name,
    parent_table,
    start_ts,
    end_ts
  );

  RETURN partition_name;
END;
$$;

CREATE OR REPLACE FUNCTION prava_create_future_partitions(months_ahead integer DEFAULT 3)
RETURNS TABLE(parent_table text, partition_name text)
LANGUAGE plpgsql
AS $$
DECLARE
  i integer;
  start_month date;
BEGIN
  FOR i IN 0..months_ahead LOOP
    start_month = (date_trunc('month', now()) + make_interval(months => i))::date;
    parent_table = 'admin_audit_logs';
    partition_name = prava_create_monthly_partition('admin_audit_logs'::regclass, 'admin_audit_logs', start_month);
    RETURN NEXT;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION prava_run_retention_policy(policy text, batch_limit integer DEFAULT 10000)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
  p retention_policies%ROWTYPE;
  affected bigint := 0;
  run_id bigint;
BEGIN
  SELECT * INTO p
  FROM retention_policies
  WHERE policy_key = policy
    AND enabled = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Retention policy % not found or disabled', policy;
  END IF;

  INSERT INTO retention_job_runs (policy_key, status, started_at)
  VALUES (policy, 'running', now())
  RETURNING id INTO run_id;

  IF p.action = 'delete' THEN
    EXECUTE format(
      'DELETE FROM %I WHERE created_at < now() - (%L || '' days'')::interval AND ctid IN (SELECT ctid FROM %I WHERE created_at < now() - (%L || '' days'')::interval LIMIT %s)',
      p.table_name,
      p.retention_days,
      p.table_name,
      p.retention_days,
      batch_limit
    );
    GET DIAGNOSTICS affected = ROW_COUNT;
  END IF;

  UPDATE retention_job_runs
  SET status = 'completed',
      completed_at = now(),
      rows_affected = affected
  WHERE id = run_id;

  RETURN affected;
EXCEPTION WHEN OTHERS THEN
  IF run_id IS NOT NULL THEN
    UPDATE retention_job_runs
    SET status = 'failed',
        completed_at = now(),
        error_message = SQLERRM
    WHERE id = run_id;
  END IF;
  RAISE;
END;
$$;

CREATE OR REPLACE FUNCTION prava_mark_notification_read(target_notification uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  recipient uuid;
BEGIN
  UPDATE notifications
  SET read_at = COALESCE(read_at, now()),
      clicked_at = COALESCE(clicked_at, now())
  WHERE notification_uuid = target_notification
  RETURNING recipient_uuid INTO recipient;

  IF recipient IS NOT NULL THEN
    UPDATE user_stats
    SET unread_notifications_count = GREATEST(unread_notifications_count - 1, 0),
        updated_at = now()
    WHERE user_id = recipient
      AND unread_notifications_count > 0;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION prava_after_notification_insert()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.recipient_uuid IS NOT NULL AND NEW.read_at IS NULL THEN
    INSERT INTO user_stats (user_id, unread_notifications_count, updated_at)
    VALUES (NEW.recipient_uuid, 1, now())
    ON CONFLICT (user_id) DO UPDATE SET
      unread_notifications_count = user_stats.unread_notifications_count + 1,
      updated_at = now();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notifications_unread_count ON notifications;
CREATE TRIGGER trg_notifications_unread_count
AFTER INSERT ON notifications
FOR EACH ROW
EXECUTE FUNCTION prava_after_notification_insert();

CREATE OR REPLACE FUNCTION prava_validate_database_contract()
RETURNS TABLE(check_name text, passed boolean, detail text)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 'schema_migration_0001', EXISTS (SELECT 1 FROM schema_migrations WHERE version = '0001_database_foundation'), 'foundation migration recorded';

  RETURN QUERY
  SELECT 'schema_migration_0002', EXISTS (SELECT 1 FROM schema_migrations WHERE version = '0002_database_domain_expansion'), 'domain migration recorded';

  RETURN QUERY
  SELECT 'schema_migration_0003', EXISTS (SELECT 1 FROM schema_migrations WHERE version = '0003_database_functions_triggers_jobs_partitions'), 'functions migration recorded';

  RETURN QUERY
  SELECT 'users_uuid_backfilled', NOT EXISTS (SELECT 1 FROM users WHERE id IS NULL), 'all users have uuid id';

  RETURN QUERY
  SELECT 'posts_uuid_backfilled', NOT EXISTS (SELECT 1 FROM posts WHERE id IS NULL), 'all posts have uuid id';

  RETURN QUERY
  SELECT 'messages_uuid_backfilled', NOT EXISTS (SELECT 1 FROM messages WHERE message_uuid IS NULL), 'all messages have uuid id';

  RETURN QUERY
  SELECT 'retention_policies_seeded', EXISTS (SELECT 1 FROM retention_policies WHERE policy_key = 'feed_events_raw'), 'retention policy seed exists';

  RETURN QUERY
  SELECT 'feed_sources_seeded', EXISTS (SELECT 1 FROM feed_candidate_sources WHERE source_key = 'following_recent'), 'feed source seed exists';

  RETURN QUERY
  SELECT 'moderation_queues_seeded', EXISTS (SELECT 1 FROM moderation_queues WHERE queue_key = 'default'), 'moderation queue seed exists';
END;
$$;

SELECT * FROM prava_create_future_partitions(3);

COMMIT;
