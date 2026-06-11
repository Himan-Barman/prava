# Redis Keyspace

## Sessions And Auth

- `auth:session:<session_id>`: session cache.
- `auth:challenge:<challenge_id>`: OTP/challenge TTL.
- `rate:login:<identifier>`: login throttling.

## Feed

- `feed:home:<user_id>`: short-lived cached feed response.
- `feed:served:<user_id>`: recent served post IDs.
- `feed:lock:<user_id>`: rebuild lock.
- `feed:rank:global`: global candidate ranking.

## Notifications

- `notif:unread:<user_id>`: unread count cache.
- `notif:fanout:<event_id>`: delivery fanout lock.
- `push:receipt:<notification_id>`: push provider receipt cache.

## Chat

- `chat:online:<user_id>`: online presence.
- `chat:typing:<conversation_id>:<user_id>`: typing TTL.
- `chat:unread:<user_id>`: unread conversation counts.

## Reliability

- `job:lock:<job_name>`: distributed job lock.
- `idempotency:<key>`: request idempotency mirror.

