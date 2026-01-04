import {
  pgTable,
  uuid,
  varchar,
  text,
  timestamp,
  boolean,
  uniqueIndex,
} from 'drizzle-orm/pg-core';

export const users = pgTable(
  'users',
  {
    id: uuid('id').defaultRandom().primaryKey(),

    email: varchar('email', { length: 255 }).notNull(),

    username: varchar('username', { length: 32 }).notNull(),

    displayName: varchar('display_name', { length: 64 }),

    firstName: varchar('first_name', { length: 64 }),

    lastName: varchar('last_name', { length: 64 }),

    bio: text('bio'),

    location: varchar('location', { length: 120 }),

    website: varchar('website', { length: 255 }),

    phoneCountry: varchar('phone_country', { length: 8 }),

    phoneNumber: varchar('phone_number', { length: 20 }),

    passwordHash: varchar('password_hash', { length: 255 }).notNull(),

    isVerified: boolean('is_verified').notNull().default(false),

    emailVerifiedAt: timestamp('email_verified_at', {
      withTimezone: true,
    }),

    createdAt: timestamp('created_at', { withTimezone: true })
      .notNull()
      .defaultNow(),

    updatedAt: timestamp('updated_at', { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => ({
    emailUnique: uniqueIndex('users_email_unique').on(t.email),
    usernameUnique: uniqueIndex('users_username_unique').on(t.username),
  })
);
