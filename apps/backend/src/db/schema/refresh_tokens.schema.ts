import {
  pgTable,
  uuid,
  varchar,
  timestamp,
  index,
} from 'drizzle-orm/pg-core';
import { users } from './users.schema';

export const refreshTokens = pgTable(
  'refresh_tokens',
  {
    id: uuid('id').defaultRandom().primaryKey(),

    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),

    deviceId: varchar('device_id', { length: 255 }).notNull(),

    tokenHash: varchar('token_hash', { length: 64 }).notNull(),

    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),

    revokedAt: timestamp('revoked_at', { withTimezone: true }),

    createdAt: timestamp('created_at', { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => ({
    tokenLookup: index('refresh_token_lookup').on(
      t.tokenHash,
      t.deviceId
    ),
    userIndex: index('refresh_user_idx').on(t.userId),
  })
);
