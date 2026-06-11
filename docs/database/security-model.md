# Security Model

## Access

The backend owns all direct database writes. Clients never receive database credentials. Future admin tools must use RBAC from `roles`, `permissions`, `role_permissions`, and `user_roles`.

## Sensitive Data

- Password hashes live in `users.password_hash` today and `user_credentials.password_hash` in the normalized model.
- Session and refresh token hashes must never store raw tokens.
- Push subscription secrets are limited to notification workers.
- Audit logs must be append-only in production.

## Controls

- Use parameterized SQL for all user input.
- Use unique active indexes for handles, emails, push endpoints, and idempotency keys.
- Write moderation/admin changes to `admin_audit_logs`.
- Use `outbox_events` for side effects that must survive process crashes.

## Future Row-Level Security

RLS can be added for admin analytics or direct reporting connections. The current service-owned database connection does not require RLS for app traffic.

