# Retention Policy

## Keep Indefinitely

- `users`, `user_profiles`, `user_privacy_settings`
- `posts`, unless user deletion/moderation requires removal
- `conversations`, `messages`, unless deleted under product policy
- `roles`, `permissions`, `feature_flags`, `app_config_versions`

## Time-Limited

- `auth_login_attempts`: 180 days.
- `security_events`: 2 years.
- `feed_events`: 180 days raw, aggregate before deletion.
- `feed_impressions`: 180 days raw, aggregate before deletion.
- `feed_served_history`: 30 to 90 days depending on feed dedupe window.
- `outbox_events`: 30 days after processed.
- `processed_events`: 180 days.
- `dead_letter_events`: until resolved, then 180 days.
- `idempotency_keys`: expire based on `expires_at`.
- `admin_audit_logs`: minimum 7 years.

## Deletion

Account deletion should mark the account in `account_deletion_requests`, anonymize non-required analytics, delete personal credentials/devices/sessions, and remove or tombstone content according to policy.

