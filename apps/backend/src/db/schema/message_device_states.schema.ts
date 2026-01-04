import {
  pgTable,
  uuid,
  varchar,
  timestamp,
  primaryKey,
} from 'drizzle-orm/pg-core';
import { messages } from './messages.schema';

export const messageDeviceStates = pgTable(
  'message_device_states',
  {
    /* ================= IDENTITY ================= */

    messageId: uuid('message_id')
      .notNull()
      .references(() => messages.id, { onDelete: 'cascade' }),
    deviceId: varchar('device_id', { length: 128 }).notNull(),

    /* ================= DELIVERY STATE ================= */

    deliveredAt: timestamp('delivered_at', {
      withTimezone: true,
    }),

    readAt: timestamp('read_at', {
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
