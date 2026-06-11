import { sendOtpEmail } from "../../lib/email.js";
import { query, queryMany, queryOne, withTransaction } from "../../lib/pg.js";
import { markOutboxFailed, markOutboxProcessed } from "../../shared/outbox/index.js";
import { incrementMetric, observeTiming } from "../../shared/metrics/index.js";

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

async function createNotification(input: {
  notificationId: string;
  recipient: any;
  actor?: any | null;
  type: string;
  title: string;
  body: string;
  data?: Record<string, unknown>;
}): Promise<void> {
  if (!input.recipient?.user_id || !input.recipient?.id) {
    return;
  }
  if (input.actor?.user_id && input.actor.user_id === input.recipient.user_id) {
    return;
  }

  await withTransaction(async (client) => {
    await client.query(
      `INSERT INTO notifications (
         notification_id, notification_uuid, user_id, recipient_uuid,
         actor_user_id, actor_uuid, type, notification_type,
         title, body, data, entity_type, entity_uuid, created_at
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $7, $8, $9, $10, $11, $12, NOW())
       ON CONFLICT (notification_id) DO NOTHING`,
      [
        input.notificationId,
        input.notificationId,
        input.recipient.user_id,
        input.recipient.id,
        input.actor?.user_id || null,
        input.actor?.id || null,
        input.type,
        input.title,
        input.body,
        JSON.stringify(input.data || {}),
        String(input.data?.entityType || input.type.split(".")[0] || "system"),
        input.data?.entityUuid || null,
      ]
    );

    const inserted = await client.query(
      `SELECT notification_uuid
       FROM notifications
       WHERE notification_id = $1
       LIMIT 1`,
      [input.notificationId]
    );
    const notificationUuid = inserted.rows[0]?.notification_uuid;
    if (notificationUuid) {
      const preferences = await client.query(
        `SELECT channel, enabled
         FROM notification_preferences
         WHERE user_id = $1
           AND notification_type IN ($2, 'all')`,
        [input.recipient.id, input.type]
      );
      const disabled = new Set(
        preferences.rows.filter((row: any) => row.enabled === false).map((row: any) => row.channel)
      );
      const subscriptions = await client.query(
        `SELECT id
         FROM push_subscriptions
         WHERE user_id = $1 AND is_active = TRUE AND revoked_at IS NULL
         LIMIT 25`,
        [input.recipient.id]
      );
      if (!disabled.has("push") && (subscriptions.rowCount || 0) > 0) {
        await client.query(
          `INSERT INTO notification_delivery_attempts (
             notification_id, channel, provider, status, attempted_at
           )
           VALUES ($1, 'push', 'configured_subscription', 'queued', NOW())`,
          [notificationUuid]
        );
      }
    }

    await client.query(
      `INSERT INTO user_stats (user_id, unread_notifications_count, updated_at)
       VALUES ($1, 1, NOW())
       ON CONFLICT (user_id)
       DO UPDATE SET unread_notifications_count = (
         SELECT COUNT(*)::bigint FROM notifications WHERE recipient_uuid = $1 AND read_at IS NULL
       ), updated_at = NOW()`,
      [input.recipient.id]
    );
  });
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
  const recipient = await resolveLegacyUser(post.author_id);
  await createNotification({
    notificationId: String(event.id),
    recipient,
    actor,
    type: "post.like",
    title: "New like",
    body: `${actor.display_name || actor.username || "Someone"} liked your post.`,
    data: {
      postId: post.post_id,
      entityType: "post",
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
  await createNotification({
    notificationId: String(event.id),
    recipient,
    actor,
    type: "relationship.follow",
    title: "New follower",
    body: `${actor.display_name || actor.username || "Someone"} followed you.`,
    data: {
      actorUserId: actor.user_id,
      entityType: "user",
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
  const events = await queryMany(
    `SELECT *
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

  incrementMetric("worker.outbox.processed", processed);
  incrementMetric("worker.outbox.failed", failed);
  observeTiming("worker.outbox.batch_ms", Date.now() - started);
  return { processed, failed };
}
