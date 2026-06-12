 # Cache Strategy

Redis is an acceleration layer only. PostgreSQL remains the source of truth.

Recommended key families:

- `profile:public:{userId}`
- `relationship:{viewerId}:{targetId}`
- `presence:user:{userId}`
- `typing:conversation:{conversationId}:user:{userId}`
- `feed:for_you:{userId}:{algorithmVersion}`
- `feed:following:{userId}`
- `notification:unread:{userId}`
- `conversation:unread:{userId}`
- `lock:worker:{jobName}`

Private authorization must not rely only on stale cache data.
