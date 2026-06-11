# Database Implementation Report

## Existing Schema Audit

The backend uses Fastify, TypeScript, `pg`, Redis, and Cloudinary. Existing migrations lived in startup SQL in `apps/backend/src/lib/pg.ts`. Existing production-facing tables use text IDs.

## New Runtime Migration Modules

- `apps/backend/src/lib/database-foundation.ts`
- `apps/backend/src/lib/database-domain-migrations.ts`

## PostgreSQL SQL Migrations

- `apps/backend/db/migrations/0001_database_foundation.sql`
- `apps/backend/db/migrations/0002_database_domain_expansion.sql`
- `apps/backend/db/migrations/0003_database_functions_triggers_jobs_partitions.sql`

## Rollbacks

- `apps/backend/db/rollbacks/0001_database_foundation.sql`
- `apps/backend/db/rollbacks/0002_database_domain_expansion.sql`
- `apps/backend/db/rollbacks/0003_database_functions_triggers_jobs_partitions.sql`

## Seeds

- `apps/backend/db/seeds/0001_foundation_seed.sql`
- `apps/backend/db/seeds/0002_domain_seed.sql`

## Validation

- `apps/backend/db/validation/001_database_contract.sql`
- `apps/backend/db/validation/002_operational_checks.sql`

## New Tables

The migrations add normalized tables for profiles, stats, privacy, emails, phones, credentials, devices, sessions, challenges, RBAC, friendships, blocks, mutes, topics, post stats, hashtags, mentions, post edits, reaction events, feed requests/items, candidate sources, negative feedback, trend windows, direct chat pairs, invites, conversation events, message receipts/delivery events, notification preferences/delivery/batches, moderation queues/policies/cases/actions, media/upload sessions, outbox/idempotency/jobs, feature flags/overrides/config, audit logs, retention policies/jobs, and analytics aggregates.

## Modified Tables

The migrations add UUID and production columns to existing `users`, `posts`, `follows`, `comments`, `post_likes`, `comment_likes`, `conversations`, `conversation_members`, `messages`, `notifications`, `feed_events`, `feed_impressions`, `feed_served_history`, `post_topics`, `post_trend_snapshots`, `trending_topics`, `feature_flags`, `app_config_versions`, and `admin_audit_logs`.

## Constraints And Indexes

Added unique active handles/emails, primary keys for new tables, idempotency keys, duplicate repost prevention, direct-message pair uniqueness, client message retry dedupe, push endpoint uniqueness, pending outbox index, unread notification index, feed/event indexes, moderation queue indexes, retention policy primary keys, and database functions/triggers for counters, follows-to-friendships, block cleanup, outbox enqueueing, idempotency reservation, notification-read accounting, retention execution, partition creation, and contract validation.

## Partitioned Tables

`0001_database_foundation.sql` defines production-style partitioned `admin_audit_logs`. The runtime migration uses unpartitioned tables for `pg-mem` compatibility. Feed event/impression partitioning is documented in `partition-plan.md`.

## Retention Settings

Seeded policies include raw feed events, raw feed impressions, login attempts, processed outbox events, dead-letter events, and admin audit logs.

## Redis Keys

See `docs/database/redis-keyspace.md`.

## Environment Variables

The database layer requires the backend's existing `DATABASE_URL`. Tests also require `JWT_SECRET` because environment validation runs on backend imports.

## Migration Order

1. `0001_database_foundation.sql`
2. `0002_database_domain_expansion.sql`
3. `0003_database_functions_triggers_jobs_partitions.sql`
4. `0001_foundation_seed.sql`
5. `0002_domain_seed.sql`
6. `001_database_contract.sql`
7. `002_operational_checks.sql`

## Test Results

Latest validation:

- `npm run build`: passed
- `npm test`: passed, 17/17 tests
- Migration target check: passed; every `0002` ALTER target exists in the legacy schema or `0001`
- Direct PostgreSQL execution: not run locally because `psql` is not installed in this environment

## Commands Executed

- `npm run build`
- `npm test`
- `git diff --check`
- `psql --version` to check local PostgreSQL client availability

## Known Limitations

- Existing app routes still primarily read/write legacy text IDs.
- PostgreSQL SQL files are the production migration artifacts; runtime migrations remain because the current app has no dedicated migration runner.
- `pg-mem` does not support every PostgreSQL feature, so runtime migrations use compatible forms in a few places.
- The SQL files should still be executed in a staging PostgreSQL 15+ database with `psql` before production rollout.

## Recommended Next Migration

Add background workers for counter reconciliation, outbox delivery, retention cleanup, partition creation, and feed event aggregation. Then migrate app services gradually from legacy text IDs to UUID columns.
