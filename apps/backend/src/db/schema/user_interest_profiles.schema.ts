import {
  pgTable,
  uuid,
  text,
  timestamp,
  index,
  uniqueIndex,
  doublePrecision,
} from 'drizzle-orm/pg-core';
import { users } from './users.schema';

export const userInterestProfiles = pgTable(
  'user_interest_profiles',
  {
    id: uuid('id').defaultRandom().primaryKey(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    tag: text('tag').notNull(),
    score: doublePrecision('score').notNull().default(0),
    createdAt: timestamp('created_at', { withTimezone: true })
      .defaultNow()
      .notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (t) => ({
    userIdx: index('user_interest_profiles_user_idx').on(t.userId),
    tagIdx: index('user_interest_profiles_tag_idx').on(t.tag),
    userTagIdx: uniqueIndex('user_interest_profiles_user_tag_unique').on(
      t.userId,
      t.tag,
    ),
  }),
);
