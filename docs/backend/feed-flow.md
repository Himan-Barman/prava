# Feed Flow

Implemented:

- `/api/v1/feed/following`: chronological following feed.
- `/api/v1/feed/for-you`: heuristic personalized feed.
- Candidate sources include in-network, interacted authors, interests, social proof, trending, exploration and cold start.
- Hard filters remove blocked, muted, hidden, not-interested, deleted and moderated content.
- Feed events are idempotent by client event ID.
- Feed aggregation worker updates affinity, engagement, topic and trend tables.
