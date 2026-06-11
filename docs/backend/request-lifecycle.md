# Request Lifecycle

1. Request ID is generated or propagated.
2. Fastify applies security headers, CORS, compression and rate limiting.
3. Protected routes run JWT authentication.
4. `/api/v1` routes validate and bridge to service logic or direct repositories.
5. Services use parameterized PostgreSQL queries and transactions.
6. Durable writes enqueue outbox events where async work is required.
7. `/api/v1` success responses use `{ success, data, meta }`.
8. `/api/v1` errors use `{ success, error, meta }`.
