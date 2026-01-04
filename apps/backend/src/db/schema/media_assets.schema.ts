import {
  pgTable,
  uuid,
  varchar,
  timestamp,
  uniqueIndex,
  index,
  bigint,
  jsonb,
} from 'drizzle-orm/pg-core';
import { users } from './users.schema';
import { conversations } from './conversations.schema';

export const mediaAssets = pgTable(
  'media_assets',
  {
    id: uuid('id').defaultRandom().primaryKey(),

    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),

    conversationId: uuid('conversation_id').references(
      () => conversations.id,
      { onDelete: 'set null' },
    ),

    status: varchar('status', { length: 16 })
      .$type<'pending' | 'uploaded' | 'processing' | 'ready' | 'failed'>()
      .notNull()
      .default('pending'),

    contentType: varchar('content_type', { length: 128 }).notNull(),

    fileName: varchar('file_name', { length: 256 }),

    sizeBytes: bigint('size_bytes', { mode: 'number' }),

    sha256: varchar('sha256', { length: 64 }),

    storageBucket: varchar('storage_bucket', { length: 128 })
      .notNull(),

    storageKey: varchar('storage_key', { length: 512 }).notNull(),

    storageRegion: varchar('storage_region', { length: 64 }),

    metadata: jsonb('metadata'),

    encryptionAlgorithm: varchar('encryption_algorithm', {
      length: 32,
    }),
    encryptionKeyId: varchar('encryption_key_id', {
      length: 128,
    }),
    encryptionIv: varchar('encryption_iv', { length: 128 }),
    encryptionKeyHash: varchar('encryption_key_hash', {
      length: 128,
    }),

    thumbnailKey: varchar('thumbnail_key', { length: 512 }),
    thumbnailContentType: varchar('thumbnail_content_type', {
      length: 128,
    }),

    retentionPolicy: varchar('retention_policy', { length: 32 })
      .notNull()
      .default('standard'),

    expiresAt: timestamp('expires_at', {
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

    uploadedAt: timestamp('uploaded_at', {
      withTimezone: true,
    }),

    processedAt: timestamp('processed_at', {
      withTimezone: true,
    }),
  },
  (t) => ({
    storageKeyUnique: uniqueIndex(
      'media_assets_storage_key_unique',
    ).on(t.storageKey),
    userIdx: index('media_assets_user_idx').on(t.userId),
    conversationIdx: index(
      'media_assets_conversation_idx',
    ).on(t.conversationId),
    statusIdx: index('media_assets_status_idx').on(t.status),
  }),
);
