import {
  pgTable,
  uuid,
  varchar,
  text,
  integer,
  timestamp,
  primaryKey,
  index,
} from 'drizzle-orm/pg-core';
import { users } from './users.schema';

export const deviceSignedPreKeys = pgTable(
  'device_signed_prekeys',
  {
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),

    deviceId: varchar('device_id', { length: 128 }).notNull(),

    keyId: integer('key_id').notNull(),

    publicKey: text('public_key').notNull(),

    signature: text('signature').notNull(),

    createdAt: timestamp('created_at', {
      withTimezone: true,
    })
      .defaultNow()
      .notNull(),

    expiresAt: timestamp('expires_at', {
      withTimezone: true,
    }),

    revokedAt: timestamp('revoked_at', {
      withTimezone: true,
    }),
  },
  (t) => ({
    pk: primaryKey({
      columns: [t.userId, t.deviceId, t.keyId],
    }),
    userDeviceIdx: index(
      'device_signed_prekeys_user_device_idx',
    ).on(t.userId, t.deviceId),
  }),
);
