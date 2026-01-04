import {
  pgTable,
  uuid,
  varchar,
  integer,
  timestamp,
  primaryKey,
} from 'drizzle-orm/pg-core';
import { messages } from './messages.schema';

export const messageRetries = pgTable(
  'message_retries',
  {
    /* ================= IDENTITY ================= */

    messageId: uuid('message_id')
      .notNull()
      .references(() => messages.id, { onDelete: 'cascade' }),
    deviceId: varchar('device_id', { length: 128 }).notNull(),

    /* ================= RETRY STATE ================= */

    attempt: integer('attempt')
      .notNull()
      .default(0),

    lastAttemptAt: timestamp('last_attempt_at', {
      withTimezone: true,
    }),

    nextAttemptAt: timestamp('next_attempt_at', {
      withTimezone: true,
    }),

    /* ================= META ================= */

    createdAt: timestamp('created_at', {
      withTimezone: true,
    })
      .defaultNow()
      .notNull(),
  },
  (t) => ({
    pk: primaryKey(t.messageId, t.deviceId),
  }),
);
