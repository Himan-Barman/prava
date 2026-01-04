import {
  pgTable,
  uuid,
  varchar,
  integer,
  timestamp,
  primaryKey,
} from 'drizzle-orm/pg-core';
import { messages } from './messages.schema';

export const messageCrypto = pgTable(
  'message_crypto',
  {
    /* ================= IDENTITY ================= */

    messageId: uuid('message_id')
      .notNull()
      .references(() => messages.id, { onDelete: 'cascade' }),
    deviceId: varchar('device_id', { length: 128 }).notNull(),

    /* ================= ENCRYPTION ================= */

    algorithm: varchar('algorithm', { length: 32 })
      .$type<'signal' | 'double-ratchet'>()
      .notNull(),

    keyVersion: integer('key_version').notNull(),

    senderRatchetKey: varchar('sender_ratchet_key', {
      length: 512,
    }).notNull(),

    wrappedMessageKey: varchar('wrapped_message_key', {
      length: 1024,
    }).notNull(),

    /* ================= STATE ================= */

    encryptedAt: timestamp('encrypted_at', {
      withTimezone: true,
    })
      .defaultNow()
      .notNull(),
  },
  (t) => ({
    pk: primaryKey(t.messageId, t.deviceId),
  }),
);
