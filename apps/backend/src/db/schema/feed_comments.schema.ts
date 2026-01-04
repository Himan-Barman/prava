import {
  pgTable,
  uuid,
  text,
  timestamp,
  index,
} from 'drizzle-orm/pg-core';
import { users } from './users.schema';
import { feedPosts } from './feed_posts.schema';

export const feedComments = pgTable(
  'feed_comments',
  {
    id: uuid('id').defaultRandom().primaryKey(),

    postId: uuid('post_id')
      .notNull()
      .references(() => feedPosts.id, { onDelete: 'cascade' }),

    authorId: uuid('author_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),

    body: text('body').notNull(),

    createdAt: timestamp('created_at', {
      withTimezone: true,
    })
      .defaultNow()
      .notNull(),
  },
  (t) => ({
    postIdx: index('feed_comments_post_idx').on(t.postId),
    authorIdx: index('feed_comments_author_idx').on(t.authorId),
  }),
);
