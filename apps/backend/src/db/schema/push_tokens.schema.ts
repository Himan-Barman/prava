import {
  pgTable,
  uuid,
  varchar,
  timestamp,
  uniqueIndex,
  index,
} from 'drizzle-orm/pg-core';
import { users } from './users.schema';

export const pushTokens = pgTable(
  'push_tokens',
  {
    id: uuid('id').defaultRandom().primaryKey(),

    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),

    deviceId: varchar('device_id', { length: 128 }).notNull(),

    platform: varchar('platform', { length: 16 })
      .$type<'android' | 'ios' | 'web' | 'desktop'>()
      .notNull(),

    token: varchar('token', { length: 512 }).notNull(),

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

    revokedAt: timestamp('revoked_at', {
      withTimezone: true,
    }),
  },
  (t) => ({
    deviceUnique: uniqueIndex('push_tokens_device_unique').on(
      t.userId,
      t.deviceId,
    ),
    tokenUnique: uniqueIndex('push_tokens_token_unique').on(
      t.token,
    ),
    userIdx: index('push_tokens_user_idx').on(t.userId),
  }),
);
