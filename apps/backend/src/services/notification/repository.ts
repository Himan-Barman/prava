import type pg from "pg";

import { query, queryMany, queryOne, withTransaction } from "../../lib/pg.js";
import { HttpError, generateId, now, sha256, toIso } from "../../lib/security.js";
import { encodeCursor, decodeCursor, pageLimit } from "../../shared/pagination/cursor.js";
import { incrementMetric } from "../../shared/metrics/index.js";
import { publishToUsers } from "../realtime/hub.js";
import {
  PREFERENCE_CATEGORIES,
  getNotificationDefinition,
  normalizeNotificationType,
  renderNotification,
  type NotificationType,
  type PreferenceCategory,
} from "./registry.js";

type Queryable = {
  query: (text: string, params?: unknown[]) => Promise<pg.QueryResult<any>>;
};

const NOTIFICATION_ID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const AGGREGATION_WINDOW_MINUTES = 10;
const WORKER_NAME = "notification-worker";

export type NotificationListInput = {
  userId: string;
  limit?: unknown;
  cursor?: unknown;
  type?: unknown;
};

export type NotificationCreateInput = {
  eventId?: string;
  type: NotificationType | string;
  recipientUserId?: string | null;
  recipientInternalId?: string | null;
  actorUserId?: string | null;
  actorInternalId?: string | null;
  entityType?: string | null;
  entityId?: string | null;
  payload?: Record<string, unknown>;
  idempotencyKey?: string;
  aggregationKey?: string | null;
};

export type NotificationEventInput = {
  eventType: NotificationType | string;
  actorUserId?: string | null;
  recipientUserId?: string | null;
  entityType?: string | null;
  entityId?: string | null;
  payload?: Record<string, unknown>;
};

type ResolvedUser = {
  id: string;
  user_id: string;
  username: string;
  display_name: string;
  avatar_url: string;
  is_verified: boolean;
};

function runner(client?: Queryable): Queryable {
  return client || { query };
}

export function isValidNotificationId(value: unknown): boolean {
  return NOTIFICATION_ID_RE.test(String(value || "").trim());
}

export function assertValidNotificationId(value: unknown): string {
  const notificationId = String(value || "").trim();
  if (!isValidNotificationId(notificationId)) {
    throw new HttpError(400, "Invalid notification id");
  }
  return notificationId;
}

function parseNotificationData(value: unknown): Record<string, unknown> {
  if (!value) return {};
  if (typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  try {
    const parsed = JSON.parse(String(value));
    return parsed && typeof parsed === "object" && !Array.isArray(parsed)
      ? parsed
      : {};
  } catch {
    return {};
  }
}

async function resolveUser(
  userIdOrUuid: string | null | undefined,
  client?: Queryable
): Promise<ResolvedUser | null> {
  const value = String(userIdOrUuid || "").trim();
  if (!value) return null;
  const result = await runner(client).query(
    `SELECT id::text AS id, user_id, username, display_name, avatar_url, is_verified
     FROM users
     WHERE user_id = $1 OR id::text = $1
     LIMIT 1`,
    [value]
  );
  return (result.rows[0] as ResolvedUser | undefined) || null;
}

export async function resolveUserInternalId(userId: string, client?: Queryable): Promise<string> {
  const user = await resolveUser(userId, client);
  if (!user) {
    throw new HttpError(404, "User not found");
  }
  return user.id;
}

async function getUnreadCount(internalUserId: string, client?: Queryable): Promise<number> {
  const result = await runner(client).query(
    `SELECT unread_notifications_count::text AS count
     FROM user_stats
     WHERE user_id = $1`,
    [internalUserId]
  );
  return Number(result.rows[0]?.count || 0);
}

async function ensureStatsRow(internalUserId: string, client?: Queryable): Promise<void> {
  await runner(client).query(
    `INSERT INTO user_stats (user_id, unread_notifications_count, updated_at)
     VALUES ($1, 0, NOW())
     ON CONFLICT (user_id) DO NOTHING`,
    [internalUserId]
  );
}

async function incrementUnread(internalUserId: string, client: Queryable): Promise<number> {
  await ensureStatsRow(internalUserId, client);
  const result = await client.query(
    `UPDATE user_stats
     SET unread_notifications_count = unread_notifications_count + 1,
         updated_at = NOW()
     WHERE user_id = $1
     RETURNING unread_notifications_count::text AS count`,
    [internalUserId]
  );
  return Number(result.rows[0]?.count || 0);
}

async function decrementUnread(internalUserId: string, client: Queryable): Promise<number> {
  await ensureStatsRow(internalUserId, client);
  const result = await client.query(
    `UPDATE user_stats
     SET unread_notifications_count = GREATEST(unread_notifications_count - 1, 0),
         updated_at = NOW()
     WHERE user_id = $1
     RETURNING unread_notifications_count::text AS count`,
    [internalUserId]
  );
  return Number(result.rows[0]?.count || 0);
}

async function resetUnread(internalUserId: string, client: Queryable): Promise<number> {
  await ensureStatsRow(internalUserId, client);
  await client.query(
    `UPDATE user_stats
     SET unread_notifications_count = 0,
         updated_at = NOW()
     WHERE user_id = $1`,
    [internalUserId]
  );
  return 0;
}

function rowToNotification(row: any, actor?: any) {
  return {
    id: row.notification_id,
    type: normalizeNotificationType(row.notification_type || row.type),
    legacyType: row.type || row.notification_type,
    title: row.title || "Notification",
    body: row.body || "",
    entityType: row.entity_type || null,
    entityId: row.entity_id || row.entity_uuid || null,
    priority: row.priority || "normal",
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at),
    readAt: toIso(row.read_at),
    clickedAt: toIso(row.clicked_at),
    dismissedAt: toIso(row.dismissed_at),
    expiresAt: toIso(row.expires_at),
    data: parseNotificationData(row.data),
    actor: actor
      ? {
          id: actor.user_id,
          username: actor.username,
          displayName: actor.display_name || actor.username,
          avatarUrl: actor.avatar_url || "",
          isVerified: actor.is_verified === true,
        }
      : null,
  };
}

export async function listNotifications(input: NotificationListInput) {
  const limit = pageLimit(input.limit, 20, 100);
  const user = await resolveUser(input.userId);
  if (!user) throw new HttpError(401, "Unauthorized");
  await ensureStatsRow(user.id);

  const params: unknown[] = [user.id, input.userId];
  let typeSql = "";
  const typeValue = String(input.type || "").trim();
  if (typeValue) {
    const normalizedType = normalizeNotificationType(typeValue);
    params.push(normalizedType);
    typeSql = `AND COALESCE(n.notification_type, n.type) = $${params.length}`;
  }

  let cursorSql = "";
  const cursor = decodeCursor<{ createdAt?: string; notificationId?: string }>(input.cursor);
  if (cursor) {
    const createdAt = new Date(String(cursor.createdAt || ""));
    const notificationId = String(cursor.notificationId || "");
    if (Number.isNaN(createdAt.getTime()) || !isValidNotificationId(notificationId)) {
      throw new HttpError(400, "Invalid cursor");
    }
    params.push(createdAt, notificationId);
    cursorSql = `AND (n.created_at < $${params.length - 1}
      OR (n.created_at = $${params.length - 1} AND n.notification_id < $${params.length}))`;
  }

  params.push(limit + 1);
  const rows = await queryMany(
    `SELECT n.notification_id, n.user_id, n.actor_user_id, n.type, n.notification_type,
            n.title, n.body, n.data, n.entity_type, n.entity_uuid, n.entity_id,
            n.priority, n.read_at, n.clicked_at, n.dismissed_at, n.created_at,
            n.updated_at, n.expires_at, n.actor_internal_user_id, n.actor_uuid
     FROM notifications n
     WHERE (n.recipient_user_id = $1 OR n.recipient_uuid = $1 OR (n.recipient_user_id IS NULL AND n.user_id = $2))
       AND n.dismissed_at IS NULL
       AND (n.expires_at IS NULL OR n.expires_at > NOW())
       ${typeSql}
       ${cursorSql}
     ORDER BY n.created_at DESC, n.notification_id DESC
     LIMIT $${params.length}`,
    params
  );

  const itemsRows = rows.slice(0, limit);
  const actorTextIds = [...new Set(itemsRows.map((row) => row.actor_user_id).filter(Boolean))];
  const actorUuidIds = [...new Set(itemsRows.map((row) => row.actor_internal_user_id || row.actor_uuid).filter(Boolean))];
  const actors = actorTextIds.length > 0 || actorUuidIds.length > 0
    ? await queryMany(
        `SELECT id::text AS id, user_id, username, display_name, avatar_url, is_verified
         FROM users
         WHERE user_id = ANY($1::text[]) OR id::text = ANY($2::text[])`,
        [actorTextIds, actorUuidIds]
      )
    : [];
  const actorByPublicId = new Map(actors.map((actor) => [actor.user_id, actor]));
  const actorByInternalId = new Map(actors.map((actor) => [actor.id, actor]));
  const items = itemsRows.map((row) => rowToNotification(
    row,
    row.actor_user_id
      ? actorByPublicId.get(row.actor_user_id)
      : actorByInternalId.get(String(row.actor_internal_user_id || row.actor_uuid || ""))
  ));
  const last = itemsRows[itemsRows.length - 1];

  return {
    items,
    nextCursor: rows.length > limit && last
      ? encodeCursor({
          createdAt: toIso(last.created_at),
          notificationId: last.notification_id,
        })
      : null,
    unreadCount: await getUnreadCount(user.id),
  };
}

export async function getUnreadNotificationCount(publicUserId: string): Promise<number> {
  const user = await resolveUser(publicUserId);
  if (!user) return 0;
  await ensureStatsRow(user.id);
  return getUnreadCount(user.id);
}

export async function markNotificationRead(publicUserId: string, notificationId: string) {
  const id = assertValidNotificationId(notificationId);
  const user = await resolveUser(publicUserId);
  if (!user) throw new HttpError(401, "Unauthorized");
  return withTransaction(async (client) => {
    const existing = await client.query(
      `SELECT notification_id, read_at
       FROM notifications
       WHERE notification_id = $1
         AND (recipient_user_id = $2 OR recipient_uuid = $2 OR (recipient_user_id IS NULL AND user_id = $3))
       LIMIT 1`,
      [id, user.id, publicUserId]
    );
    const row = existing.rows[0];
    if (!row) throw new HttpError(404, "Notification not found");
    const wasUnread = row.read_at == null;
    const ts = now();
    const updated = await client.query(
      `UPDATE notifications
       SET read_at = COALESCE(read_at, $1),
           updated_at = $1
       WHERE notification_id = $2
       RETURNING notification_id, read_at`,
      [ts, id]
    );
    const unreadCount = wasUnread
      ? await decrementUnread(user.id, client)
      : await getUnreadCount(user.id, client);
    emitNotificationEvent(publicUserId, "notification.read", {
      id,
      readAt: toIso(updated.rows[0]?.read_at),
      unreadCount,
    });
    return {
      success: true,
      readAt: toIso(updated.rows[0]?.read_at),
      unreadCount,
    };
  });
}

export async function markNotificationClicked(publicUserId: string, notificationId: string) {
  const id = assertValidNotificationId(notificationId);
  const user = await resolveUser(publicUserId);
  if (!user) throw new HttpError(401, "Unauthorized");
  const ts = now();
  const result = await query(
    `UPDATE notifications
     SET clicked_at = COALESCE(clicked_at, $1),
         updated_at = $1
     WHERE notification_id = $2
       AND (recipient_user_id = $3 OR recipient_uuid = $3 OR (recipient_user_id IS NULL AND user_id = $4))
     RETURNING notification_id, clicked_at`,
    [ts, id, user.id, publicUserId]
  );
  if ((result.rowCount || 0) === 0) throw new HttpError(404, "Notification not found");
  emitNotificationEvent(publicUserId, "notification.updated", {
    id,
    clickedAt: toIso(result.rows[0]?.clicked_at),
  });
  return {
    success: true,
    clickedAt: toIso(result.rows[0]?.clicked_at),
  };
}

export async function markAllNotificationsRead(publicUserId: string) {
  const user = await resolveUser(publicUserId);
  if (!user) throw new HttpError(401, "Unauthorized");
  return withTransaction(async (client) => {
    await client.query(
      `UPDATE notifications
       SET read_at = COALESCE(read_at, NOW()),
           updated_at = NOW()
       WHERE (recipient_user_id = $1 OR recipient_uuid = $1 OR (recipient_user_id IS NULL AND user_id = $2))
         AND read_at IS NULL`,
      [user.id, publicUserId]
    );
    const unreadCount = await resetUnread(user.id, client);
    emitNotificationEvent(publicUserId, "notification.read_all", { unreadCount });
    return { success: true, unreadCount };
  });
}

export async function dismissNotification(publicUserId: string, notificationId: string) {
  const id = assertValidNotificationId(notificationId);
  const user = await resolveUser(publicUserId);
  if (!user) throw new HttpError(401, "Unauthorized");
  return withTransaction(async (client) => {
    const existing = await client.query(
      `SELECT notification_id, read_at, dismissed_at
       FROM notifications
       WHERE notification_id = $1
         AND (recipient_user_id = $2 OR recipient_uuid = $2 OR (recipient_user_id IS NULL AND user_id = $3))
       LIMIT 1`,
      [id, user.id, publicUserId]
    );
    const row = existing.rows[0];
    if (!row) throw new HttpError(404, "Notification not found");
    const wasUnread = row.read_at == null && row.dismissed_at == null;
    const ts = now();
    await client.query(
      `UPDATE notifications
       SET dismissed_at = COALESCE(dismissed_at, $1),
           updated_at = $1
       WHERE notification_id = $2`,
      [ts, id]
    );
    const unreadCount = wasUnread
      ? await decrementUnread(user.id, client)
      : await getUnreadCount(user.id, client);
    emitNotificationEvent(publicUserId, "notification.updated", {
      id,
      dismissedAt: toIso(ts),
      unreadCount,
    });
    return { success: true, unreadCount };
  });
}

export async function getNotificationPreferences(publicUserId: string) {
  const user = await resolveUser(publicUserId);
  if (!user) throw new HttpError(401, "Unauthorized");
  const rows = await queryMany(
    `SELECT preference_category, notification_type, in_app_enabled, push_enabled,
            email_enabled, quiet_hours_enabled, quiet_hours_start, quiet_hours_end,
            timezone, updated_at
     FROM notification_preferences
     WHERE user_id = $1`,
    [user.id]
  );
  const byCategory = new Map<string, any>();
  for (const row of rows) {
    byCategory.set(row.preference_category || row.notification_type, row);
  }
  return {
    items: PREFERENCE_CATEGORIES.map((category) => {
      const row = byCategory.get(category);
      return {
        category,
        inAppEnabled: row?.in_app_enabled !== false,
        pushEnabled: row?.push_enabled !== false,
        emailEnabled: row?.email_enabled === true,
        quietHoursEnabled: row?.quiet_hours_enabled === true,
        quietHoursStart: row?.quiet_hours_start || null,
        quietHoursEnd: row?.quiet_hours_end || null,
        timezone: row?.timezone || "UTC",
        updatedAt: toIso(row?.updated_at),
      };
    }),
  };
}

function normalizePreferencePatch(value: any): Array<Record<string, unknown>> {
  if (Array.isArray(value?.preferences)) return value.preferences;
  if (Array.isArray(value)) return value;
  if (value?.category) return [value];
  if (value && typeof value === "object") {
    return Object.entries(value).map(([category, patch]) => ({
      category,
      ...(patch && typeof patch === "object" ? patch as Record<string, unknown> : {}),
    }));
  }
  return [];
}

export async function updateNotificationPreferences(publicUserId: string, body: unknown) {
  const user = await resolveUser(publicUserId);
  if (!user) throw new HttpError(401, "Unauthorized");
  const patches = normalizePreferencePatch(body);
  if (patches.length === 0) throw new HttpError(400, "No preferences supplied");

  await withTransaction(async (client) => {
    for (const patch of patches) {
      const category = String(patch.category || "").trim() as PreferenceCategory;
      if (!PREFERENCE_CATEGORIES.includes(category)) {
        throw new HttpError(400, "Invalid preference category");
      }
      const inAppEnabled = patch.inAppEnabled !== undefined ? patch.inAppEnabled === true : true;
      const pushEnabled = patch.pushEnabled !== undefined ? patch.pushEnabled === true : true;
      const emailEnabled = patch.emailEnabled === true;
      const quietHoursEnabled = patch.quietHoursEnabled === true;
      const quietHoursStart = patch.quietHoursStart ? String(patch.quietHoursStart) : null;
      const quietHoursEnd = patch.quietHoursEnd ? String(patch.quietHoursEnd) : null;
      const timezone = String(patch.timezone || "UTC").slice(0, 100);
      await client.query(
        `INSERT INTO notification_preferences (
           user_id, channel, notification_type, preference_category, enabled,
           in_app_enabled, push_enabled, email_enabled, quiet_hours_enabled,
           quiet_hours_start, quiet_hours_end, timezone, created_at, updated_at
         )
         VALUES ($1, 'all', $2, $2, $3, $3, $4, $5, $6, $7, $8, $9, NOW(), NOW())
         ON CONFLICT (user_id, channel, notification_type)
         DO UPDATE SET preference_category = EXCLUDED.preference_category,
                       enabled = EXCLUDED.enabled,
                       in_app_enabled = EXCLUDED.in_app_enabled,
                       push_enabled = EXCLUDED.push_enabled,
                       email_enabled = EXCLUDED.email_enabled,
                       quiet_hours_enabled = EXCLUDED.quiet_hours_enabled,
                       quiet_hours_start = EXCLUDED.quiet_hours_start,
                       quiet_hours_end = EXCLUDED.quiet_hours_end,
                       timezone = EXCLUDED.timezone,
                       updated_at = NOW()`,
        [
          user.id,
          category,
          inAppEnabled,
          pushEnabled,
          emailEnabled,
          quietHoursEnabled,
          quietHoursStart,
          quietHoursEnd,
          timezone,
        ]
      );
    }
  });
  return getNotificationPreferences(publicUserId);
}

export async function registerNotificationDevice(publicUserId: string, body: any) {
  const user = await resolveUser(publicUserId);
  if (!user) throw new HttpError(401, "Unauthorized");
  const publicDeviceId = String(body?.deviceId || body?.publicDeviceId || "").trim();
  const pushToken = String(body?.pushToken || "").trim();
  const platform = String(body?.platform || "unknown").trim().slice(0, 32);
  const pushProvider = String(body?.pushProvider || "fcm").trim().slice(0, 32);
  if (!publicDeviceId || publicDeviceId.length > 160) throw new HttpError(400, "Invalid device id");
  if (!pushToken || pushToken.length > 4096) throw new HttpError(400, "Invalid push token");

  await query(
    `UPDATE user_devices
     SET invalidated_at = NOW(), updated_at = NOW()
     WHERE push_provider = $1
       AND push_token = $2
       AND user_id <> $3
       AND invalidated_at IS NULL`,
    [pushProvider, pushToken, user.id]
  );

  const existing = await queryOne<{ id: string }>(
    `SELECT id::text AS id
     FROM user_devices
     WHERE user_id = $1
       AND public_device_id = $2
       AND revoked_at IS NULL
     LIMIT 1`,
    [user.id, publicDeviceId]
  );
  const deviceUuid = existing?.id || generateId();
  if (existing) {
    await query(
      `UPDATE user_devices
       SET platform = $3,
           app_version = $4,
           device_name = $5,
           push_provider = $6,
           push_token = $7,
           token_refreshed_at = NOW(),
           invalidated_at = NULL,
           last_seen_at = NOW(),
           updated_at = NOW()
       WHERE id = $1 AND user_id = $2`,
      [
        deviceUuid,
        user.id,
        platform,
        String(body?.appVersion || "").slice(0, 32) || null,
        String(body?.deviceName || "").slice(0, 180) || null,
        pushProvider,
        pushToken,
      ]
    );
  } else {
    await query(
      `INSERT INTO user_devices (
         id, user_id, device_fingerprint, public_device_id, platform,
         app_version, device_name, push_provider, push_token, token_refreshed_at,
         last_seen_at, created_at, updated_at
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW(), NOW(), NOW(), NOW())`,
      [
        deviceUuid,
        user.id,
        sha256(publicDeviceId),
        publicDeviceId,
        platform,
        String(body?.appVersion || "").slice(0, 32) || null,
        String(body?.deviceName || "").slice(0, 180) || null,
        pushProvider,
        pushToken,
      ]
    );
  }

  return {
    success: true,
    device: {
      id: publicDeviceId,
      platform,
      pushProvider,
      tokenRefreshedAt: toIso(now()),
    },
  };
}

export async function deleteNotificationDevice(publicUserId: string, deviceId: string) {
  const user = await resolveUser(publicUserId);
  if (!user) throw new HttpError(401, "Unauthorized");
  const publicDeviceId = String(deviceId || "").trim();
  if (!publicDeviceId) throw new HttpError(400, "Invalid device id");
  const result = await query(
    `UPDATE user_devices
     SET invalidated_at = COALESCE(invalidated_at, NOW()),
         revoked_at = COALESCE(revoked_at, NOW()),
         updated_at = NOW()
     WHERE user_id = $1
       AND public_device_id = $2
       AND invalidated_at IS NULL
     RETURNING id`,
    [user.id, publicDeviceId]
  );
  if ((result.rowCount || 0) === 0) throw new HttpError(404, "Device not found");
  return { success: true };
}

async function preferenceAllows(
  internalUserId: string,
  category: PreferenceCategory,
  client: Queryable
): Promise<{ inApp: boolean; push: boolean; email: boolean }> {
  const result = await client.query(
    `SELECT in_app_enabled, push_enabled, email_enabled, enabled
     FROM notification_preferences
     WHERE user_id = $1
       AND (preference_category = $2 OR notification_type = $2)
     ORDER BY updated_at DESC
     LIMIT 1`,
    [internalUserId, category]
  );
  const row = result.rows[0];
  if (!row) return { inApp: true, push: true, email: false };
  return {
    inApp: row.enabled !== false && row.in_app_enabled !== false,
    push: row.enabled !== false && row.push_enabled !== false,
    email: row.email_enabled === true,
  };
}

async function interactionSuppressed(
  recipientPublicId: string,
  actorPublicId: string | null,
  client: Queryable
): Promise<boolean> {
  if (!actorPublicId || recipientPublicId === actorPublicId) return true;
  const result = await client.query(
    `SELECT 1
     FROM user_blocks
     WHERE (blocker_id = $1 AND blocked_id = $2)
        OR (blocker_id = $2 AND blocked_id = $1)
     UNION ALL
     SELECT 1
     FROM user_mutes
     WHERE muter_id = $1 AND muted_id = $2
     LIMIT 1`,
    [recipientPublicId, actorPublicId]
  );
  return (result.rowCount || 0) > 0;
}

function eventContext(input: NotificationCreateInput, recipient: ResolvedUser, actor: ResolvedUser | null) {
  const payload = input.payload || {};
  return {
    actorName: actor?.display_name || actor?.username,
    count: Number(payload.count || 1),
    title: typeof payload.title === "string" ? payload.title : undefined,
    body: typeof payload.body === "string" ? payload.body : undefined,
    postId: String(payload.postId || input.entityId || ""),
    commentId: String(payload.commentId || ""),
    conversationId: String(payload.conversationId || ""),
    userId: actor?.user_id || recipient.user_id,
    groupId: String(payload.groupId || payload.conversationId || ""),
    reportId: String(payload.reportId || ""),
    featureKey: String(payload.featureKey || ""),
  };
}

function emitNotificationEvent(publicUserId: string, eventType: string, payload: Record<string, unknown>) {
  publishToUsers([publicUserId], eventType, payload);
  if (eventType === "notification.created") {
    publishToUsers([publicUserId], "NOTIFICATION_PUSH", payload);
  }
  if (payload.unreadCount !== undefined) {
    publishToUsers([publicUserId], "notification.unread_count_changed", {
      unreadCount: payload.unreadCount,
    });
  }
}

async function schedulePushDeliveries(
  notificationId: string,
  internalUserId: string,
  client: Queryable
): Promise<void> {
  const devices = await client.query(
    `SELECT id
     FROM user_devices
     WHERE user_id = $1
       AND push_token IS NOT NULL
       AND invalidated_at IS NULL
       AND revoked_at IS NULL
     ORDER BY last_seen_at DESC NULLS LAST
     LIMIT 50`,
    [internalUserId]
  );
  for (const device of devices.rows) {
    await client.query(
      `INSERT INTO notification_deliveries (
         delivery_id, notification_id, device_id, channel, status, created_at, updated_at
       )
       VALUES ($1, $2, $3, 'push', 'queued', NOW(), NOW())
       ON CONFLICT (delivery_id) DO NOTHING`,
      [generateId(), notificationId, device.id]
    );
  }
}

export async function createNotificationFromEvent(input: NotificationCreateInput) {
  const type = normalizeNotificationType(input.type);
  const definition = getNotificationDefinition(type);
  return withTransaction(async (client) => {
    const recipient = input.recipientInternalId
      ? await resolveUser(input.recipientInternalId, client)
      : await resolveUser(input.recipientUserId, client);
    if (!recipient) {
      incrementMetric("notifications.skipped.invalid_recipient", 1);
      return { inserted: false, skipped: true, reason: "invalid_recipient" };
    }
    const actor = input.actorInternalId
      ? await resolveUser(input.actorInternalId, client)
      : await resolveUser(input.actorUserId || null, client);
    if (actor?.user_id && await interactionSuppressed(recipient.user_id, actor.user_id, client)) {
      incrementMetric("notifications.skipped.policy", 1);
      return { inserted: false, skipped: true, reason: "policy" };
    }
    const preference = await preferenceAllows(recipient.id, definition.preferenceCategory, client);
    if (!preference.inApp) {
      incrementMetric("notifications.skipped.preference", 1);
      return { inserted: false, skipped: true, reason: "preference" };
    }

    const context = eventContext(input, recipient, actor);
    const rendered = renderNotification(type, context);
    const payload = {
      ...(input.payload || {}),
      deepLink: rendered.deepLink,
      notificationType: type,
    };
    const idempotencyKey = input.idempotencyKey ||
      `${type}:${recipient.id}:${actor?.id || "system"}:${input.entityType || definition.entityType || "system"}:${input.entityId || input.eventId || generateId()}`;
    const aggregationKey = input.aggregationKey ||
      (definition.aggregationEligible && input.entityId
        ? `${type}:${recipient.id}:${input.entityType || definition.entityType}:${input.entityId}`
        : null);
    const expiresAt = new Date(Date.now() + definition.retentionDays * 24 * 60 * 60 * 1000);

    if (aggregationKey) {
      const aggregate = await client.query(
        `SELECT aggregation_key, actor_count, notification_id, window_expires_at
         FROM notification_aggregates
         WHERE aggregation_key = $1 AND recipient_user_id = $2 AND window_expires_at > NOW()
         LIMIT 1`,
        [aggregationKey, recipient.id]
      );
      const current = aggregate.rows[0];
      if (current) {
        const nextCount = Number(current.actor_count || 1) + 1;
        const aggregateRendered = renderNotification(type, {
          ...context,
          count: nextCount,
        });
        await client.query(
          `UPDATE notification_aggregates
           SET actor_count = $3,
               latest_actor_user_id = $4,
               updated_at = NOW()
           WHERE aggregation_key = $1 AND recipient_user_id = $2`,
          [aggregationKey, recipient.id, nextCount, actor?.id || null]
        );
        const updated = await client.query(
          `UPDATE notifications
           SET title = $2,
               body = $3,
               data = data || $4::jsonb,
               updated_at = NOW()
           WHERE notification_id = $1
           RETURNING notification_id, title, body, data, created_at, updated_at, read_at`,
          [
            current.notification_id,
            aggregateRendered.title,
            aggregateRendered.body,
            JSON.stringify({ count: nextCount, latestActorUserId: actor?.user_id || null }),
          ]
        );
        incrementMetric("notifications.aggregated", 1);
        const unreadCount = await getUnreadCount(recipient.id, client);
        emitNotificationEvent(recipient.user_id, "notification.updated", {
          id: current.notification_id,
          title: updated.rows[0]?.title,
          body: updated.rows[0]?.body,
          unreadCount,
        });
        return { inserted: false, aggregated: true, notificationId: current.notification_id, unreadCount };
      }
    }

    const notificationId = generateId();
    const windowExpiresAt = new Date(Date.now() + AGGREGATION_WINDOW_MINUTES * 60 * 1000);
    const insert = await client.query(
      `INSERT INTO notifications (
         notification_id, notification_uuid, user_id, recipient_uuid, recipient_user_id,
         actor_user_id, actor_uuid, actor_internal_user_id, type, notification_type,
         entity_type, entity_uuid, entity_id, aggregation_key, idempotency_key,
         title, body, data, priority, preference_category, push_eligible,
         created_at, updated_at, expires_at
       )
       VALUES ($1, $1, $2, $3, $3, $4, $5, $5, $6, $6, $7, $8, $9, $10, $11,
               $12, $13, $14, $15, $16, $17, NOW(), NOW(), $18)
       ON CONFLICT (idempotency_key) DO NOTHING
       RETURNING notification_id, created_at, read_at`,
      [
        notificationId,
        recipient.user_id,
        recipient.id,
        actor?.user_id || null,
        actor?.id || null,
        type,
        input.entityType || definition.entityType || null,
        NOTIFICATION_ID_RE.test(String(input.entityId || "")) ? input.entityId : null,
        input.entityId || null,
        aggregationKey,
        idempotencyKey,
        rendered.title,
        rendered.body,
        JSON.stringify(payload),
        definition.priority,
        definition.preferenceCategory,
        definition.pushEligible && preference.push,
        expiresAt,
      ]
    );
    if ((insert.rowCount || 0) === 0) {
      incrementMetric("notifications.duplicates", 1);
      return { inserted: false, duplicate: true };
    }
    if (aggregationKey) {
      await client.query(
        `INSERT INTO notification_aggregates (
           aggregation_key, recipient_user_id, notification_type, entity_id,
           actor_count, latest_actor_user_id, notification_id, window_started_at,
           window_expires_at, updated_at
         )
         VALUES ($1, $2, $3, $4, 1, $5, $6, NOW(), $7, NOW())
         ON CONFLICT (aggregation_key, recipient_user_id) DO NOTHING`,
        [
          aggregationKey,
          recipient.id,
          type,
          input.entityId || null,
          actor?.id || null,
          notificationId,
          windowExpiresAt,
        ]
      );
    }
    const unreadCount = await incrementUnread(recipient.id, client);
    if (definition.pushEligible && preference.push) {
      await schedulePushDeliveries(notificationId, recipient.id, client);
    }
    incrementMetric("notifications.inserted", 1);
    emitNotificationEvent(recipient.user_id, "notification.created", {
      id: notificationId,
      type,
      title: rendered.title,
      body: rendered.body,
      createdAt: toIso(insert.rows[0]?.created_at),
      readAt: null,
      data: payload,
      actor: actor
        ? {
            id: actor.user_id,
            username: actor.username,
            displayName: actor.display_name || actor.username,
            avatarUrl: actor.avatar_url || "",
            isVerified: actor.is_verified === true,
          }
        : null,
      unreadCount,
    });
    return { inserted: true, notificationId, unreadCount };
  });
}

export async function enqueueNotificationEvent(
  input: NotificationEventInput,
  client?: Queryable
): Promise<string> {
  const type = normalizeNotificationType(input.eventType);
  const actor = await resolveUser(input.actorUserId || null, client);
  const recipient = await resolveUser(input.recipientUserId || null, client);
  const eventId = generateId();
  await runner(client).query(
    `INSERT INTO notification_outbox (
       event_id, event_type, actor_user_id, recipient_user_id,
       entity_type, entity_id, payload, created_at
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
     ON CONFLICT (event_id) DO NOTHING`,
    [
      eventId,
      type,
      actor?.id || null,
      recipient?.id || null,
      input.entityType || null,
      input.entityId || null,
      JSON.stringify({
        ...(input.payload || {}),
        actorUserId: actor?.user_id || input.actorUserId || null,
        recipientUserId: recipient?.user_id || input.recipientUserId || null,
      }),
    ]
  );
  incrementMetric("notifications.events_produced", 1);
  return eventId;
}

export async function publishNotificationOutboxBatch(limit = 100) {
  const rows = await queryMany(
    `SELECT event_id::text AS event_id, event_type, actor_user_id::text AS actor_user_id,
            recipient_user_id::text AS recipient_user_id, entity_type, entity_id, payload
     FROM notification_outbox
     WHERE published_at IS NULL
     ORDER BY created_at ASC
     LIMIT $1`,
    [limit]
  );
  let processed = 0;
  let failed = 0;
  for (const row of rows) {
    try {
      await createNotificationFromEvent({
        eventId: row.event_id,
        type: row.event_type,
        actorInternalId: row.actor_user_id,
        recipientInternalId: row.recipient_user_id,
        entityType: row.entity_type,
        entityId: row.entity_id,
        payload: parseNotificationData(row.payload),
        idempotencyKey: `notification_outbox:${row.event_id}`,
      });
      await query(
        `UPDATE notification_outbox
         SET published_at = COALESCE(published_at, NOW()),
             last_error = NULL
         WHERE event_id = $1`,
        [row.event_id]
      );
      processed += 1;
    } catch (error) {
      failed += 1;
      const message = error instanceof Error ? error.message : String(error);
      await query(
        `UPDATE notification_outbox
         SET attempt_count = attempt_count + 1,
             last_error = $2,
             locked_at = NULL,
             locked_by = NULL
         WHERE event_id = $1`,
        [row.event_id, message]
      );
      if (message) {
        await query(
          `INSERT INTO notification_dead_letters (
             dead_letter_id, source_event_id, event_type, payload, error_message, failed_at
           )
           SELECT $1, event_id, event_type, payload, $2, NOW()
           FROM notification_outbox
           WHERE event_id = $3 AND attempt_count >= 10
           ON CONFLICT (dead_letter_id) DO NOTHING`,
          [generateId(), message.slice(0, 1000), row.event_id]
        );
      }
    }
  }
  incrementMetric("notifications.outbox_published", processed);
  incrementMetric("notifications.outbox_failed", failed);
  return { processed, failed };
}

export async function reconcileUnreadCounters(limit = 1000) {
  const rows = await queryMany(
    `SELECT u.id::text AS id,
            COUNT(n.notification_id)::bigint AS unread
     FROM users u
     LEFT JOIN notifications n
       ON (n.recipient_user_id = u.id OR n.recipient_uuid = u.id OR (n.recipient_user_id IS NULL AND n.user_id = u.user_id))
      AND n.read_at IS NULL
      AND n.dismissed_at IS NULL
      AND (n.expires_at IS NULL OR n.expires_at > NOW())
     GROUP BY u.id
     LIMIT $1`,
    [limit]
  );
  let repaired = 0;
  for (const row of rows) {
    const result = await query(
      `INSERT INTO user_stats (user_id, unread_notifications_count, updated_at)
       VALUES ($1, $2, NOW())
       ON CONFLICT (user_id)
       DO UPDATE SET unread_notifications_count = EXCLUDED.unread_notifications_count,
                     updated_at = NOW()
       WHERE user_stats.unread_notifications_count <> EXCLUDED.unread_notifications_count`,
      [row.id, Number(row.unread || 0)]
    );
    if ((result.rowCount || 0) > 0) repaired += 1;
  }
  incrementMetric("notifications.reconciled", repaired);
  return { checked: rows.length, repaired };
}

export async function expireOldNotifications(limit = 1000) {
  const result = await query(
    `UPDATE notifications
     SET dismissed_at = COALESCE(dismissed_at, NOW()),
         updated_at = NOW()
     WHERE notification_id IN (
       SELECT notification_id
       FROM notifications
       WHERE expires_at IS NOT NULL
         AND expires_at <= NOW()
         AND dismissed_at IS NULL
       LIMIT $1
     )`,
    [limit]
  );
  incrementMetric("notifications.expired", result.rowCount || 0);
  return { expired: result.rowCount || 0 };
}

export async function cleanupInvalidDeviceTokens(limit = 1000) {
  const result = await query(
    `UPDATE user_devices
     SET invalidated_at = COALESCE(invalidated_at, NOW()),
         updated_at = NOW()
     WHERE id IN (
       SELECT id
       FROM user_devices
       WHERE push_token IS NULL
          OR push_token = ''
          OR revoked_at IS NOT NULL
       LIMIT $1
     )
       AND invalidated_at IS NULL`,
    [limit]
  );
  incrementMetric("notifications.stale_tokens_removed", result.rowCount || 0);
  return { invalidated: result.rowCount || 0 };
}

export async function retryPendingDeliveries(limit = 100) {
  const result = await query(
    `UPDATE notification_deliveries
     SET status = 'queued',
         next_retry_at = NULL,
         updated_at = NOW()
     WHERE delivery_id IN (
       SELECT delivery_id
       FROM notification_deliveries
       WHERE status = 'retry'
         AND (next_retry_at IS NULL OR next_retry_at <= NOW())
       ORDER BY created_at ASC
       LIMIT $1
     )`,
    [limit]
  );
  incrementMetric("notifications.delivery_retries_requeued", result.rowCount || 0);
  return { requeued: result.rowCount || 0 };
}

export async function archiveProcessedNotificationOutbox(retentionDays = 14) {
  const cutoff = new Date(Date.now() - retentionDays * 24 * 60 * 60 * 1000);
  const result = await query(
    `DELETE FROM notification_outbox
     WHERE published_at IS NOT NULL
       AND published_at < $1`,
    [cutoff]
  );
  return { deleted: result.rowCount || 0 };
}

export function workerName(): string {
  return WORKER_NAME;
}
