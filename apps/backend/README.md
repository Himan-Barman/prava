# Backend (Node.js + PostgreSQL)

This is the active TypeScript backend service for the project. Data is stored in PostgreSQL and can use Supabase by setting `DATABASE_URL`.

## Active API
- Local: `http://localhost:3000/api`
- Health: `GET /api/health`
- WebSocket: `ws://localhost:3000` (or `/ws`) with `token` and `deviceId` query params

## Scripts
- `npm run dev` - run in watch mode using TypeScript (`tsx`)
- `npm run build` - compile TypeScript to `dist/`
- `npm run start` - run compiled production server
- `npm run typecheck` - run TypeScript type checks
- `npm run test` - run backend integration tests
- `npm run load:chat` - run chat message load test with autocannon

## Required Env Vars
- `DATABASE_URL`
- `JWT_SECRET` or `JWT_PRIVATE_KEY` / `JWT_PUBLIC_KEY`
- `RESEND_API_KEY` (production email delivery)
- `EMAIL_FROM` (verified sender in Resend)

### Supabase Example
Use the Postgres connection string from Supabase project settings:

`DATABASE_URL=postgresql://postgres:<db_password>@db.<project-ref>.supabase.co:5432/postgres`

Notes:
- Replace `<db_password>` and `<project-ref>` with your Supabase values.
- If the password has special characters, URL-encode it.
- The backend creates required tables and indexes on startup.

### OTP Email Delivery (Resend)
OTP for email verification and password reset is sent through Resend.

Required:
- `RESEND_API_KEY`
- `EMAIL_FROM` (example: `Prava <no-reply@mail.prava.app>`)

Recommended:
- `EMAIL_REPLY_TO` (example: `support@prava.app`)
- `APP_NAME` (default: `Prava`)
- `APP_PUBLIC_URL` (example: `https://prava.app`)
- `OTP_EXPIRES_MINUTES` (default: `10`)
- `USERNAME_RESERVATION_MINUTES` (default: `5`)

## Optional Env Vars
- `JWT_PRIVATE_KEY`
- `JWT_PUBLIC_KEY`
- `PG_POOL_MAX`
- `PG_POOL_IDLE_TIMEOUT_MS`
- `PG_CONNECT_TIMEOUT_MS`
- `PG_STATEMENT_TIMEOUT_MS`
- `CORS_ORIGIN` (comma-separated origins, defaults to `*`)
- `RATE_LIMIT_MAX`
- `RATE_LIMIT_WINDOW_MS`
- `BODY_LIMIT_BYTES`
- `ACCESS_TOKEN_TTL_SECONDS`
- `REFRESH_TOKEN_TTL_SECONDS`
- `REDIS_URL` (enables Redis-backed rate limiting)
- `REDIS_TLS`
- `REDIS_KEY_PREFIX`
- `CONNECTION_TIMEOUT_MS`
- `KEEP_ALIVE_TIMEOUT_MS`
- `MAX_PARAM_LENGTH`
- `PRESSURE_MAX_EVENT_LOOP_DELAY_MS`
- `PRESSURE_MAX_HEAP_USED_BYTES`
- `PRESSURE_MAX_RSS_BYTES`
- `PRESSURE_RETRY_AFTER_SECONDS`

## Local Docker
From the repository root:

```bash
docker compose up --build
```

The compose file starts the API, PostgreSQL, and Redis. It overrides `DATABASE_URL` for the API container.

## Chat Load Test
Set these env vars, then run `npm run load:chat`:
- `CHAT_LOAD_BASE_URL` (example: `http://127.0.0.1:3000`)
- `CHAT_LOAD_ACCESS_TOKEN`
- `CHAT_LOAD_CONVERSATION_ID`
- Optional tuning: `CHAT_LOAD_CONNECTIONS`, `CHAT_LOAD_DURATION_SEC`, `CHAT_LOAD_WORKERS`, `CHAT_LOAD_PIPELINING`, `CHAT_LOAD_TIMEOUT_SEC`
