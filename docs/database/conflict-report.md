# Conflict Report

## Main Conflict

The requested PostgreSQL design expects UUID primary keys for durable business entities. The current app already uses text primary keys in production-facing tables. A direct rewrite would require destructive migration of every foreign key and every service query.

## Resolution

The implementation uses an additive compatibility layer:

- Keep existing text primary keys.
- Add UUID columns such as `users.id`, `posts.id`, `messages.message_uuid`, `notifications.notification_uuid`.
- Backfill UUID values deterministically from legacy IDs in runtime migrations.
- Add normalized UUID-based production tables around the existing schema.
- Keep both runtime migrations and SQL migrations until the app has a dedicated migration runner.

## Tables Upgraded Additively

- `users`
- `user_settings`
- `posts`
- `post_likes`
- `comments`
- `comment_likes`
- `follows`
- `conversations`
- `conversation_members`
- `messages`
- `notifications`
- `feed_events`
- `feed_impressions`
- `feed_served_history`
- `post_topics`
- `post_trend_snapshots`
- `trending_topics`
- `feature_flags`
- `app_config_versions`
- `admin_audit_logs`

## Deferred Destructive Work

No existing table was dropped or renamed. A future UUID-primary migration can be planned only after all services read/write UUID columns and legacy columns are no longer required.

