import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { and, desc, eq, isNull, or, sql } from 'drizzle-orm';
import crypto from 'crypto';

import { db } from '@/db';
import { deviceIdentityKeys } from '@/db/schema/device_identity_keys.schema';
import { deviceSignedPreKeys } from '@/db/schema/device_signed_prekeys.schema';
import { devicePreKeys } from '@/db/schema/device_prekeys.schema';
import { deviceTrust } from '@/db/schema/device_trust.schema';

type SignedPreKeyInput = {
  keyId: number;
  publicKey: string;
  signature: string;
  expiresAt?: string;
};

type PreKeyInput = {
  keyId: number;
  publicKey: string;
};

type DbTx = Parameters<Parameters<typeof db.transaction>[0]>[0];

@Injectable()
export class E2eService {
  private async ensureKeyAccess(
    requesterId: string,
    targetUserId: string,
  ) {
    if (requesterId === targetUserId) return;

    const rows = await db.execute(sql`
      SELECT 1
      FROM conversation_members cm1
      JOIN conversation_members cm2
        ON cm1.conversation_id = cm2.conversation_id
      WHERE cm1.user_id = ${requesterId}
        AND cm2.user_id = ${targetUserId}
        AND cm1.left_at IS NULL
        AND cm2.left_at IS NULL
      LIMIT 1
    `);

    if (rows.rows.length === 0) {
      throw new ForbiddenException(
        'No shared conversation with user',
      );
    }
  }

  private parseExpiresAt(value?: string) {
    if (!value) return null;
    const parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) return null;
    return parsed;
  }

  private fingerprint(key: string) {
    return crypto.createHash('sha256').update(key).digest('hex');
  }

  async registerDeviceKeys(input: {
    userId: string;
    deviceId: string;
    platform: 'android' | 'ios' | 'web' | 'desktop';
    deviceName?: string;
    identityKey: string;
    registrationId?: number;
    signedPreKey: SignedPreKeyInput;
    oneTimePreKeys?: PreKeyInput[];
  }) {
    const now = new Date();

    return db.transaction(async (tx) => {
      const existing = await tx
        .select({
          identityKey: deviceIdentityKeys.identityKey,
        })
        .from(deviceIdentityKeys)
        .where(
          and(
            eq(deviceIdentityKeys.userId, input.userId),
            eq(deviceIdentityKeys.deviceId, input.deviceId),
          ),
        )
        .limit(1);

      const identityChanged =
        existing[0] &&
        existing[0].identityKey !== input.identityKey;

      await tx
        .insert(deviceIdentityKeys)
        .values({
          userId: input.userId,
          deviceId: input.deviceId,
          platform: input.platform,
          deviceName: input.deviceName ?? null,
          identityKey: input.identityKey,
          registrationId: input.registrationId ?? null,
          updatedAt: now,
          lastSeenAt: now,
          revokedAt: null,
        })
        .onConflictDoUpdate({
          target: [
            deviceIdentityKeys.userId,
            deviceIdentityKeys.deviceId,
          ],
          set: {
            platform: input.platform,
            deviceName: input.deviceName ?? null,
            identityKey: input.identityKey,
            registrationId: input.registrationId ?? null,
            updatedAt: now,
            lastSeenAt: now,
            revokedAt: null,
          },
        });

      if (identityChanged) {
        await tx
          .update(deviceSignedPreKeys)
          .set({ revokedAt: now })
          .where(
            and(
              eq(deviceSignedPreKeys.userId, input.userId),
              eq(deviceSignedPreKeys.deviceId, input.deviceId),
              isNull(deviceSignedPreKeys.revokedAt),
            ),
          );

        await tx.execute(sql`
          UPDATE device_prekeys
          SET consumed_at = ${now}
          WHERE user_id = ${input.userId}
            AND device_id = ${input.deviceId}
            AND consumed_at IS NULL
        `);

        await tx
          .update(deviceTrust)
          .set({
            status: 'unverified',
            verifiedAt: null,
            updatedAt: now,
          })
          .where(
            and(
              eq(deviceTrust.trustedUserId, input.userId),
              eq(deviceTrust.trustedDeviceId, input.deviceId),
            ),
          );
      }

      await this.upsertSignedPreKey(tx, {
        userId: input.userId,
        deviceId: input.deviceId,
        signedPreKey: input.signedPreKey,
        now,
      });

      const preKeys = input.oneTimePreKeys ?? [];
      if (preKeys.length > 0) {
        await tx
          .insert(devicePreKeys)
          .values(
            preKeys.map((key) => ({
              userId: input.userId,
              deviceId: input.deviceId,
              keyId: key.keyId,
              publicKey: key.publicKey,
            })),
          )
          .onConflictDoNothing();
      }

      return { registered: true, preKeysAdded: preKeys.length };
    });
  }

  async uploadPreKeys(input: {
    userId: string;
    deviceId: string;
    preKeys: PreKeyInput[];
  }) {
    const device = await db.query.deviceIdentityKeys.findFirst(
      {
        where: and(
          eq(deviceIdentityKeys.userId, input.userId),
          eq(deviceIdentityKeys.deviceId, input.deviceId),
          isNull(deviceIdentityKeys.revokedAt),
        ),
      },
    );

    if (!device) {
      throw new NotFoundException('Device not registered');
    }

    if (input.preKeys.length === 0) {
      throw new BadRequestException('No prekeys supplied');
    }

    await db
      .insert(devicePreKeys)
      .values(
        input.preKeys.map((key) => ({
          userId: input.userId,
          deviceId: input.deviceId,
          keyId: key.keyId,
          publicKey: key.publicKey,
        })),
      )
      .onConflictDoNothing();

    return { added: input.preKeys.length };
  }

  async rotateSignedPreKey(input: {
    userId: string;
    deviceId: string;
    signedPreKey: SignedPreKeyInput;
  }) {
    const device = await db.query.deviceIdentityKeys.findFirst(
      {
        where: and(
          eq(deviceIdentityKeys.userId, input.userId),
          eq(deviceIdentityKeys.deviceId, input.deviceId),
          isNull(deviceIdentityKeys.revokedAt),
        ),
      },
    );

    if (!device) {
      throw new NotFoundException('Device not registered');
    }

    await db.transaction(async (tx) => {
      await this.upsertSignedPreKey(tx, {
        userId: input.userId,
        deviceId: input.deviceId,
        signedPreKey: input.signedPreKey,
        now: new Date(),
      });
    });

    return { rotated: true };
  }

  async listDevicesForUser(input: {
    requesterId: string;
    targetUserId: string;
  }) {
    await this.ensureKeyAccess(
      input.requesterId,
      input.targetUserId,
    );

    const rows = await db.execute(sql`
      SELECT
        dik.device_id AS "deviceId",
        dik.platform AS "platform",
        dik.device_name AS "deviceName",
        dik.identity_key AS "identityKey",
        dik.registration_id AS "registrationId",
        dik.last_seen_at AS "lastSeenAt",
        dik.revoked_at AS "revokedAt",
        dt.status AS "trustStatus",
        dt.verified_at AS "verifiedAt"
      FROM device_identity_keys dik
      LEFT JOIN device_trust dt
        ON dt.trusting_user_id = ${input.requesterId}
       AND dt.trusted_user_id = dik.user_id
       AND dt.trusted_device_id = dik.device_id
      WHERE dik.user_id = ${input.targetUserId}
        AND dik.revoked_at IS NULL
      ORDER BY dik.created_at ASC
    `);

    return rows.rows.map((row) => ({
      ...row,
      identityFingerprint: row.identityKey
        ? this.fingerprint(row.identityKey as string)
        : null,
    }));
  }

  async getPreKeyBundle(input: {
    requesterId: string;
    targetUserId: string;
    targetDeviceId: string;
  }) {
    await this.ensureKeyAccess(
      input.requesterId,
      input.targetUserId,
    );

    return db.transaction(async (tx) => {
      const device = await tx
        .select()
        .from(deviceIdentityKeys)
        .where(
          and(
            eq(deviceIdentityKeys.userId, input.targetUserId),
            eq(deviceIdentityKeys.deviceId, input.targetDeviceId),
            isNull(deviceIdentityKeys.revokedAt),
          ),
        )
        .limit(1);

      if (!device[0]) {
        throw new NotFoundException('Device not found');
      }

      const now = new Date();
      const signedPreKey = await tx
        .select()
        .from(deviceSignedPreKeys)
        .where(
          and(
            eq(deviceSignedPreKeys.userId, input.targetUserId),
            eq(deviceSignedPreKeys.deviceId, input.targetDeviceId),
            isNull(deviceSignedPreKeys.revokedAt),
            or(
              isNull(deviceSignedPreKeys.expiresAt),
              sql`${deviceSignedPreKeys.expiresAt} > ${now}`,
            ),
          ),
        )
        .orderBy(desc(deviceSignedPreKeys.createdAt))
        .limit(1);

      if (!signedPreKey[0]) {
        throw new NotFoundException('Signed prekey missing');
      }

      const preKeyResult = await tx.execute<{
        key_id: number;
        public_key: string;
      }>(sql`
        SELECT key_id, public_key
        FROM device_prekeys
        WHERE user_id = ${input.targetUserId}
          AND device_id = ${input.targetDeviceId}
          AND consumed_at IS NULL
        ORDER BY created_at ASC
        FOR UPDATE SKIP LOCKED
        LIMIT 1
      `);

      const oneTimePreKey = preKeyResult.rows[0]
        ? {
            keyId: preKeyResult.rows[0].key_id,
            publicKey: preKeyResult.rows[0].public_key,
          }
        : null;

      if (oneTimePreKey) {
        await tx.execute(sql`
          UPDATE device_prekeys
          SET consumed_at = ${now}
          WHERE user_id = ${input.targetUserId}
            AND device_id = ${input.targetDeviceId}
            AND key_id = ${oneTimePreKey.keyId}
        `);
      }

      return {
        deviceId: device[0].deviceId,
        identityKey: device[0].identityKey,
        identityFingerprint: this.fingerprint(device[0].identityKey),
        registrationId: device[0].registrationId,
        signedPreKey: {
          keyId: signedPreKey[0].keyId,
          publicKey: signedPreKey[0].publicKey,
          signature: signedPreKey[0].signature,
        },
        oneTimePreKey,
      };
    });
  }

  async setTrust(input: {
    requesterId: string;
    targetUserId: string;
    targetDeviceId: string;
    status: 'trusted' | 'unverified' | 'blocked';
  }) {
    await this.ensureKeyAccess(
      input.requesterId,
      input.targetUserId,
    );

    const device = await db.query.deviceIdentityKeys.findFirst(
      {
        where: and(
          eq(deviceIdentityKeys.userId, input.targetUserId),
          eq(deviceIdentityKeys.deviceId, input.targetDeviceId),
          isNull(deviceIdentityKeys.revokedAt),
        ),
      },
    );

    if (!device) {
      throw new NotFoundException('Device not found');
    }

    const now = new Date();
    const verifiedAt = input.status === 'trusted' ? now : null;

    await db
      .insert(deviceTrust)
      .values({
        trustingUserId: input.requesterId,
        trustedUserId: input.targetUserId,
        trustedDeviceId: input.targetDeviceId,
        status: input.status,
        verifiedAt,
        updatedAt: now,
      })
      .onConflictDoUpdate({
        target: [
          deviceTrust.trustingUserId,
          deviceTrust.trustedUserId,
          deviceTrust.trustedDeviceId,
        ],
        set: {
          status: input.status,
          verifiedAt,
          updatedAt: now,
        },
      });

    return { trusted: input.status };
  }

  async listTrustForUser(input: {
    requesterId: string;
    targetUserId: string;
  }) {
    await this.ensureKeyAccess(
      input.requesterId,
      input.targetUserId,
    );

    const rows = await db.execute(sql`
      SELECT
        dik.device_id AS "deviceId",
        dt.status AS "status",
        dt.verified_at AS "verifiedAt"
      FROM device_identity_keys dik
      LEFT JOIN device_trust dt
        ON dt.trusting_user_id = ${input.requesterId}
       AND dt.trusted_user_id = dik.user_id
       AND dt.trusted_device_id = dik.device_id
      WHERE dik.user_id = ${input.targetUserId}
        AND dik.revoked_at IS NULL
      ORDER BY dik.created_at ASC
    `);

    return rows.rows;
  }

  private async upsertSignedPreKey(
    tx: DbTx,
    input: {
      userId: string;
      deviceId: string;
      signedPreKey: SignedPreKeyInput;
      now: Date;
    },
  ) {
    const expiresAt = this.parseExpiresAt(
      input.signedPreKey.expiresAt,
    );

    await tx
      .update(deviceSignedPreKeys)
      .set({ revokedAt: input.now })
      .where(
        and(
          eq(deviceSignedPreKeys.userId, input.userId),
          eq(deviceSignedPreKeys.deviceId, input.deviceId),
          isNull(deviceSignedPreKeys.revokedAt),
        ),
      );

    await tx
      .insert(deviceSignedPreKeys)
      .values({
        userId: input.userId,
        deviceId: input.deviceId,
        keyId: input.signedPreKey.keyId,
        publicKey: input.signedPreKey.publicKey,
        signature: input.signedPreKey.signature,
        expiresAt,
      })
      .onConflictDoUpdate({
        target: [
          deviceSignedPreKeys.userId,
          deviceSignedPreKeys.deviceId,
          deviceSignedPreKeys.keyId,
        ],
        set: {
          publicKey: input.signedPreKey.publicKey,
          signature: input.signedPreKey.signature,
          expiresAt,
          revokedAt: null,
        },
      });
  }
}
