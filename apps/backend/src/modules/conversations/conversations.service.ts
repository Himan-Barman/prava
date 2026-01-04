import { Injectable } from '@nestjs/common';

import { db } from '@/db';
import { conversations } from '@/db/schema/conversations.schema';
import { conversationMembers } from '@/db/schema/conversation_members.schema';
import { and, eq, isNull, sql } from 'drizzle-orm';

@Injectable()
export class ConversationsService {
  async getMembership(input: {
    conversationId: string;
    userId: string;
  }) {
    const rows = await db
      .select()
      .from(conversationMembers)
      .where(
        and(
          eq(conversationMembers.conversationId, input.conversationId),
          eq(conversationMembers.userId, input.userId),
          isNull(conversationMembers.leftAt),
        ),
      )
      .limit(1);

    return rows[0] ?? null;
  }

  async listConversationIdsForUser(userId: string) {
    const rows = await db
      .select({ conversationId: conversationMembers.conversationId })
      .from(conversationMembers)
      .where(
        and(
          eq(conversationMembers.userId, userId),
          isNull(conversationMembers.leftAt),
        ),
      );

    return rows.map((row) => row.conversationId);
  }

  async listForUser(userId: string) {
    const result = await db.execute(sql`
      SELECT
        c.id,
        c.type,
        c.title,
        c.created_at AS "createdAt",
        c.updated_at AS "updatedAt",
        cm.role,
        cm.last_read_seq AS "lastReadSeq",
        GREATEST(COALESCE(lm.seq, 0) - COALESCE(cm.last_read_seq, 0), 0) AS "unreadCount",
        lm.id AS "lastMessageId",
        lm.seq AS "lastMessageSeq",
        lm.sender_user_id AS "lastMessageSenderUserId",
        lm.body AS "lastMessageBody",
        lm.content_type AS "lastMessageContentType",
        lm.edit_version AS "lastMessageEditVersion",
        lm.deleted_for_all_at AS "lastMessageDeletedForAllAt",
        lm.created_at AS "lastMessageCreatedAt"
      FROM conversation_members cm
      JOIN conversations c
        ON c.id = cm.conversation_id
      LEFT JOIN LATERAL (
        SELECT m.id, m.seq, m.sender_user_id, m.body, m.content_type,
          m.edit_version, m.deleted_for_all_at, m.created_at
        FROM messages m
        WHERE m.conversation_id = c.id
        ORDER BY m.seq DESC
        LIMIT 1
      ) lm ON TRUE
      WHERE cm.user_id = ${userId}
        AND cm.left_at IS NULL
      ORDER BY c.updated_at DESC
    `);

    return result.rows;
  }

  async createDm(input: { userId: string; otherUserId: string }) {
    if (input.userId === input.otherUserId) {
      throw new Error('Cannot create DM with self');
    }

    const existing = await db.execute(sql`
      SELECT c.id
      FROM conversations c
      JOIN conversation_members cm1
        ON cm1.conversation_id = c.id
      JOIN conversation_members cm2
        ON cm2.conversation_id = c.id
      WHERE c.type = 'dm'
        AND cm1.user_id = ${input.userId}
        AND cm2.user_id = ${input.otherUserId}
        AND cm1.left_at IS NULL
        AND cm2.left_at IS NULL
      LIMIT 1
    `);

    const existingId = (existing.rows[0] as { id?: string } | undefined)?.id;
    if (existingId) {
      return { conversationId: existingId, created: false };
    }

    return db.transaction(async (tx) => {
      const [conversation] = await tx
        .insert(conversations)
        .values({
          type: 'dm',
          createdByUserId: input.userId,
        })
        .returning({ id: conversations.id });

      await tx.insert(conversationMembers).values([
        {
          conversationId: conversation.id,
          userId: input.userId,
          role: 'member',
        },
        {
          conversationId: conversation.id,
          userId: input.otherUserId,
          role: 'member',
        },
      ]);

      return { conversationId: conversation.id, created: true };
    });
  }

  async createGroup(input: {
    userId: string;
    title: string;
    memberIds: string[];
  }) {
    const title = input.title.trim();
    if (!title) {
      throw new Error('Invalid group title');
    }

    const uniqueMembers = Array.from(
      new Set([input.userId, ...input.memberIds]),
    );

    return db.transaction(async (tx) => {
      const [conversation] = await tx
        .insert(conversations)
        .values({
          type: 'group',
          title,
          createdByUserId: input.userId,
        })
        .returning({ id: conversations.id });

      const memberRows = uniqueMembers.map((memberId) => ({
        conversationId: conversation.id,
        userId: memberId,
        role: memberId === input.userId ? 'admin' : 'member',
      }));

      await tx.insert(conversationMembers).values(memberRows);

      return { conversationId: conversation.id };
    });
  }

  async addMembers(input: {
    conversationId: string;
    requesterId: string;
    memberIds: string[];
  }) {
    const membership = await this.getMembership({
      conversationId: input.conversationId,
      userId: input.requesterId,
    });

    if (!membership) {
      throw new Error('Not a member of conversation');
    }

    const convo = await db
      .select({
        type: conversations.type,
      })
      .from(conversations)
      .where(eq(conversations.id, input.conversationId))
      .limit(1);

    if (convo[0]?.type === 'dm') {
      throw new Error('Cannot add members to a DM');
    }

    if (membership.role !== 'admin') {
      throw new Error('Only admins can add members');
    }

    const uniqueMembers = Array.from(new Set(input.memberIds));
    if (uniqueMembers.length === 0) return { added: 0 };

    await db
      .insert(conversationMembers)
      .values(
        uniqueMembers.map((memberId) => ({
          conversationId: input.conversationId,
          userId: memberId,
          role: 'member',
        })),
      )
      .onConflictDoNothing();

    return { added: uniqueMembers.length };
  }

  async listMembers(conversationId: string) {
    return db
      .select({
        userId: conversationMembers.userId,
        role: conversationMembers.role,
        joinedAt: conversationMembers.joinedAt,
        leftAt: conversationMembers.leftAt,
      })
      .from(conversationMembers)
      .where(eq(conversationMembers.conversationId, conversationId));
  }

  async leaveConversation(input: { conversationId: string; userId: string }) {
    await db
      .update(conversationMembers)
      .set({ leftAt: new Date() })
      .where(
        and(
          eq(conversationMembers.conversationId, input.conversationId),
          eq(conversationMembers.userId, input.userId),
          isNull(conversationMembers.leftAt),
        ),
      );
  }
}
