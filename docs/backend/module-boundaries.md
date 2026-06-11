# Module Boundaries

- `src/services/auth`: signup OTP, login, refresh tokens, sessions and password reset.
- `src/services/user`: profiles, settings, social graph, blocks, mutes, search and account center.
- `src/services/feed`: posts, replies, likes, shares, feed events, Following and For You ranking.
- `src/services/chat`: direct messages, groups, reads, delivery, message retries and group membership.
- `src/services/realtime`: authenticated WebSocket gateway.
- `src/services/notification`: notification reads and unread state.
- `src/services/media`: Cloudinary-backed media records.
- `src/services/api-v1`: versioned public contract and envelope.
- `src/shared`: policy, pagination, outbox, metrics and HTTP primitives.
- `src/workers`: durable async processing.
