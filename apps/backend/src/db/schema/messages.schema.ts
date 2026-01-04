import {
  pgTable,
  uuid,
  text,
  timestamp,
  integer,
  varchar,
  index,
  uniqueIndex,
} from 'drizzle-orm/pg-core';
import { conversations } from './conversations.schema';
import { users } from './users.schema';
import { mediaAssets } from './media_assets.schema';

export const messages = pgTable(
  'messages',
  {
    /* ================= IDENTITY ================= */

    id: uuid('id').defaultRandom().primaryKey(),

    conversationId: uuid('conversation_id')
      .notNull()
      .references(() => conversations.id, { onDelete: 'cascade' }),

    senderUserId: uuid('sender_user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    senderDeviceId: varchar('sender_device_id', { length: 128 }).notNull(),

    /* ================= ORDERING ================= */

    seq: integer('seq').notNull(), // monotonic per conversation

    /* ================= CONTENT ================= */

    contentType: varchar('content_type', { length: 16 })
      .$type<'text' | 'system' | 'media'>()
      .notNull()
      .default('text'),

    body: text('body').notNull(), // encrypted later

    clientTempId: varchar('client_temp_id', { length: 64 }),

    mediaAssetId: uuid('media_asset_id').references(
      () => mediaAssets.id,
      { onDelete: 'set null' },
    ),

    editVersion: integer('edit_version')
      .default(0)
      .notNull(),

    /* ================= TIMESTAMPS ================= */

    clientTimestamp: timestamp('client_timestamp', {
      withTimezone: true,
    }),

    createdAt: timestamp('created_at', {
      withTimezone: true,
    })
      .defaultNow()
      .notNull(),

    /* ================= DELIVERY (LEGACY / FAST PATH) ================= */

    deliveredAt: timestamp('delivered_at', {
      withTimezone: true,
    }),

    readAt: timestamp('read_at', {
      withTimezone: true,
    }),

    /* ================= DELETION / TOMBSTONE ================= */

    deletedForAllAt: timestamp('deleted_for_all_at', {
      withTimezone: true,
    }),
  },
  (t) => ({
    conversationSeqIdx: index(
      'idx_messages_conversation_seq',
    ).on(t.conversationId, t.seq),
    messageTempIdUnique: uniqueIndex(
      'idx_messages_temp_id_unique',
    ).on(
      t.conversationId,
      t.senderUserId,
      t.senderDeviceId,
      t.clientTempId,
    ),
  }),
);
