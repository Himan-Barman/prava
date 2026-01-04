import {
  pgTable,
  uuid,
  text,
  timestamp,
  integer,
  jsonb,
  index,
} from 'drizzle-orm/pg-core';
import { users } from './users.schema';

export const feedPosts = pgTable(
  'feed_posts',
  {
    id: uuid('id').defaultRandom().primaryKey(),

    authorId: uuid('author_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),

    body: text('body').notNull(),

    likeCount: integer('like_count').notNull().default(0),
    commentCount: integer('comment_count').notNull().default(0),
    shareCount: integer('share_count').notNull().default(0),

    metadata: jsonb('metadata'),

    createdAt: timestamp('created_at', {
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
    createdIdx: index('feed_posts_created_idx').on(t.createdAt),
    authorIdx: index('feed_posts_author_idx').on(t.authorId),
  }),
);
