import {
  pgTable,
  uuid,
  timestamp,
  primaryKey,
  index,
} from 'drizzle-orm/pg-core';
import { users } from './users.schema';
import { feedPosts } from './feed_posts.schema';

export const feedLikes = pgTable(
  'feed_likes',
  {
    postId: uuid('post_id')
      .notNull()
      .references(() => feedPosts.id, { onDelete: 'cascade' }),

    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),

    createdAt: timestamp('created_at', {
      withTimezone: true,
    })
      .defaultNow()
      .notNull(),
  },
  (t) => ({
    pk: primaryKey({ columns: [t.postId, t.userId] }),
    userIdx: index('feed_likes_user_idx').on(t.userId),
  }),
);
