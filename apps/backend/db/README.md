# Prava PostgreSQL Migrations

This directory contains PostgreSQL migration artifacts for the Prava database foundation.

## Files

- `migrations/0001_database_foundation.sql`
- `migrations/0002_database_domain_expansion.sql`
- `migrations/0003_database_functions_triggers_jobs_partitions.sql`
- `seeds/0001_foundation_seed.sql`
- `seeds/0002_domain_seed.sql`
- `rollbacks/0001_database_foundation.sql`
- `rollbacks/0002_database_domain_expansion.sql`
- `rollbacks/0003_database_functions_triggers_jobs_partitions.sql`
- `validation/001_database_contract.sql`
- `validation/002_operational_checks.sql`

## Apply

```powershell
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/migrations/0001_database_foundation.sql
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/migrations/0002_database_domain_expansion.sql
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/migrations/0003_database_functions_triggers_jobs_partitions.sql
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/seeds/0001_foundation_seed.sql
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/seeds/0002_domain_seed.sql
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/validation/001_database_contract.sql
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/validation/002_operational_checks.sql
```

The backend also runs idempotent runtime migrations for local and current deployment compatibility.
