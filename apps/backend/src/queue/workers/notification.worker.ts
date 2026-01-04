import { Worker } from 'bullmq';
import { and, eq, isNull } from 'drizzle-orm';

import { connection } from '../bullmq.config';
import { db } from '@/db';
import { pushTokens } from '@/db/schema/push_tokens.schema';
import { presenceManager } from '@/realtime/presence.manager';
import { canSendPush, sendPush } from '@/notifications/push.provider';

type NotificationJob = {
  userId: string;
  type?: 'message' | 'system';
  messageId?: string;
  conversationId?: string;
  senderUserId?: string;
  preview?: string;
  deviceId?: string;
  title?: string;
  body?: string;
  data?: Record<string, string>;
};

export const notificationWorker = new Worker<NotificationJob>(
  'notification',
  async (job) => {
    if (job.name !== 'push-message' && job.name !== 'push-notification') {
      return;
    }

    const tokenFilter = job.data.deviceId
      ? and(
          eq(pushTokens.userId, job.data.userId),
          eq(pushTokens.deviceId, job.data.deviceId),
          isNull(pushTokens.revokedAt),
        )
      : and(
          eq(pushTokens.userId, job.data.userId),
          isNull(pushTokens.revokedAt),
        );

    const tokens = await db
      .select({
        deviceId: pushTokens.deviceId,
        token: pushTokens.token,
        platform: pushTokens.platform,
      })
      .from(pushTokens)
      .where(tokenFilter);

    if (tokens.length === 0) return;

    const data: Record<string, string> = {};
    if (job.name === 'push-message') {
      if (job.data.messageId) data.messageId = job.data.messageId;
      if (job.data.conversationId) {
        data.conversationId = job.data.conversationId;
      }
      if (job.data.senderUserId) data.senderUserId = job.data.senderUserId;
      data.type = job.data.type ?? 'message';
    } else if (job.data.data) {
      Object.assign(data, job.data.data);
      if (!data.type) data.type = 'system';
    }

    const title =
      job.name === 'push-message'
        ? job.data.type === 'message'
          ? 'New message'
          : 'Notification'
        : job.data.title ?? 'Notification';
    const body =
      job.name === 'push-message'
        ? job.data.preview ?? 'You have a new notification'
        : job.data.body ?? 'You have a new notification';

    for (const token of tokens) {
      const isOnline = await presenceManager.isDeviceOnline(
        job.data.userId,
        token.deviceId,
      );
      if (isOnline) continue;

      if (!canSendPush(token.platform)) {
        console.warn(`Push not configured for ${token.platform}`);
        continue;
      }

      const result = await sendPush(
        { token: token.token, platform: token.platform },
        { title, body, data },
      );

      if (!result.ok) {
        if (result.reason === 'invalid-token') {
          await db
            .update(pushTokens)
            .set({ revokedAt: new Date(), updatedAt: new Date() })
            .where(
              and(
                eq(pushTokens.userId, job.data.userId),
                eq(pushTokens.deviceId, token.deviceId),
                eq(pushTokens.token, token.token),
              ),
            );
        } else if (result.reason === 'error') {
          console.warn('Push send failed', result.detail ?? '');
        }
      }
    }
  },
  {
    ...connection,
    concurrency: 10,
  },
);
