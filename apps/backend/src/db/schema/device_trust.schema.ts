import {
  pgTable,
  uuid,
  varchar,
  timestamp,
  primaryKey,
  index,
} from 'drizzle-orm/pg-core';
import { users } from './users.schema';

export const deviceTrust = pgTable(
  'device_trust',
  {
    trustingUserId: uuid('trusting_user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),

    trustedUserId: uuid('trusted_user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),

    trustedDeviceId: varchar('trusted_device_id', {
      length: 128,
    }).notNull(),

    status: varchar('status', { length: 16 })
      .$type<'trusted' | 'unverified' | 'blocked'>()
      .notNull()
      .default('unverified'),

    verifiedAt: timestamp('verified_at', {
      withTimezone: true,
    }),

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
    pk: primaryKey({
      columns: [t.trustingUserId, t.trustedUserId, t.trustedDeviceId],
    }),
    trustingIdx: index('device_trust_trusting_idx').on(
      t.trustingUserId,
    ),
    trustedIdx: index('device_trust_trusted_idx').on(
      t.trustedUserId,
    ),
  }),
);
