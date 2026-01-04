import {
  pgTable,
  uuid,
  varchar,
  text,
  timestamp,
  index,
  jsonb,
} from 'drizzle-orm/pg-core';

export const notifications = pgTable(
  'notifications',
  {
    id: uuid('id').defaultRandom().primaryKey(),

    userId: uuid('user_id').notNull(),

    actorId: uuid('actor_id'),

    type: varchar('type', { length: 32 }).notNull(),

    title: varchar('title', { length: 120 }).notNull(),

    body: text('body').notNull(),

    data: jsonb('data').$type<Record<string, unknown>>(),

    readAt: timestamp('read_at', { withTimezone: true }),

    createdAt: timestamp('created_at', { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => ({
    userIdx: index('notifications_user_idx').on(t.userId),
    readIdx: index('notifications_read_idx').on(t.userId, t.readAt),
    createdIdx: index('notifications_created_idx').on(
      t.userId,
      t.createdAt,
    ),
  }),
);
