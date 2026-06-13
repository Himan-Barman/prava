import { sendOtpEmail } from "../../lib/email.js";
import { query, queryMany, queryOne, withTransaction } from "../../lib/pg.js";
import { markOutboxFailed, markOutboxProcessed } from "../../shared/outbox/index.js";
import { incrementMetric, observeTiming } from "../../shared/metrics/index.js";
import {
  createNotificationFromEvent,
  publishNotificationOutboxBatch,
} from "../../services/notification/repository.js";
import { sendQueuedPushDeliveries } from "../../services/notification/push.js";

export type OutboxDispatchResult = {
  processed: number;
  failed: number;
};

function parsePayload(value: unknown): Record<string, unknown> {
  if (!value) {
    return {};
  }
  if (typeof value === "object") {
    return value as Record<string, unknown>;
  }
  try {
    const parsed = JSON.parse(String(value));
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    return {};
  }
}

async function resolveLegacyUser(userId: unknown): Promise<any | null> {
  const value = String(userId || "").trim();
  if (!value) {
    return null;
  }
  if (/^[0-9a-f-]{36}$/i.test(value)) {
    return queryOne(
      `SELECT user_id, id::text AS id, username, handle, display_name, avatar_url
       FROM users
       WHERE id = $1 OR user_id = $1
       LIMIT 1`,
      [value]
    );
  }
  return queryOne(
    `SELECT user_id, id::text AS id, username, handle, display_name, avatar_url
     FROM users
     WHERE user_id = $1
     LIMIT 1`,
    [value]
  );
}

async function dispatchAuthEmail(eventType: string, payload: Record<string, unknown>): Promise<void> {
  const email = String(payload.email || "").trim().toLowerCase();
  const code = String(payload.code || payload.devCode || payload.token || "").trim();
  if (!email || !code) {
    return;
  }
  await sendOtpEmail({
    to: email,
    code,
    type: eventType === "auth.password_reset_email.requested" ? "password-reset" : "verification",
  });
}

async function dispatchPostLiked(event: any, payload: Record<string, unknown>): Promise<void> {
  const postId = String(payload.postId || "").trim();
  const actor = await resolveLegacyUser(payload.userId);
  if (!postId || !actor) {
    return;
  }
  const post = await queryOne(
    `SELECT post_id, id::text AS id, author_id
     FROM posts
     WHERE post_id = $1 OR id = $2
     LIMIT 1`,
    [postId, event.aggregate_id || null]
  );
  if (!post) {
    return;
  }
  await createNotificationFromEvent({
    eventId: String(event.id),
    type: "POST_LIKED",
    recipientUserId: post.author_id,
    actorUserId: actor.user_id,
    entityType: "post",
    entityId: post.post_id,
    idempotencyKey: `outbox:${event.id}`,
    payload: {
      postId: post.post_id,
      entityUuid: post.id,
      actorUserId: actor.user_id,
    },
  });
}

async function dispatchFollowAccepted(event: any, payload: Record<string, unknown>): Promise<void> {
  const actor = await resolveLegacyUser(payload.followerId);
  const recipient = await resolveLegacyUser(payload.followingId || event.aggregate_id);
  if (!actor || !recipient) {
    return;
  }
  await createNotificationFromEvent({
    eventId: String(event.id),
    type: "FOLLOW_RECEIVED",
    recipientUserId: recipient.user_id,
    actorUserId: actor.user_id,
    entityType: "user",
    entityId: actor.user_id,
    idempotencyKey: `outbox:${event.id}`,
    payload: {
      actorUserId: actor.user_id,
      entityUuid: actor.id,
    },
  });
}

async function dispatchModerationEvent(event: any, payload: Record<string, unknown>): Promise<void> {
  await query(
    `INSERT INTO admin_audit_logs (
       actor_id, actor_user_id, action, target_type, target_uuid,
       entity_type, entity_id, metadata, occurred_at
     )
     VALUES (NULL, NULL, $1, $2, $3, $2, $3, $4, NOW())`,
    [
      String(event.event_type),
      String(event.aggregate_type || "system"),
      event.aggregate_id && /^[0-9a-f-]{36}$/i.test(String(event.aggregate_id)) ? event.aggregate_id : null,
      JSON.stringify(payload),
    ]
  );
}

async function dispatchEvent(event: any): Promise<void> {
  const payload = parsePayload(event.payload);
  switch (event.event_type) {
    case "noop":
    case "post.unliked":
    case "post.unbookmarked":
    case "post.bookmarked":
      return;
    case "auth.verification_email.requested":
    case "auth.password_reset_email.requested":
      await dispatchAuthEmail(String(event.event_type), payload);
      return;
    case "post.liked":
      await dispatchPostLiked(event, payload);
      return;
    case "follow.accepted":
      await dispatchFollowAccepted(event, payload);
      return;
    case "notification.event":
      await createNotificationFromEvent({
        eventId: String(event.id),
        type: String(payload.type || payload.notificationType || "SYSTEM_ANNOUNCEMENT"),
        recipientUserId: String(payload.recipientUserId || ""),
        actorUserId: payload.actorUserId ? String(payload.actorUserId) : null,
        entityType: payload.entityType ? String(payload.entityType) : null,
        entityId: payload.entityId ? String(payload.entityId) : null,
        idempotencyKey: `outbox:${event.id}`,
        payload,
      });
      return;
    case "moderation.report.created":
    case "moderation.case.note_added":
    case "moderation.action.reversed":
      await dispatchModerationEvent(event, payload);
      return;
    default:
      incrementMetric("worker.outbox.unhandled", 1);
  }
}

export async function runOutboxDispatcherBatch(limit = 100): Promise<OutboxDispatchResult> {
  const started = Date.now();
  const notificationOutbox = await publishNotificationOutboxBatch(Math.max(1, Math.floor(limit / 2)));
  const events = await queryMany(
    `SELECT id::text AS id, aggregate_type, aggregate_uuid::text AS aggregate_uuid,
            aggregate_id::text AS aggregate_id, event_type, payload, attempts,
            available_at, created_at
     FROM outbox_events
     WHERE status = 'pending'
       AND available_at <= NOW()
     ORDER BY created_at ASC
     LIMIT $1`,
    [limit]
  );

  let processed = 0;
  let failed = 0;
  for (const event of events) {
    try {
      await dispatchEvent(event);
      await withTransaction(async (client) => {
        await markOutboxProcessed(String(event.id), client);
      });
      processed += 1;
    } catch (error) {
      await markOutboxFailed(String(event.id), error);
      failed += 1;
    }
  }

  await sendQueuedPushDeliveries(limit).catch(() => undefined);
  incrementMetric("worker.outbox.processed", processed);
  incrementMetric("worker.outbox.failed", failed);
  observeTiming("worker.outbox.batch_ms", Date.now() - started);
  return {
    processed: processed + notificationOutbox.processed,
    failed: failed + notificationOutbox.failed,
  };
}
