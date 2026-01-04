import {
  pgTable,
  uuid,
  varchar,
  text,
  timestamp,
  integer,
  primaryKey,
  index,
} from 'drizzle-orm/pg-core';
import { users } from './users.schema';

export const deviceIdentityKeys = pgTable(
  'device_identity_keys',
  {
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),

    deviceId: varchar('device_id', { length: 128 }).notNull(),

    platform: varchar('platform', { length: 16 })
      .$type<'android' | 'ios' | 'web' | 'desktop'>()
      .notNull(),

    deviceName: varchar('device_name', { length: 64 }),

    identityKey: text('identity_key').notNull(),

    registrationId: integer('registration_id'),

    createdAt: timestamp('created_at', {
      withTimezone: true,
    })
      .defaultNow()
      .notNull(),

    updatedAt: timestamp('updated_at', {
      withTimezone: true,
    })
      .defaultNow()
      .notNull(),

    lastSeenAt: timestamp('last_seen_at', {
      withTimezone: true,
    }),

    revokedAt: timestamp('revoked_at', {
      withTimezone: true,
    }),
  },
  (t) => ({
    pk: primaryKey({
      columns: [t.userId, t.deviceId],
    }),
    userIdx: index('device_identity_user_idx').on(t.userId),
    deviceIdx: index('device_identity_device_idx').on(t.deviceId),
  }),
);
