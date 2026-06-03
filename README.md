# PRAVA Monorepo

This repository runs the API from `apps/backend` (Node.js + TypeScript) with **PostgreSQL** as the primary database. Supabase is supported through `DATABASE_URL`.

## Local run

```bash
docker compose up --build
```

Services:
- API: `http://localhost:3000` and `http://localhost:3100` (health: `GET /api/health`)
- PostgreSQL: `postgresql://postgres:postgres@localhost:5432/prava`
- Redis: `localhost:6379`

## Environment

Set at least:
- `DATABASE_URL`
- `JWT_SECRET`

Optional:
- `ACCESS_TOKEN_TTL_SECONDS`
- `REFRESH_TOKEN_TTL_SECONDS`
- `REDIS_URL` (enables Redis-backed rate limiting)

## Notes

- `apps/backend/` is the active Node.js + TypeScript backend runtime and uses PostgreSQL.
- The old C++ backend was removed.
