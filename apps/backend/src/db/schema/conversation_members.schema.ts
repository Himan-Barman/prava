import {
  pgTable,
  uuid,
  varchar,
  timestamp,
  integer,
  primaryKey,
} from 'drizzle-orm/pg-core';
import { conversations } from './conversations.schema';
import { users } from './users.schema';

export const conversationMembers = pgTable(
  'conversation_members',
  {
    /* ================= IDENTITY ================= */

    conversationId: uuid('conversation_id')
      .notNull()
      .references(() => conversations.id, { onDelete: 'cascade' }),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),

    /* ================= ROLE ================= */

    role: varchar('role', { length: 16 })
      .$type<'member' | 'admin'>()
      .notNull(),

    /* ================= LIFECYCLE ================= */

    joinedAt: timestamp('joined_at', {
      withTimezone: true,
    })
      .defaultNow()
      .notNull(),

    leftAt: timestamp('left_at', {
      withTimezone: true,
    }),

    /* ================= READ STATE ================= */

    lastReadSeq: integer('last_read_seq'),
  },
  (t) => ({
    pk: primaryKey(t.conversationId, t.userId),
  }),
);
