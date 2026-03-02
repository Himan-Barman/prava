# Backend (Node.js + MongoDB)

This is the active TypeScript backend service for the project.

## Active API
- Local: `http://localhost:3000/api`
- Health: `GET /api/health`
- WebSocket: `ws://localhost:3000` (or `/ws`) with `token` and `deviceId` query params

## Scripts
- `npm run dev` - run in watch mode using TypeScript (`tsx`)
- `npm run build` - compile TypeScript to `dist/`
- `npm run start` - run compiled production server
- `npm run typecheck` - run TypeScript type checks
- `npm run test` - run backend integration tests (chat routes + websocket)
- `npm run load:chat` - run chat message load test with autocannon

## Required env vars
- `MONGODB_URI`
- `MONGODB_DB_NAME`
- `JWT_SECRET`

## Optional env vars
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

## Chat Load Test
Set these env vars, then run `npm run load:chat`:
- `CHAT_LOAD_BASE_URL` (example: `http://127.0.0.1:3000`)
- `CHAT_LOAD_ACCESS_TOKEN`
- `CHAT_LOAD_CONVERSATION_ID`
- Optional tuning: `CHAT_LOAD_CONNECTIONS`, `CHAT_LOAD_DURATION_SEC`, `CHAT_LOAD_WORKERS`, `CHAT_LOAD_PIPELINING`, `CHAT_LOAD_TIMEOUT_SEC`
