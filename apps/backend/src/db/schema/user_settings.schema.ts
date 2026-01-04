import { pgTable, uuid, jsonb, timestamp, index } from 'drizzle-orm/pg-core';
import { users } from './users.schema';

export const userSettings = pgTable(
  'user_settings',
  {
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' })
      .primaryKey(),
    settings: jsonb('settings').notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => ({
    updatedIdx: index('user_settings_updated_idx').on(t.updatedAt),
  }),
);
