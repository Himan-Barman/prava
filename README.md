# PRAVA Monorepo

This repository now runs the API from `apps/backend` (Node.js + TypeScript) with **MongoDB** as the primary database.

## Local run

```bash
docker compose up --build
```

Services:
- API: `http://localhost:3000` and `http://localhost:3100` (health: `GET /api/health`)
- MongoDB: `mongodb://localhost:27017/prava_chat`
- Redis: `localhost:6379`

## Environment

Set at least:
- `MONGODB_URI`
- `MONGODB_DB_NAME`
- `JWT_SECRET`

Optional:
- `ACCESS_TOKEN_TTL_SECONDS`
- `REFRESH_TOKEN_TTL_SECONDS`

## Notes

- `apps/backend/` is the active Node.js + TypeScript backend runtime and uses MongoDB.
- The old C++ backend was removed.
