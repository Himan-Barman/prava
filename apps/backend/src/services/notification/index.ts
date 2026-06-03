import { query, queryMany, queryOne } from "../../lib/pg.js";
import { requireAuth } from "../../lib/auth.js";
import { ensure, toIso, now } from "../../lib/security.js";

function parseLimit(raw, fallback, min, max) {
  const parsed = Number.parseInt(String(raw || ""), 10);
  if (Number.isNaN(parsed)) {
    return fallback;
  }
  return Math.max(min, Math.min(max, parsed));
}

export default async function notificationService(app) {
  app.get("/", { preHandler: requireAuth }, async (request) => {
    const limit = parseLimit(request.query?.limit, 20, 1, 100);
    const cursor = String(request.query?.cursor || "").trim();

    let rows;
    if (cursor) {
      const parsed = new Date(cursor);
      if (!Number.isNaN(parsed.getTime())) {
        rows = await queryMany(
          `SELECT * FROM notifications
           WHERE user_id = $1 AND created_at < $2
           ORDER BY created_at DESC LIMIT $3`,
          [request.user.userId, parsed, limit + 1]
        );
      } else {
        rows = await queryMany(
          `SELECT * FROM notifications
           WHERE user_id = $1
           ORDER BY created_at DESC LIMIT $2`,
          [request.user.userId, limit + 1]
        );
      }
    } else {
      rows = await queryMany(
        `SELECT * FROM notifications
         WHERE user_id = $1
         ORDER BY created_at DESC LIMIT $2`,
        [request.user.userId, limit + 1]
      );
    }

    const hasMore = rows.length > limit;
    const itemsRows = hasMore ? rows.slice(0, limit) : rows;

    const actorIds = [...new Set(itemsRows.map((item) => item.actor_user_id).filter(Boolean))];
    let actors: any[] = [];
    if (actorIds.length > 0) {
      actors = await queryMany(
        `SELECT user_id, username, display_name, is_verified FROM users WHERE user_id = ANY($1)`,
        [actorIds]
      );
    }

    const actorMap = new Map(actors.map((actor) => [actor.user_id, actor]));

    const unreadResult = await queryOne(
      `SELECT COUNT(*)::int AS count FROM notifications WHERE user_id = $1 AND read_at IS NULL`,
      [request.user.userId]
    );
    const unreadCount = unreadResult?.count || 0;

    return {
      items: itemsRows.map((item) => {
        const actor = item.actor_user_id ? actorMap.get(item.actor_user_id) : null;
        return {
          id: item.notification_id,
          type: item.type || "system",
          title: item.title || "Notification",
          body: item.body || "",
          createdAt: toIso(item.created_at),
          readAt: toIso(item.read_at),
          data: item.data || {},
          actor: actor
            ? {
              id: actor.user_id,
              username: actor.username,
              displayName: actor.display_name || actor.username,
              isVerified: actor.is_verified === true,
            }
            : null,
        };
      }),
      nextCursor: hasMore ? toIso(itemsRows[itemsRows.length - 1]?.created_at) : null,
      unreadCount,
    };
  });

  app.get("/unread-count", { preHandler: requireAuth }, async (request) => {
    const result = await queryOne(
      `SELECT COUNT(*)::int AS count FROM notifications WHERE user_id = $1 AND read_at IS NULL`,
      [request.user.userId]
    );

    return { count: result?.count || 0 };
  });

  app.post("/:notificationId/read", { preHandler: requireAuth }, async (request) => {
    const notificationId = String(request.params.notificationId || "").trim();
    ensure(notificationId.length >= 3, 400, "Invalid notification id");

    await query(
      `UPDATE notifications SET read_at = $1 WHERE notification_id = $2 AND user_id = $3`,
      [now(), notificationId, request.user.userId]
    );

    return { success: true };
  });

  app.post("/read-all", { preHandler: requireAuth }, async (request) => {
    await query(
      `UPDATE notifications SET read_at = $1 WHERE user_id = $2 AND read_at IS NULL`,
      [now(), request.user.userId]
    );

    return { success: true };
  });
}
