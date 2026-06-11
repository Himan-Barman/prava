# Schema Catalog

## Identity And Auth

- `users`: legacy account table with additive UUID, handle, privacy, role, and status columns.
- `user_profiles`: profile bio, avatar, cover, location, website, metadata.
- `user_stats`: aggregate counts for profile, posts, graph, and unread notifications.
- `user_privacy_settings`: profile, message, mention, activity, search, and feed personalization settings.
- `user_emails`: normalized verified email records with unique active email and unique primary email.
- `user_credentials`, `user_devices`, `auth_sessions`, `auth_refresh_tokens`, `auth_challenges`, `auth_login_attempts`, `security_events`: production auth/security foundation.
- `roles`, `permissions`, `role_permissions`, `user_roles`: RBAC.

## Social Graph

- `follows`: legacy follow edges with additive UUID columns.
- `friendships`: request/accepted friendship state.
- `blocks`, `mutes`: hard and soft relationship filters.
- `topic_catalog`, `user_selected_topics`: selectable interest taxonomy.
- `user_recommendation_dismissals`: feed exclusion records.

## Posts And Engagement

- `posts`: legacy post table with additive UUID, visibility, status, language, moderation, and engagement columns.
- `post_stats`: normalized counters and engagement score.
- `post_likes`: legacy likes with additive UUID columns and reaction type.
- `post_bookmarks`, `post_shares`, `hashtags`, `post_hashtags`, `post_mentions`, `hidden_posts`: normalized post interaction and discovery tables.
- `comments`: legacy comments with additive UUID, parent UUID, depth, counter, edit, and delete columns.
- `comment_likes`: legacy comment likes with additive UUID columns.

## Ranking And Feed

- `post_quality_scores`, `post_engagement_windows`: scoring inputs.
- `post_topics`, `post_trend_snapshots`, `trending_topics`: existing topic/trend tables with additive UUID scope columns.
- `feed_algorithm_versions`, `feed_requests`, `feed_impressions`, `feed_events`, `feed_served_history`: feed serving and event audit.
- `user_interest_profiles`, `user_topic_affinities`, `user_author_affinities`: personalization state.

## Chat

- `conversations`, `conversation_members`, `messages`: legacy chat tables with additive UUID columns.
- `direct_conversation_pairs`, `conversation_invites`, `conversation_events`, `message_receipts`: normalized chat consistency tables.

## Notifications

- `notifications`: legacy notification table with additive UUID, recipient/actor UUID, entity, delivery, click, and expiry columns.
- `notification_preferences`, `push_subscriptions`: delivery preferences and push endpoints.

## Trust, Safety, Media, Operations

- `reports`, `moderation_cases`, `moderation_case_reports`, `moderation_case_notes`, `moderation_actions`, `user_restrictions`, `content_labels`, `post_content_labels`, `spam_signals`.
- `media_objects`, `upload_sessions`.
- `outbox_events`, `processed_events`, `dead_letter_events`, `idempotency_keys`, `background_job_runs`, `background_job_locks`.
- `feature_flags`, `app_config_versions`, `admin_audit_logs`.

