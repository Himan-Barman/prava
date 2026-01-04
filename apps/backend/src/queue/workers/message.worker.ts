import { Worker } from 'bullmq';
import {
  connection,
  notificationQueue,
  messageRetryQueue,
} from '../bullmq.config';
import { db } from '@/db';
import { messages } from '@/db/schema/messages.schema';
import { conversationMembers } from '@/db/schema/conversation_members.schema';
import { messageRetries } from '@/db/schema/message_retries.schema';
import { pushTokens } from '@/db/schema/push_tokens.schema';
import { and, eq, inArray, isNull, ne } from 'drizzle-orm';
import { presenceManager } from '@/realtime/presence.manager';

export const messageWorker = new Worker(
  'message',
  async (job) => {
    if (job.name !== 'deliver-message') return;

    const { messageId } = job.data as { messageId: string };

    const msg = await db.query.messages.findFirst({
      where: eq(messages.id, messageId),
    });

    if (!msg) return;

    const members = await db
      .select({ userId: conversationMembers.userId })
      .from(conversationMembers)
      .where(
        and(
          eq(conversationMembers.conversationId, msg.conversationId),
          isNull(conversationMembers.leftAt),
          ne(conversationMembers.userId, msg.senderUserId),
        ),
      );

    let delivered = false;
    const offlineMembers: string[] = [];
    for (const member of members) {
      if (await presenceManager.isOnline(member.userId)) {
        delivered = true;
      } else {
        offlineMembers.push(member.userId);
      }
    }

    if (delivered) {
      console.log('Deliver via WS stub', msg.id);

      await db
        .update(messages)
        .set({ deliveredAt: new Date() })
        .where(eq(messages.id, msg.id));
    }

    if (offlineMembers.length === 0) return;

    const preview =
      msg.contentType === 'text'
        ? msg.body.slice(0, 140)
        : msg.contentType === 'media'
          ? 'Media message'
          : 'New message';

    const tokens = await db
      .select({
        userId: pushTokens.userId,
        deviceId: pushTokens.deviceId,
      })
      .from(pushTokens)
      .where(
        and(
          inArray(pushTokens.userId, offlineMembers),
          isNull(pushTokens.revokedAt),
        ),
      );

    if (tokens.length === 0) return;

    const delayMs = 30_000;
    const nextAttemptAt = new Date(Date.now() + delayMs);

    for (const token of tokens) {
      const isOnline = await presenceManager.isDeviceOnline(
        token.userId,
        token.deviceId,
      );
      if (isOnline) continue;

      await db
        .insert(messageRetries)
        .values({
          messageId: msg.id,
          deviceId: token.deviceId,
          attempt: 0,
          nextAttemptAt,
        })
        .onConflictDoNothing();

      try {
        await notificationQueue.add(
          'push-message',
          {
            userId: token.userId,
            deviceId: token.deviceId,
            type: 'message',
            messageId: msg.id,
            conversationId: msg.conversationId,
            senderUserId: msg.senderUserId,
            preview,
          },
          {
            jobId: `push:${msg.id}:${token.deviceId}:0`,
            attempts: 3,
            backoff: { type: 'exponential', delay: 2000 },
            removeOnComplete: true,
          },
        );
      } catch (err: any) {
        if (!String(err?.message || '').includes('Job already exists')) {
          throw err;
        }
      }

      try {
        await messageRetryQueue.add(
          'message-retry',
          {
            userId: token.userId,
            deviceId: token.deviceId,
            messageId: msg.id,
            conversationId: msg.conversationId,
            senderUserId: msg.senderUserId,
            preview,
          },
          {
            jobId: `retry:${msg.id}:${token.deviceId}`,
            delay: delayMs,
            removeOnComplete: true,
          },
        );
      } catch (err: any) {
        if (!String(err?.message || '').includes('Job already exists')) {
          throw err;
        }
      }
    }
  },
  {
    ...connection,
    concurrency: 20,
  },
);
