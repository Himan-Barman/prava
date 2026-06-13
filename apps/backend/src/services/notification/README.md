# Notification Service

The notification service is the backend pipeline for in-app, realtime, and push notifications.

## Architecture

Domain actions enqueue notification events instead of inserting notification rows directly. The worker consumes:

1. `notification_outbox` events produced by notification-aware services.
2. Existing `outbox_events` rows produced by legacy domain flows.

The worker generates canonical notification records, updates `user_stats.unread_notifications_count` atomically, emits WebSocket events, creates push delivery rows, and processes queued push deliveries.

PostgreSQL is authoritative. Redis is only used by the realtime hub for cross-instance fanout when configured.

## Main Tables

- `notifications`: canonical in-app notification records with idempotency keys, stable cursor fields, read/click/dismiss timestamps, priority, preference category, and expiry.
- `notification_outbox`: notification event queue for domain actions.
- `notification_preferences`: per-user category preferences for in-app, push, email, and quiet hours.
- `user_devices`: device and push-token registration.
- `notification_deliveries`: per-device push delivery status and retry state.
- `notification_aggregates`: aggregation windows for high-volume events.
- `notification_dead_letters`: permanently failing notification events.

Runtime migrations in `src/lib/pg.ts` repair these tables and indexes on startup.

## HTTP Routes

All routes require authentication.

- `GET /api/notifications?limit=&cursor=&type=`
- `GET /api/notifications/unread-count`
- `POST /api/notifications/:notificationId/read`
- `POST /api/notifications/:notificationId/click`
- `POST /api/notifications/read-all`
- `DELETE /api/notifications/:notificationId`
- `GET /api/notifications/preferences`
- `PATCH /api/notifications/preferences`
- `POST /api/notifications/devices`
- `DELETE /api/notifications/devices/:deviceId`

`/api/v1/notifications/*` bridges to the same routes and wraps responses in the v1 envelope.

Pagination uses a signed compound cursor over `(created_at DESC, notification_id DESC)`. Invalid cursors return `400`.

## WebSocket Events

The service emits these events through the existing realtime hub:

- `notification.created`
- `notification.updated`
- `notification.read`
- `notification.read_all`
- `notification.unread_count_changed`

For older clients, `notification.created` also emits `NOTIFICATION_PUSH`.

## Notification Types

The registry in `registry.ts` defines supported types, templates, entity type, aggregation eligibility, push eligibility, priority, deep links, preference category, and retention:

- Social graph: follow and friend request events.
- Feed engagement: likes, replies, reposts, quotes, comments, mentions.
- Chat: direct/group messages, group mentions, replies, missed calls.
- Community: group invitations, approvals, role changes, announcements.
- Security: login, password, suspicious login, session events.
- Moderation: removals, report status, warnings, appeals.
- System: announcements, features, maintenance.

Domain code must not trust client-provided title, body, actor, recipient, or deep links for normal notifications.

## Worker

Build and run:

```bash
npm run build
npm run worker
```

The worker loops over:

- legacy `outbox_events`
- `notification_outbox`
- queued push deliveries
- counter reconciliation

Tuning:

- `WORKER_INTERVAL_MS`, default `15000`
- `REDIS_URL`, optional realtime fanout
- `REDIS_TLS`, optional Redis TLS
- `REDIS_KEY_PREFIX`, default `prava`
- `FCM_SERVER_KEY`, optional FCM legacy server key. If unset, push sends use the no-op provider and delivery rows are still tracked.

## Scheduler

Build and run:

```bash
npm run build
npm run scheduler
```

The scheduler calls:

- notification expiry
- invalid device-token cleanup
- pending delivery retry
- processed notification-outbox cleanup
- existing retention and partition maintenance

Tuning:

- `SCHEDULER_INTERVAL_MS`, default `300000`

## Tests

Run:

```bash
npm run typecheck
npm test
```

Current coverage includes:

- stable cursor pagination
- invalid cursor rejection
- read and click separation
- atomic unread-counter decrement
- read-all reset
- preferences update
- device registration and invalidation
- idempotent outbox materialization
- existing auth, feed, chat, and database contracts

## Scaling Notes

For 1 million users, move push delivery from the process-local worker loop to a dedicated queue consumer pool, shard notification delivery by recipient hash, and use Redis Streams or a managed broker with consumer groups for backpressure and replay.
