import {
  pgTable,
  uuid,
  varchar,
  timestamp,
} from 'drizzle-orm/pg-core';
import { users } from './users.schema';

export const conversations = pgTable('conversations', {
  id: uuid('id').defaultRandom().primaryKey(),

  type: varchar('type', { length: 16 })
    .$type<'dm' | 'group'>()
    .notNull(),

  title: varchar('title', { length: 140 }),

  createdByUserId: uuid('created_by_user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),

  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
});
