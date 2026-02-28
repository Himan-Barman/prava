# Backend (Node.js + MongoDB)

This is the active TypeScript backend service for the project.

## Active API
- Local: `http://localhost:3000/api`
- Health: `GET /api/health`

## Scripts
- `npm run dev` - run in watch mode using TypeScript (`tsx`)
- `npm run build` - compile TypeScript to `dist/`
- `npm run start` - run compiled production server
- `npm run typecheck` - run TypeScript type checks

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
