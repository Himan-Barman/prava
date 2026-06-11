# Migration Plan

## Principles

- No destructive conversion of current text IDs.
- Add UUID columns and normalized tables first.
- Backfill deterministically.
- Move services gradually to UUID columns after validation.
- Drop legacy columns only in a future major migration after app code no longer uses them.

## Steps

1. Deploy runtime migrations from `apps/backend/src/lib/database-foundation.ts` and `apps/backend/src/lib/database-domain-migrations.ts`.
2. Verify `schema_migrations` contains `0001_database_foundation`, `0002_database_domain_expansion`, and `0003_database_functions_triggers_jobs_partitions` in SQL-managed environments.
3. Run `apps/backend/db/seeds/0001_foundation_seed.sql` and `apps/backend/db/seeds/0002_domain_seed.sql` for SQL-managed environments.
4. Run `apps/backend/db/validation/001_database_contract.sql` and `apps/backend/db/validation/002_operational_checks.sql`.
5. Validate counts:
   - `users.id IS NOT NULL` for existing users.
   - `posts.id IS NOT NULL` and `posts.author_uuid IS NOT NULL`.
   - `messages.message_uuid IS NOT NULL`.
   - `notifications.notification_uuid IS NOT NULL`.
6. Start writing new services to UUID columns and normalized stats/event tables.
7. Add background workers for outbox delivery, notification fanout, and feed aggregation.

## Compatibility Notes

The live backend still inserts into legacy columns. The foundation and domain runtime migrations are re-runnable and backfill rows that were inserted after the first migration pass. PostgreSQL deployments should also apply the SQL trigger/function migration so counters, notification-read accounting, retention jobs, partition helpers, and validation live inside the database.
