import { Injectable } from '@nestjs/common';
import { and, eq, isNull, ne } from 'drizzle-orm';

import { db } from '@/db';
import { pushTokens } from '@/db/schema/push_tokens.schema';

@Injectable()
export class DevicesService {
  async registerPushToken(input: {
    userId: string;
    deviceId: string;
    platform: 'android' | 'ios' | 'web' | 'desktop';
    token: string;
  }) {
    const now = new Date();

    return db.transaction(async (tx) => {
      const existingByToken = await tx
        .select()
        .from(pushTokens)
        .where(eq(pushTokens.token, input.token))
        .limit(1);

      if (existingByToken[0]) {
        const existing = existingByToken[0];

        await tx
          .delete(pushTokens)
          .where(
            and(
              eq(pushTokens.userId, input.userId),
              eq(pushTokens.deviceId, input.deviceId),
              ne(pushTokens.id, existing.id),
            ),
          );

        const [updated] = await tx
          .update(pushTokens)
          .set({
            userId: input.userId,
            deviceId: input.deviceId,
            platform: input.platform,
            updatedAt: now,
            revokedAt: null,
          })
          .where(eq(pushTokens.id, existing.id))
          .returning();

        return updated;
      }

      const [row] = await tx
        .insert(pushTokens)
        .values({
          userId: input.userId,
          deviceId: input.deviceId,
          platform: input.platform,
          token: input.token,
          updatedAt: now,
          revokedAt: null,
        })
        .onConflictDoUpdate({
          target: [pushTokens.userId, pushTokens.deviceId],
          set: {
            token: input.token,
            platform: input.platform,
            updatedAt: now,
            revokedAt: null,
          },
        })
        .returning();

      return row;
    });
  }

  async revokePushToken(input: {
    userId: string;
    deviceId: string;
  }) {
    const now = new Date();

    await db
      .update(pushTokens)
      .set({ revokedAt: now, updatedAt: now })
      .where(
        and(
          eq(pushTokens.userId, input.userId),
          eq(pushTokens.deviceId, input.deviceId),
          isNull(pushTokens.revokedAt),
        ),
      );

    return { success: true };
  }
}
