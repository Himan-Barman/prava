Backend (Production)
=====================

Requirements
------------
- Node.js 20+
- Postgres 16+
- Redis 7+

Environment
-----------
Copy `apps/backend/.env.example` to `apps/backend/.env` and fill in:
- `NODE_ENV=production`
- `PORT` and `WS_PORT`
- `DATABASE_URL`
- `REDIS_URL`
- `JWT_PRIVATE_KEY` and `JWT_PUBLIC_KEY` (PEM strings or escaped `\n`)
- Optional: `APP_NAME`, `RESEND_API_KEY`, `EMAIL_FROM`, `EMAIL_FROM_NAME`, `EMAIL_SUPPORT`, `EMAIL_VERIFY_URL`, `PASSWORD_RESET_URL`, `CORS_ORIGIN`, `S3_*`, `FCM_*`, `APNS_*`

Build & Run
-----------
```
npm ci
npm run build
npm run migrate
NODE_ENV=production npm run start
NODE_ENV=production npm run start:workers
```

Docker
------
```
docker compose -f apps/backend/docker/docker-compose.yml up -d --build
```

Reverse Proxy (Recommended)
---------------------------
- Route HTTPS traffic to `PORT` (REST) and `WS_PORT` (WebSocket).
- Set `CORS_ORIGIN` to your web domain(s).
- Enable TLS termination (Nginx, Caddy, ALB, Cloudflare).
