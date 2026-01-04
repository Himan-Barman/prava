import {
  pgTable,
  uuid,
  varchar,
  integer,
  timestamp,
  index,
} from 'drizzle-orm/pg-core';

export const emailOtpTokens = pgTable(
  'email_otp_tokens',
  {
    id: uuid('id').defaultRandom().primaryKey(),

    email: varchar('email', { length: 255 }).notNull(),

    tokenHash: varchar('token_hash', { length: 64 }).notNull(),

    attempts: integer('attempts').notNull().default(0),

    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),

    usedAt: timestamp('used_at', { withTimezone: true }),

    createdAt: timestamp('created_at', { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => ({
    emailIdx: index('email_otp_email_idx').on(t.email),
    tokenIdx: index('email_otp_token_idx').on(t.tokenHash),
  })
);
