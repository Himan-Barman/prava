import {
  pgTable,
  uuid,
  varchar,
  timestamp,
  primaryKey,
} from 'drizzle-orm/pg-core';
import { messages } from './messages.schema';
import { users } from './users.schema';

export const messageReactions = pgTable(
  'message_reactions',
  {
    /* ================= IDENTITY ================= */

    messageId: uuid('message_id')
      .notNull()
      .references(() => messages.id, { onDelete: 'cascade' }),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),

    /* ================= REACTION ================= */

    emoji: varchar('emoji', { length: 16 }).notNull(),

    /* ================= META ================= */

    reactedAt: timestamp('reacted_at', {
      withTimezone: true,
    })
      .defaultNow()
      .notNull(),

    updatedAt: timestamp('updated_at', {
      withTimezone: true,
    })
      .defaultNow()
      .notNull(),
  },
  (t) => ({
    pk: primaryKey(t.messageId, t.userId),
  }),
);
