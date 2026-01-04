import { Injectable } from '@nestjs/common';
import { and, eq, isNull, sql } from 'drizzle-orm';

import { db } from '@/db';
import { notifications } from '@/db/schema/notifications.schema';
import { users } from '@/db/schema/users.schema';
import { notificationQueue } from '@/queue/bullmq.config';
import { publishNotification } from './notifications.realtime';

type NotificationInput = {
  userId: string;
  actorId?: string | null;
  type: string;
  title: string;
  body: string;
  data?: Record<string, unknown>;
  push?: boolean;
};

@Injectable()
export class NotificationsService {
  async listForUser(input: {
    userId: string;
    limit?: number;
    cursor?: string;
  }) {
    const limit = Math.min(Math.max(input.limit ?? 30, 1), 50);
    const before = input.cursor ? new Date(input.cursor) : null;
    const useCursor =
      before instanceof Date && !Number.isNaN(before.getTime());

    const cursorClause = useCursor
      ? sql`AND n.created_at < ${before}`
      : sql``;

    const rows = await db.execute(sql`
      SELECT
        n.id,
        n.type,
        n.title,
        n.body,
        n.data,
        n.read_at AS "readAt",
        n.created_at AS "createdAt",
        u.id AS "actorId",
        u.username AS "actorUsername",
        u.display_name AS "actorDisplayName",
        u.is_verified AS "actorVerified"
      FROM notifications n
      LEFT JOIN users u
        ON u.id = n.actor_id
      WHERE n.user_id = ${input.userId}
      ${cursorClause}
      ORDER BY n.created_at DESC
      LIMIT ${limit + 1}
    `);

    const items = rows.rows.map((row) => ({
      id: row.id,
      type: row.type,
      title: row.title,
      body: row.body,
      data: row.data ?? {},
      readAt: row.readAt,
      createdAt: row.createdAt,
      actor: row.actorId
        ? {
            id: row.actorId,
            username: row.actorUsername ?? '',
            displayName:
              row.actorDisplayName ?? row.actorUsername ?? '',
            isVerified: row.actorVerified === true,
          }
        : null,
    }));

    let nextCursor: string | null = null;
    if (items.length > limit) {
      const last = items[limit - 1];
      nextCursor = last?.createdAt
        ? new Date(last.createdAt).toISOString()
        : null;
      items.splice(limit);
    }

    const unreadCount = await this.countUnread(input.userId);

    return {
      items,
      nextCursor,
      unreadCount,
    };
  }

  async countUnread(userId: string) {
    const rows = await db.execute(sql`
      SELECT COUNT(*)::int AS "count"
      FROM notifications
      WHERE user_id = ${userId}
        AND read_at IS NULL
    `);

    return Number(rows.rows[0]?.count ?? 0);
  }

  async markRead(input: { userId: string; notificationId: string }) {
    const [row] = await db
      .update(notifications)
      .set({ readAt: new Date() })
      .where(
        and(
          eq(notifications.id, input.notificationId),
          eq(notifications.userId, input.userId),
          isNull(notifications.readAt),
        ),
      )
      .returning({ id: notifications.id });

    return { success: Boolean(row) };
  }

  async markAllRead(userId: string) {
    await db
      .update(notifications)
      .set({ readAt: new Date() })
      .where(
        and(
          eq(notifications.userId, userId),
          isNull(notifications.readAt),
        ),
      );

    return { success: true };
  }

  async createNotification(input: NotificationInput) {
    if (input.actorId && input.actorId === input.userId) {
      return null;
    }

    const [row] = await db
      .insert(notifications)
      .values({
        userId: input.userId,
        actorId: input.actorId ?? null,
        type: input.type,
        title: input.title,
        body: input.body,
        data: input.data ?? {},
      })
      .returning({
        id: notifications.id,
        data: notifications.data,
        readAt: notifications.readAt,
        createdAt: notifications.createdAt,
      });

    if (!row) return null;

    const actor = input.actorId
      ? await db
          .select({
            id: users.id,
            username: users.username,
            displayName: users.displayName,
            isVerified: users.isVerified,
          })
          .from(users)
          .where(eq(users.id, input.actorId))
          .limit(1)
      : [];

    const payload = {
      id: row.id,
      type: input.type,
      title: input.title,
      body: input.body,
      data: row.data ?? {},
      readAt: row.readAt,
      createdAt: row.createdAt,
      actor: actor[0]
        ? {
            id: actor[0].id,
            username: actor[0].username,
            displayName:
              actor[0].displayName ?? actor[0].username,
            isVerified: actor[0].isVerified === true,
          }
        : null,
    };

    await publishNotification(input.userId, {
      type: 'NOTIFICATION_PUSH',
      payload,
      ts: Date.now(),
    });

    if (input.push) {
      const data: Record<string, string> = {
        type: input.type,
      };
      if (input.actorId) data.actorId = input.actorId;

      const postId = input.data
        ? (input.data['postId'] as string | undefined)
        : undefined;
      if (postId) {
        data.postId = postId;
      }

      try {
        await notificationQueue.add(
          'push-notification',
          {
            userId: input.userId,
            title: input.title,
            body: input.body,
            data,
          },
          {
            attempts: 3,
            backoff: { type: 'exponential', delay: 2000 },
            removeOnComplete: true,
          },
        );
      } catch {
        // Push delivery is best-effort.
      }
    }

    return payload;
  }
}
