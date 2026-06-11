# Partition Plan

## Partitioned In Production

Use monthly range partitions for high-volume append-only tables:

- `admin_audit_logs`
- `feed_events`
- `feed_impressions`
- `feed_requests`
- `outbox_events` if volume becomes high
- `security_events`
- `auth_login_attempts`

## Runtime Compatibility

The TypeScript runtime migration creates unpartitioned versions where needed because `pg-mem` does not fully support partition DDL. The SQL migration includes partitioned `admin_audit_logs` as the production pattern.

## Partition Naming

Use:

`<table>_YYYY_MM`

Example:

`feed_events_2026_06`

## Maintenance

Create next month partitions at least seven days before month start. Drop or archive expired partitions according to `retention-policy.md`.

