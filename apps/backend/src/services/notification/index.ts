import { getDb } from "../../lib/mongo.js";
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
  const db = getDb();

  app.get("/", { preHandler: requireAuth }, async (request) => {
    const limit = parseLimit(request.query?.limit, 20, 1, 100);
    const cursor = String(request.query?.cursor || "").trim();

    const filter: { userId: string; createdAt?: { $lt: Date } } = {
      userId: request.user.userId,
    };

    if (cursor) {
      const parsed = new Date(cursor);
      if (!Number.isNaN(parsed.getTime())) {
        filter.createdAt = { $lt: parsed };
      }
    }

    const rows = await db.collection("notifications").find(filter, {
      sort: { createdAt: -1 },
      limit: limit + 1,
    }).toArray();

    const hasMore = rows.length > limit;
    const itemsRows = hasMore ? rows.slice(0, limit) : rows;

    const actorIds = [...new Set(itemsRows.map((item) => item.actorUserId).filter(Boolean))];
    const actors = actorIds.length
      ? await db.collection("users").find(
          { userId: { $in: actorIds } },
          {
            projection: {
              userId: 1,
              username: 1,
              displayName: 1,
              isVerified: 1,
            },
          }
        ).toArray()
      : [];

    const actorMap = new Map(actors.map((actor) => [actor.userId, actor]));

    const unreadCount = await db.collection("notifications").countDocuments({
      userId: request.user.userId,
      readAt: null,
    });

    return {
      items: itemsRows.map((item) => {
        const actor = item.actorUserId ? actorMap.get(item.actorUserId) : null;
        return {
          id: item.notificationId,
          type: item.type || "system",
          title: item.title || "Notification",
          body: item.body || "",
          createdAt: toIso(item.createdAt),
          readAt: toIso(item.readAt),
          data: item.data || {},
          actor: actor
            ? {
                id: actor.userId,
                username: actor.username,
                displayName: actor.displayName || actor.username,
                isVerified: actor.isVerified === true,
              }
            : null,
        };
      }),
      nextCursor: hasMore ? toIso(itemsRows[itemsRows.length - 1]?.createdAt) : null,
      unreadCount,
    };
  });

  app.get("/unread-count", { preHandler: requireAuth }, async (request) => {
    const count = await db.collection("notifications").countDocuments({
      userId: request.user.userId,
      readAt: null,
    });

    return { count };
  });

  app.post("/:notificationId/read", { preHandler: requireAuth }, async (request) => {
    const notificationId = String(request.params.notificationId || "").trim();
    ensure(notificationId.length >= 3, 400, "Invalid notification id");

    await db.collection("notifications").updateOne(
      {
        notificationId,
        userId: request.user.userId,
      },
      {
        $set: { readAt: now() },
      }
    );

    return { success: true };
  });

  app.post("/read-all", { preHandler: requireAuth }, async (request) => {
    await db.collection("notifications").updateMany(
      {
        userId: request.user.userId,
        readAt: null,
      },
      {
        $set: { readAt: now() },
      }
    );

    return { success: true };
  });
}
