import {
  pgTable,
  uuid,
  varchar,
  integer,
  timestamp,
  primaryKey,
} from 'drizzle-orm/pg-core';
import { conversations } from './conversations.schema';
import { users } from './users.schema';

export const syncState = pgTable(
  'sync_state',
  {
    /* ================= IDENTITY ================= */

    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    deviceId: varchar('device_id', { length: 128 }).notNull(),
    conversationId: uuid('conversation_id')
      .notNull()
      .references(() => conversations.id, { onDelete: 'cascade' }),

    /* ================= DELIVERY CURSORS ================= */

    lastDeliveredSeq: integer('last_delivered_seq')
      .notNull()
      .default(0),

    lastReadSeq: integer('last_read_seq')
      .notNull()
      .default(0),

    /* ================= SYNC CONTROL ================= */

    lastSyncAt: timestamp('last_sync_at', {
      withTimezone: true,
    }),

    joinedAt: timestamp('joined_at', {
      withTimezone: true,
    })
      .defaultNow()
      .notNull(),

    /* ================= META ================= */

    updatedAt: timestamp('updated_at', {
      withTimezone: true,
    })
      .defaultNow()
      .notNull(),
  },
  (t) => ({
    pk: primaryKey(
      t.userId,
      t.deviceId,
      t.conversationId,
    ),
  }),
);
