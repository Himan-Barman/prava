import {
  pgTable,
  uuid,
  varchar,
  timestamp,
  index,
  uniqueIndex,
} from 'drizzle-orm/pg-core';
import { users } from './users.schema';

export const userMutedWords = pgTable(
  'user_muted_words',
  {
    id: uuid('id').defaultRandom().primaryKey(),

    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),

    phrase: varchar('phrase', { length: 120 }).notNull(),

    createdAt: timestamp('created_at', { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => ({
    unique: uniqueIndex('user_muted_words_unique').on(
      t.userId,
      t.phrase,
    ),
    userIdx: index('user_muted_words_user_idx').on(t.userId),
  }),
);
