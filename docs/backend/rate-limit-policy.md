# Rate Limit Policy

Global Fastify rate limiting is enabled. Route-specific limits should stay strict for:

- Signup and OTP routes.
- Login and refresh.
- Password reset.
- Post create, reply, like and share.
- Follow, block and report.
- Search.
- Feed refresh and feed event ingestion.
- Chat send and typing.
- Upload initialization.

Keys should combine route, IP, authenticated user, device ID and target ID where useful.
