import { BadRequestException, Injectable } from '@nestjs/common';

import { db } from '@/db';
import { conversations } from '@/db/schema/conversations.schema';
import { conversationMembers } from '@/db/schema/conversation_members.schema';
import { messages } from '@/db/schema/messages.schema';
import { messageReactions } from '@/db/schema/message_reactions.schema';
import { syncState } from '@/db/schema/sync_state.schema';
import { MediaService } from '@/modules/media/media.service';
import { and, eq, isNull, sql } from 'drizzle-orm';
import { messageQueue } from '@/queue/bullmq.config';
import { MAX_MESSAGE_BODY_LENGTH } from '@/common/constants';

@Injectable()
export class MessagesService {
  constructor(private readonly media: MediaService) {}

  async sendMessage(input: {
    conversationId: string;
    senderUserId: string;
    senderDeviceId: string;
    body?: string;
    contentType?: 'text' | 'system' | 'media';
    clientTimestamp?: Date | null;
    clientTempId?: string | null;
    mediaAssetId?: string | null;
  }): Promise<{ message: typeof messages.$inferSelect; created: boolean }> {
    const contentType = input.contentType ?? 'text';
    const body = input.body ?? '';

    if (contentType === 'media') {
      if (!input.mediaAssetId) {
        throw new BadRequestException(
          'Media asset is required for media messages',
        );
      }

      if (body.length > MAX_MESSAGE_BODY_LENGTH) {
        throw new BadRequestException('Invalid body length');
      }

      await this.media.assertAssetReadyForMessage({
        assetId: input.mediaAssetId,
        userId: input.senderUserId,
        conversationId: input.conversationId,
      });
    } else {
      if (body.length === 0 || body.length > MAX_MESSAGE_BODY_LENGTH) {
        throw new BadRequestException('Invalid body length');
      }

      if (input.mediaAssetId) {
        throw new BadRequestException(
          'Media asset only allowed for media messages',
        );
      }
    }

    const result = await db.transaction(async (tx) => {
      if (input.clientTempId) {
        const existing = await tx
          .select()
          .from(messages)
          .where(
            and(
              eq(messages.conversationId, input.conversationId),
              eq(messages.senderUserId, input.senderUserId),
              eq(messages.senderDeviceId, input.senderDeviceId),
              eq(messages.clientTempId, input.clientTempId),
            ),
          )
          .limit(1);

        if (existing[0]) {
          return { message: existing[0], created: false };
        }
      }

      /* ================= SEQUENCE ================= */

      const convoResult = await tx.execute(sql`
        SELECT id
        FROM conversations
        WHERE id = ${input.conversationId}
        FOR UPDATE
      `);
      if (convoResult.rows.length === 0) {
        throw new Error('Conversation not found');
      }

      const result = await tx.execute<{ next: number }>(sql`
        SELECT COALESCE(MAX(seq), 0) + 1 AS next
        FROM messages
        WHERE conversation_id = ${input.conversationId}
      `);

      const nextSeq = result.rows[0]?.next ?? 1;

      /* ================= INSERT ================= */

      let inserted;
      try {
        [inserted] = await tx
          .insert(messages)
          .values({
            conversationId: input.conversationId,
            senderUserId: input.senderUserId,
            senderDeviceId: input.senderDeviceId,
            body,
            contentType,
            clientTimestamp: input.clientTimestamp ?? null,
            clientTempId: input.clientTempId ?? null,
            mediaAssetId:
              contentType === 'media'
                ? input.mediaAssetId
                : null,
            seq: nextSeq,
          })
          .returning();
      } catch (err: any) {
        if (input.clientTempId && err?.code === '23505') {
          const existing = await tx
            .select()
            .from(messages)
            .where(
              and(
                eq(messages.conversationId, input.conversationId),
                eq(messages.senderUserId, input.senderUserId),
                eq(messages.senderDeviceId, input.senderDeviceId),
                eq(messages.clientTempId, input.clientTempId),
              ),
            )
            .limit(1);

          if (existing[0]) {
            return { message: existing[0], created: false };
          }
        }

        throw err;
      }

      await tx
        .update(conversations)
        .set({ updatedAt: new Date() })
        .where(eq(conversations.id, input.conversationId));

      return { message: inserted, created: true };
    });

    /* ================= ASYNC FANOUT ================= */

    try {
      await messageQueue.add(
        'deliver-message',
        {
          messageId: result.message.id,
          conversationId: result.message.conversationId,
        },
        {
          jobId: `message:${result.message.id}`,
          attempts: 5,
          backoff: { type: 'exponential', delay: 2000 },
          removeOnComplete: true,
        },
      );
    } catch (err: any) {
      if (!String(err?.message || '').includes('Job already exists')) {
        throw err;
      }
    }

    return result;
  }

  async listMessages(input: {
    conversationId: string;
    beforeSeq?: number;
    limit?: number;
  }) {
    const limit = Math.min(Math.max(input.limit ?? 50, 1), 100);
    const beforeCondition =
      typeof input.beforeSeq === 'number'
        ? sql`AND m.seq < ${input.beforeSeq}`
        : sql``;

    const result = await db.execute(sql`
      SELECT
        m.id AS "id",
        m.conversation_id AS "conversationId",
        m.sender_user_id AS "senderUserId",
        m.sender_device_id AS "senderDeviceId",
        m.seq AS "seq",
        m.content_type AS "contentType",
        m.body AS "body",
        m.client_temp_id AS "clientTempId",
        m.media_asset_id AS "mediaAssetId",
        m.edit_version AS "editVersion",
        m.client_timestamp AS "clientTimestamp",
        m.created_at AS "createdAt",
        m.delivered_at AS "deliveredAt",
        m.read_at AS "readAt",
        m.deleted_for_all_at AS "deletedForAllAt",
        COALESCE(
          json_agg(
            json_build_object(
              'userId', mr.user_id,
              'emoji', mr.emoji,
              'reactedAt', mr.reacted_at,
              'updatedAt', mr.updated_at
            )
          ) FILTER (WHERE mr.message_id IS NOT NULL),
          '[]'::json
        ) AS reactions
      FROM messages m
      LEFT JOIN message_reactions mr ON mr.message_id = m.id
      WHERE m.conversation_id = ${input.conversationId}
      ${beforeCondition}
      GROUP BY m.id
      ORDER BY m.seq DESC
      LIMIT ${limit}
    `);

    return result.rows.reverse();
  }

  async markRead(input: {
    conversationId: string;
    userId: string;
    deviceId: string;
    lastReadSeq: number;
  }) {
    const now = new Date();

    await db.transaction(async (tx) => {
      const existing = await tx
        .select({
          lastReadSeq: syncState.lastReadSeq,
          lastDeliveredSeq: syncState.lastDeliveredSeq,
        })
        .from(syncState)
        .where(
          and(
            eq(syncState.userId, input.userId),
            eq(syncState.deviceId, input.deviceId),
            eq(syncState.conversationId, input.conversationId),
          ),
        )
        .limit(1);

      const prevReadSeq = existing[0]?.lastReadSeq ?? 0;

      await tx
        .update(conversationMembers)
        .set({
          lastReadSeq: sql<number>`
            GREATEST(COALESCE(${conversationMembers.lastReadSeq}, 0), ${input.lastReadSeq})
          `,
        })
        .where(
          and(
            eq(conversationMembers.conversationId, input.conversationId),
            eq(conversationMembers.userId, input.userId),
            isNull(conversationMembers.leftAt),
          ),
        );

      await tx
        .insert(syncState)
        .values({
          userId: input.userId,
          deviceId: input.deviceId,
          conversationId: input.conversationId,
          lastDeliveredSeq: input.lastReadSeq,
          lastReadSeq: input.lastReadSeq,
          lastSyncAt: now,
        })
        .onConflictDoUpdate({
          target: [
            syncState.userId,
            syncState.deviceId,
            syncState.conversationId,
          ],
          set: {
            lastReadSeq: sql<number>`
              GREATEST(COALESCE(${syncState.lastReadSeq}, 0), ${input.lastReadSeq})
            `,
            lastDeliveredSeq: sql<number>`
              GREATEST(COALESCE(${syncState.lastDeliveredSeq}, 0), ${input.lastReadSeq})
            `,
            lastSyncAt: now,
          },
        });

      if (input.lastReadSeq > prevReadSeq) {
        await tx.execute(sql`
          INSERT INTO message_device_states (
            message_id,
            device_id,
            delivered_at,
            read_at
          )
          SELECT
            m.id,
            ${input.deviceId},
            ${now},
            ${now}
          FROM messages m
          WHERE m.conversation_id = ${input.conversationId}
            AND m.seq > ${prevReadSeq}
            AND m.seq <= ${input.lastReadSeq}
          ON CONFLICT (message_id, device_id)
          DO UPDATE SET
            delivered_at = COALESCE(message_device_states.delivered_at, EXCLUDED.delivered_at),
            read_at = COALESCE(message_device_states.read_at, EXCLUDED.read_at)
        `);

        await tx.execute(sql`
          DELETE FROM message_retries mr
          USING messages m
          WHERE mr.message_id = m.id
            AND mr.device_id = ${input.deviceId}
            AND m.conversation_id = ${input.conversationId}
            AND m.seq <= ${input.lastReadSeq}
        `);
      }
    });
  }

  async markDelivered(input: {
    conversationId: string;
    userId: string;
    deviceId: string;
    lastDeliveredSeq: number;
  }) {
    const now = new Date();

    await db.transaction(async (tx) => {
      const existing = await tx
        .select({
          lastDeliveredSeq: syncState.lastDeliveredSeq,
        })
        .from(syncState)
        .where(
          and(
            eq(syncState.userId, input.userId),
            eq(syncState.deviceId, input.deviceId),
            eq(syncState.conversationId, input.conversationId),
          ),
        )
        .limit(1);

      const prevDeliveredSeq = existing[0]?.lastDeliveredSeq ?? 0;

      await tx
        .insert(syncState)
        .values({
          userId: input.userId,
          deviceId: input.deviceId,
          conversationId: input.conversationId,
          lastDeliveredSeq: input.lastDeliveredSeq,
          lastSyncAt: now,
        })
        .onConflictDoUpdate({
          target: [
            syncState.userId,
            syncState.deviceId,
            syncState.conversationId,
          ],
          set: {
            lastDeliveredSeq: sql<number>`
              GREATEST(COALESCE(${syncState.lastDeliveredSeq}, 0), ${input.lastDeliveredSeq})
            `,
            lastSyncAt: now,
          },
        });

      if (input.lastDeliveredSeq > prevDeliveredSeq) {
        await tx.execute(sql`
          INSERT INTO message_device_states (
            message_id,
            device_id,
            delivered_at
          )
          SELECT
            m.id,
            ${input.deviceId},
            ${now}
          FROM messages m
          WHERE m.conversation_id = ${input.conversationId}
            AND m.seq > ${prevDeliveredSeq}
            AND m.seq <= ${input.lastDeliveredSeq}
          ON CONFLICT (message_id, device_id)
          DO UPDATE SET
            delivered_at = COALESCE(message_device_states.delivered_at, EXCLUDED.delivered_at)
        `);

        await tx.execute(sql`
          DELETE FROM message_retries mr
          USING messages m
          WHERE mr.message_id = m.id
            AND mr.device_id = ${input.deviceId}
            AND m.conversation_id = ${input.conversationId}
            AND m.seq <= ${input.lastDeliveredSeq}
        `);
      }
    });
  }

  async getMessage(input: { conversationId: string; messageId: string }) {
    const rows = await db
      .select()
      .from(messages)
      .where(
        and(
          eq(messages.id, input.messageId),
          eq(messages.conversationId, input.conversationId),
        ),
      )
      .limit(1);

    return rows[0] ?? null;
  }

  async listMessageReceipts(input: {
    conversationId: string;
    messageId: string;
  }) {
    const result = await db.execute(sql`
      SELECT DISTINCT ON (mds.device_id)
        mds.device_id AS "deviceId",
        mds.delivered_at AS "deliveredAt",
        mds.read_at AS "readAt",
        ss.user_id AS "userId"
      FROM message_device_states mds
      LEFT JOIN sync_state ss
        ON ss.device_id = mds.device_id
       AND ss.conversation_id = ${input.conversationId}
      WHERE mds.message_id = ${input.messageId}
      ORDER BY mds.device_id, ss.updated_at DESC NULLS LAST
    `);

    return result.rows;
  }

  async editMessage(input: {
    conversationId: string;
    messageId: string;
    userId: string;
    body: string;
  }) {
    const [updated] = await db
      .update(messages)
      .set({
        body: input.body,
        editVersion: sql<number>`${messages.editVersion} + 1`,
      })
      .where(
        and(
          eq(messages.id, input.messageId),
          eq(messages.conversationId, input.conversationId),
          eq(messages.senderUserId, input.userId),
          eq(messages.contentType, 'text'),
          isNull(messages.deletedForAllAt),
        ),
      )
      .returning();

    return updated ?? null;
  }

  async deleteMessageForAll(input: {
    conversationId: string;
    messageId: string;
    userId: string;
  }) {
    const now = new Date();

    const [updated] = await db
      .update(messages)
      .set({
        deletedForAllAt: now,
        body: '',
        contentType: 'system',
      })
      .where(
        and(
          eq(messages.id, input.messageId),
          eq(messages.conversationId, input.conversationId),
          eq(messages.senderUserId, input.userId),
          isNull(messages.deletedForAllAt),
        ),
      )
      .returning();

    return updated ?? null;
  }

  async setReaction(input: {
    conversationId: string;
    messageId: string;
    userId: string;
    emoji: string;
  }) {
    const exists = await db
      .select({ id: messages.id })
      .from(messages)
      .where(
        and(
          eq(messages.id, input.messageId),
          eq(messages.conversationId, input.conversationId),
          isNull(messages.deletedForAllAt),
        ),
      )
      .limit(1);

    if (!exists[0]) {
      return null;
    }

    const now = new Date();
    const [row] = await db
      .insert(messageReactions)
      .values({
        messageId: input.messageId,
        userId: input.userId,
        emoji: input.emoji,
        reactedAt: now,
        updatedAt: now,
      })
      .onConflictDoUpdate({
        target: [
          messageReactions.messageId,
          messageReactions.userId,
        ],
        set: {
          emoji: input.emoji,
          updatedAt: now,
        },
      })
      .returning();

    return row ?? null;
  }

  async removeReaction(input: {
    conversationId: string;
    messageId: string;
    userId: string;
  }) {
    const exists = await db
      .select({ id: messages.id })
      .from(messages)
      .where(
        and(
          eq(messages.id, input.messageId),
          eq(messages.conversationId, input.conversationId),
        ),
      )
      .limit(1);

    if (!exists[0]) {
      return false;
    }

    const rows = await db
      .delete(messageReactions)
      .where(
        and(
          eq(messageReactions.messageId, input.messageId),
          eq(messageReactions.userId, input.userId),
        ),
      )
      .returning();

    return rows.length > 0;
  }
}
