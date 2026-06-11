# Existing Schema Audit

## Backend Framework

The backend is a Node.js TypeScript service using Fastify. PostgreSQL access is through the `pg` package, not an ORM. Runtime schema creation currently lives in `apps/backend/src/lib/pg.ts`.

## Migration Process Before This Work

Before this implementation, the backend used one large startup migration SQL block. There were no versioned SQL migration directories under `apps/backend/db`.

## Existing PostgreSQL Tables

The existing runtime schema already created these major tables:

- Identity/auth: `users`, `refresh_tokens`, `email_otp_tokens`, `username_reservations`, `password_reset_tokens`.
- Social graph/settings: `follows`, `user_blocks`, `user_muted_words`, `user_settings`.
- Content/feed: `posts`, `post_tags`, `tag_stats`, `post_likes`, `post_reads`, `post_hidden`, `post_not_interested`, `user_mutes`, `feed_events`, `feed_impressions`, `feed_served_history`, `post_topics`, `post_engagement_stats`, `user_topic_affinities`, `user_author_affinities`, `post_trend_snapshots`, `trending_topics`, `feed_algorithm_config`, `feed_experiments`, `comments`, `comment_likes`.
- Chat: `conversations`, `conversation_members`, `messages`, `message_reactions`, `conversation_reads`, `conversation_user_preferences`.
- Crypto/media/support: `crypto_devices`, `crypto_prekeys`, `notifications`, `support_requests`, `data_exports`, `media_assets`.

## Existing ID Shape

The app uses legacy text IDs in active product tables:

- `users.user_id`
- `posts.post_id`
- `conversations.conversation_id`
- `messages.message_id`
- `notifications.notification_id`

The new PostgreSQL foundation preserves those IDs and adds UUID columns additively.

## Existing Integrations

- JWT and refresh-token logic exists in backend auth services.
- Redis integration exists in `apps/backend/src/lib/redis.ts`.
- Cloudinary integration exists in `apps/backend/src/lib/cloudinary.ts`.
- Existing tests use `pg-mem` with Fastify service tests.

