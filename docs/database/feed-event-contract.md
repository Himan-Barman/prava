# Feed Event Contract

## Event Table

`feed_events` records user interaction events. Existing legacy columns remain, with additive UUID columns:

- `request_uuid`
- `user_uuid`
- `post_uuid`
- `entity_type`
- `event_type`
- `dwell_ms`
- `weight`
- `metadata`
- `created_at`

## Event Types

- `impression`
- `read`
- `like`
- `unlike`
- `comment`
- `share`
- `profile_click`
- `hide`
- `not_interested`
- `report`

## Idempotency

Client-generated IDs should use `client_event_id`. The unique index on `(user_id, client_event_id)` prevents duplicate ingestion for legacy routes. UUID-oriented ingestion should also set `request_uuid` when the event came from a specific feed response.

## Ranking Inputs

Feed ranking reads:

- post recency and quality
- `post_stats`
- `post_engagement_windows`
- `user_topic_affinities`
- `user_author_affinities`
- blocks, mutes, hidden posts, and dismissals

