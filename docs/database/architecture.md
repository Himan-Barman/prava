# Prava Database Architecture

Prava keeps the current app online while moving toward a production UUID-first data model. The existing app tables in `apps/backend/src/lib/pg.ts` use text IDs (`users.user_id`, `posts.post_id`, `conversations.conversation_id`, `messages.message_id`). The foundation migration keeps those columns and adds UUID-compatible columns plus normalized production tables.

## Layers

1. Legacy compatibility layer: existing text-ID tables remain the source used by current routes.
2. UUID foundation layer: additive `id`, `*_uuid`, stats, identity, moderation, notification, media, reliability, and config tables.
3. Event/reliability layer: `outbox_events`, `processed_events`, `dead_letter_events`, `idempotency_keys`, and job tables make async work retryable.
4. Analytics/feed layer: feed request/event/impression tables, affinity tables, interest profiles, engagement windows, and algorithm versions support ranking and auditability.
5. Operational PostgreSQL layer: functions and triggers reconcile counters, sync reciprocal follows to friendships, clear relationships after blocks, reserve idempotency keys, mark notifications read, run retention policies, create future partitions, and validate the contract.

## ID Strategy

Runtime migration backfills UUID columns deterministically from legacy IDs for existing rows. New normalized tables use UUID primary keys. The SQL migration uses `gen_random_uuid()` defaults for PostgreSQL deployments.

## Source Of Truth

Runtime startup migration:
`apps/backend/src/lib/database-foundation.ts`
`apps/backend/src/lib/database-domain-migrations.ts`

SQL migration path:
`apps/backend/db/migrations/0001_database_foundation.sql`
`apps/backend/db/migrations/0002_database_domain_expansion.sql`
`apps/backend/db/migrations/0003_database_functions_triggers_jobs_partitions.sql`

Seed data:
`apps/backend/db/seeds/0001_foundation_seed.sql`
`apps/backend/db/seeds/0002_domain_seed.sql`

Rollback:
`apps/backend/db/rollbacks/0001_database_foundation.sql`
`apps/backend/db/rollbacks/0002_database_domain_expansion.sql`
`apps/backend/db/rollbacks/0003_database_functions_triggers_jobs_partitions.sql`
