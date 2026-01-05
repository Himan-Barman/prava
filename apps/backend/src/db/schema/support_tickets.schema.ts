import {
  pgTable,
  uuid,
  varchar,
  text,
  jsonb,
  timestamp,
  index,
} from 'drizzle-orm/pg-core';
import { users } from './users.schema';

export const supportTickets = pgTable(
  'support_tickets',
  {
    id: uuid('id').defaultRandom().primaryKey(),

    userId: uuid('user_id').references(() => users.id, {
      onDelete: 'set null',
    }),

    type: varchar('type', { length: 16 }).notNull(),

    category: varchar('category', { length: 32 }),

    message: text('message').notNull(),

    metadata: jsonb('metadata').notNull().default({}),

    createdAt: timestamp('created_at', { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => ({
    userIdx: index('support_tickets_user_idx').on(t.userId),
    typeIdx: index('support_tickets_type_idx').on(t.type),
  }),
);
