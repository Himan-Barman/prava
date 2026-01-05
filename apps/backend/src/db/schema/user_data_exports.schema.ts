import {
  pgTable,
  uuid,
  varchar,
  jsonb,
  timestamp,
  index,
} from 'drizzle-orm/pg-core';
import { users } from './users.schema';

export const userDataExports = pgTable(
  'user_data_exports',
  {
    id: uuid('id').defaultRandom().primaryKey(),

    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),

    status: varchar('status', { length: 16 })
      .notNull()
      .default('ready'),

    format: varchar('format', { length: 16 })
      .notNull()
      .default('json'),

    payload: jsonb('payload').notNull().default({}),

    createdAt: timestamp('created_at', { withTimezone: true })
      .notNull()
      .defaultNow(),

    completedAt: timestamp('completed_at', { withTimezone: true }),
  },
  (t) => ({
    userIdx: index('user_data_exports_user_idx').on(
      t.userId,
      t.createdAt,
    ),
  }),
);
