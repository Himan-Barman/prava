# Backend Architecture

Prava is implemented as a Node.js TypeScript modular monolith using Fastify, PostgreSQL, Redis, WebSocket, Cloudinary and background workers. The existing `/api/*` routes remain available for mobile compatibility. New public contracts should target `/api/v1/*`, which wraps responses in a stable envelope and maps to durable service implementations.

Process types:

- `api`: REST, WebSocket upgrade routes, auth, profiles, posts, feeds, chat, notifications, media and moderation.
- `worker`: transactional outbox dispatch, feed aggregation and counter reconciliation.
- `scheduler`: retention cleanup and future partition creation.

The current implementation intentionally keeps legacy text IDs while the database foundation adds UUID compatibility columns and normalized production tables.
