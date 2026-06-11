# Staging Migration Instructions

## Prerequisites

- PostgreSQL 15 or newer.
- Database backup from the target environment.
- Backend environment variables available, especially `DATABASE_URL`.
- `citext` and `pgcrypto` extension permissions.

## Apply In Staging

Run from repository root:

```powershell
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/migrations/0001_database_foundation.sql
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/migrations/0002_database_domain_expansion.sql
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/migrations/0003_database_functions_triggers_jobs_partitions.sql
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/seeds/0001_foundation_seed.sql
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/seeds/0002_domain_seed.sql
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/validation/001_database_contract.sql
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/validation/002_operational_checks.sql
```

## Validate

```powershell
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/validation/001_database_contract.sql
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/validation/002_operational_checks.sql
```

Run backend validation:

```powershell
cd apps/backend
npm run build
npm test
```

## Rollback In Staging

Only before new app code depends on the new domain tables:

```powershell
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/rollbacks/0003_database_functions_triggers_jobs_partitions.sql
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/rollbacks/0002_database_domain_expansion.sql
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f apps/backend/db/rollbacks/0001_database_foundation.sql
```
