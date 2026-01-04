import {
  pgTable,
  uuid,
  varchar,
  text,
  timestamp,
} from 'drizzle-orm/pg-core';
import { users } from './users.schema';

export const devices = pgTable('devices', {
  /* ================= IDENTITY ================= */

  id: uuid('id').defaultRandom().primaryKey(),

  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),

  /* ================= DEVICE META ================= */

  platform: varchar('platform', { length: 16 })
    .$type<'android' | 'ios' | 'web' | 'desktop'>()
    .notNull(),

  deviceName: varchar('device_name', { length: 64 }),

  /* ================= CRYPTO ================= */

  publicKey: text('public_key').notNull(),

  /* ================= LIFECYCLE ================= */

  createdAt: timestamp('created_at', {
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
});
