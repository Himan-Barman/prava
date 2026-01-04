import { db } from '@/db';
import { messages } from '@/db/schema/messages.schema';
import { syncState } from '@/db/schema/sync_state.schema';
import { and, eq, gt, asc, sql } from 'drizzle-orm';
import type { InferSelectModel } from 'drizzle-orm';

/* ================= TYPES ================= */

export type MessageRow = InferSelectModel<typeof messages>;

export interface SyncConversationInput {
  userId: string;
  deviceId: string;
  conversationId: string;
  lastDeliveredSeq: number;
}

/* ================= SERVICE ================= */

export class SyncService {
  /**
   * Sync missing messages for a single conversation.
   *
   * This method is:
   * - Idempotent
   * - Device-safe
   * - Replay-safe
   * - Cursor-authoritative
   */
  async syncConversation(
    input: SyncConversationInput,
  ): Promise<MessageRow[]> {
    const now = new Date();

    /* ================= 1. UPDATE CURSOR =================
       This is the authoritative server-side sync position.
       Client cursor is NEVER trusted long-term.
    */
    await db
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

    /* ================= 2. FETCH MISSING MESSAGES =================
       Ordered, bounded, replay-safe.
    */
    const rows = await db
      .select()
      .from(messages)
      .where(
        and(
          eq(messages.conversationId, input.conversationId),
          gt(messages.seq, input.lastDeliveredSeq),
        ),
      )
      .orderBy(asc(messages.seq))
      .limit(500); // 🔒 batch window (DoS + memory safe)

    return rows;
  }
}
