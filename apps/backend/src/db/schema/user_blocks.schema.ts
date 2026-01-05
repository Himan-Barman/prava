import {
  pgTable,
  uuid,
  timestamp,
  index,
  uniqueIndex,
} from 'drizzle-orm/pg-core';
import { users } from './users.schema';

export const userBlocks = pgTable(
  'user_blocks',
  {
    id: uuid('id').defaultRandom().primaryKey(),

    blockerId: uuid('blocker_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),

    blockedId: uuid('blocked_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),

    createdAt: timestamp('created_at', { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => ({
    unique: uniqueIndex('user_blocks_unique').on(
      t.blockerId,
      t.blockedId,
    ),
    blockerIdx: index('user_blocks_blocker_idx').on(t.blockerId),
    blockedIdx: index('user_blocks_blocked_idx').on(t.blockedId),
  }),
);
