# Index Plan

## Hot Path Indexes

- Feed: `posts(visibility, status, created_at DESC)`, `posts(author_uuid, created_at DESC)`, `feed_served_history(user_uuid, expires_at)`.
- Post details: `post_likes(post_uuid, user_uuid, reaction_type)`, `comments(post_uuid, created_at DESC)`, `post_stats(post_id)`.
- Mentions: `post_mentions(mentioned_user_id, created_at DESC)`.
- Notifications: `notifications(recipient_uuid, created_at DESC) WHERE read_at IS NULL`.
- Chat: `messages(conversation_uuid, created_at DESC)`, `conversation_members(user_uuid, status)`.
- Search/discovery: `hashtags(engagement_score DESC, last_used_at DESC)`, `users(handle_normalized) WHERE deleted_at IS NULL`.

## Operational Indexes

- Outbox: `outbox_events(status, available_at, created_at) WHERE status = 'pending'`.
- Idempotency: `idempotency_keys(expires_at)`.
- Moderation: `reports(target_type, target_uuid, status, created_at DESC)`, `moderation_cases(status, priority DESC, opened_at ASC)`.
- Audit: `admin_audit_logs(actor_id, occurred_at DESC)` and `admin_audit_logs(target_type, target_uuid, occurred_at DESC)`.

