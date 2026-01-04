import { Worker } from 'bullmq';
import { and, eq, isNull } from 'drizzle-orm';

import {
  connection,
  messageRetryQueue,
  notificationQueue,
} from '../bullmq.config';
import { db } from '@/db';
import { messageRetries } from '@/db/schema/message_retries.schema';
import { messages } from '@/db/schema/messages.schema';
import { pushTokens } from '@/db/schema/push_tokens.schema';
import { presenceManager } from '@/realtime/presence.manager';

const MAX_ATTEMPTS = 6;
const BASE_DELAY_MS = 30_000;
const MAX_DELAY_MS = 10 * 60 * 1000;

const nextDelayMs = (attempt: number) =>
  Math.min(BASE_DELAY_MS * 2 ** attempt, MAX_DELAY_MS);

type RetryJob = {
  messageId: string;
  deviceId: string;
  userId: string;
  conversationId: string;
  senderUserId: string;
  preview: string;
};

export const messageRetryWorker = new Worker<RetryJob>(
  'message-retry',
  async (job) => {
    if (job.name !== 'message-retry') return;

    const { messageId, deviceId, userId } = job.data;

    const retryRow = await db.query.messageRetries.findFirst({
      where: and(
        eq(messageRetries.messageId, messageId),
        eq(messageRetries.deviceId, deviceId),
      ),
    });

    if (!retryRow) return;
    if (retryRow.attempt >= MAX_ATTEMPTS) return;
    if (retryRow.nextAttemptAt && retryRow.nextAttemptAt > new Date()) {
      return;
    }

    const isOnline = await presenceManager.isDeviceOnline(
      userId,
      deviceId,
    );
    if (isOnline) {
      await db
        .delete(messageRetries)
        .where(
          and(
            eq(messageRetries.messageId, messageId),
            eq(messageRetries.deviceId, deviceId),
          ),
        );
      return;
    }

    const token = await db.query.pushTokens.findFirst({
      where: and(
        eq(pushTokens.userId, userId),
        eq(pushTokens.deviceId, deviceId),
        isNull(pushTokens.revokedAt),
      ),
    });

    if (!token) {
      await db
        .delete(messageRetries)
        .where(
          and(
            eq(messageRetries.messageId, messageId),
            eq(messageRetries.deviceId, deviceId),
          ),
        );
      return;
    }

    const message = await db.query.messages.findFirst({
      where: eq(messages.id, messageId),
    });
    if (!message) {
      await db
        .delete(messageRetries)
        .where(
          and(
            eq(messageRetries.messageId, messageId),
            eq(messageRetries.deviceId, deviceId),
          ),
        );
      return;
    }

    const attempt = retryRow.attempt + 1;
    const delayMs = nextDelayMs(attempt);
    const nextAttemptAt = new Date(Date.now() + delayMs);

    await db
      .update(messageRetries)
      .set({
        attempt,
        lastAttemptAt: new Date(),
        nextAttemptAt,
      })
      .where(
        and(
          eq(messageRetries.messageId, messageId),
          eq(messageRetries.deviceId, deviceId),
        ),
      );

    try {
      await notificationQueue.add(
        'push-message',
        {
          ...job.data,
          deviceId,
        },
        {
          jobId: `push:${messageId}:${deviceId}:${attempt}`,
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
        job.data,
        {
          jobId: `retry:${messageId}:${deviceId}`,
          delay: delayMs,
          removeOnComplete: true,
        },
      );
    } catch (err: any) {
      if (!String(err?.message || '').includes('Job already exists')) {
        throw err;
      }
    }
  },
  {
    ...connection,
    concurrency: 10,
  },
);
