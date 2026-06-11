# Production Migration Instructions

## Preflight

1. Take a verified PostgreSQL backup.
2. Confirm staging migration has passed.
3. Confirm backend image includes `apps/backend/src/lib/database-foundation.ts` and `apps/backend/src/lib/database-domain-migrations.ts`.
4. Confirm no client connects directly to PostgreSQL.
5. Confirm `DATABASE_URL` points to production only for the migration operator.

## Apply

Use a maintenance window or low-traffic period. Run SQL migrations once:

```powershell
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/migrations/0001_database_foundation.sql
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/migrations/0002_database_domain_expansion.sql
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/migrations/0003_database_functions_triggers_jobs_partitions.sql
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/seeds/0001_foundation_seed.sql
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/seeds/0002_domain_seed.sql
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/validation/001_database_contract.sql
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/validation/002_operational_checks.sql
```

Then deploy the backend. Startup runtime migrations are idempotent and will refresh missing UUID references for rows inserted during rollout.

## Postflight Checks

```sql
SELECT version, applied_at FROM schema_migrations ORDER BY applied_at;
SELECT count(*) AS missing_user_uuid FROM users WHERE id IS NULL;
SELECT count(*) AS missing_post_uuid FROM posts WHERE id IS NULL;
SELECT count(*) AS missing_message_uuid FROM messages WHERE message_uuid IS NULL;
SELECT count(*) AS pending_outbox FROM outbox_events WHERE status = 'pending';
SELECT policy_key, retention_days FROM retention_policies ORDER BY policy_key;
```

The validation scripts must complete with `ON_ERROR_STOP=1` before the deployment is considered healthy.

## Rollback Policy

Do not run rollback scripts automatically in production. The rollback scripts drop only newly introduced domain tables, but that can still remove data created after deployment. If rollback is required, first stop writes, take another backup, and decide whether to preserve/export the new tables.
