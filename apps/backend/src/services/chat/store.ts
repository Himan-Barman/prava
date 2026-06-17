import type pg from "pg";

import { query, queryMany, queryOne, withTransaction } from "../../lib/pg.js";
import { HttpError, generateId, now, toIso } from "../../lib/security.js";

export const MESSAGE_TYPES = new Set([
  "text",
  "system",
  "media",
  "image",
  "video",
  "file",
  "audio",
  "voice_note",
]);

export function parseLimit(
  raw: unknown,
  fallback: number,
  min: number,
  max: number,
): number {
  const parsed = Number.parseInt(String(raw || ""), 10);
  if (Number.isNaN(parsed)) {
    return fallback;
  }
  return Math.max(min, Math.min(max, parsed));
}

export function normalizeString(value: unknown): string {
  return String(value || "").trim();
}

export function normalizeMemberHash(ids: string[]): string {
  return [...new Set(ids)].sort().join(":");
}

export function normalizeIdList(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  const ids: string[] = [];
  const seen = new Set<string>();
  for (const item of value) {
    const id = normalizeString(item);
    if (id.length < 8 || id.length > 128 || seen.has(id)) {
      continue;
    }
    seen.add(id);
    ids.push(id);
  }
  return ids;
}

function mapMemberRow(row: any) {
  return {
    conversationId: row.conversation_id,
    userId: row.user_id,
    role: row.role || "member",
    joinedAt: row.joined_at,
    leftAt: row.left_at,
  };
}

function mapConversationRow(row: any, members: any[] = []) {
  const mappedMembers = members.map(mapMemberRow);
  const memberIds = mappedMembers.map((member) => member.userId);
  const adminIds = mappedMembers
    .filter((member) => member.role === "admin" || member.role === "owner")
    .map((member) => member.userId);

  return {
    conversationId: row.conversation_id,
    conversationUuid: row.id || row.conversation_uuid || null,
    type: row.type || "dm",
    title: row.title,
    memberHash: row.member_hash,
    ownerUserId: row.owner_user_id,
    seqCounter: Number(row.seq_counter || 0),
    lastMessageId: row.last_message_id,
    lastMessageSeq: row.last_message_seq,
    lastMessageSenderUserId: row.last_message_sender_user_id,
    lastMessageBody: row.last_message_body,
    lastMessageContentType: row.last_message_content_type,
    lastMessageDeletedForAllAt: row.last_message_deleted_for_all_at,
    lastMessageCreatedAt: row.last_message_created_at,
    lastMessageEditVersion: Number(row.last_message_edit_version || 0),
    dmRequestStatus: row.dm_request_status || "active",
    dmRequestSenderUserId: row.dm_request_sender_user_id,
    dmRequestRecipientUserId: row.dm_request_recipient_user_id,
    dmRequestRespondedAt: row.dm_request_responded_at,
    isFavorite: row.is_favorite === true,
    isStarred: row.is_starred === true,
    isMuted: row.is_muted === true,
    isArchived: row.is_archived === true,
    markedUnread: row.marked_unread === true,
    draftText: row.draft_text || "",
    draftUpdatedAt: row.draft_updated_at || null,
    clearedBeforeSeq: Number(row.cleared_before_seq || 0),
    localDeletedAt: row.local_deleted_at || null,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    members: mappedMembers,
    memberIds,
    adminIds,
  };
}

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function normalizeUuid(value: unknown): string | null {
  const id = normalizeString(value).toLowerCase();
  return UUID_RE.test(id) ? id : null;
}

export function getGroupMeta(conversation: any) {
  const memberIds = Array.isArray(conversation.memberIds)
    ? conversation.memberIds.map((id) => String(id))
    : [];

  let ownerUserId = normalizeString(conversation.ownerUserId);
  if (!ownerUserId || !memberIds.includes(ownerUserId)) {
    ownerUserId = memberIds[0] || "";
  }

  const adminSet = new Set(
    (Array.isArray(conversation.adminIds) ? conversation.adminIds : [])
      .map((id) => String(id))
      .filter((id) => memberIds.includes(id)),
  );
  if (ownerUserId) {
    adminSet.add(ownerUserId);
  }

  return {
    memberIds,
    ownerUserId,
    adminIds: [...adminSet],
  };
}

export function roleForUser(groupMeta: any, userId: string): string {
  if (userId === groupMeta.ownerUserId) {
    return "owner";
  }
  if (groupMeta.adminIds.includes(userId)) {
    return "admin";
  }
  return "member";
}

export function isGroupAdmin(groupMeta: any, userId: string): boolean {
  return roleForUser(groupMeta, userId) !== "member";
}

async function loadMembersForConversations(
  conversationIds: string[],
): Promise<Map<string, any[]>> {
  const out = new Map<string, any[]>();
  if (conversationIds.length === 0) {
    return out;
  }

  const placeholders = conversationIds
    .map((_, index) => `$${index + 1}`)
    .join(", ");
  const rows = await queryMany(
    `SELECT conversation_id, user_id, role, joined_at, left_at
     FROM conversation_members
     WHERE conversation_id IN (${placeholders}) AND left_at IS NULL
     ORDER BY joined_at ASC`,
    conversationIds,
  );

  for (const row of rows) {
    const key = String(row.conversation_id);
    const list = out.get(key) || [];
    list.push(row);
    out.set(key, list);
  }

  return out;
}

export async function hydrateConversations(rows: any[]): Promise<any[]> {
  const memberMap = await loadMembersForConversations(
    rows.map((row) => row.conversation_id),
  );
  return rows.map((row) =>
    mapConversationRow(row, memberMap.get(row.conversation_id) || []),
  );
}

export async function hydrateConversation(row: any): Promise<any> {
  const [conversation] = await hydrateConversations([row]);
  return conversation;
}

export async function loadConversationForUser(
  conversationId: string,
  userId: string,
): Promise<any> {
  const row = await queryOne(
    `SELECT c.*
     FROM conversations c
     JOIN conversation_members cm ON cm.conversation_id = c.conversation_id
     WHERE c.conversation_id = $1 AND cm.user_id = $2 AND cm.left_at IS NULL`,
    [conversationId, userId],
  );

  if (!row) {
    throw new HttpError(404, "Conversation not found");
  }

  return hydrateConversation(row);
}

export async function loadConversationForUserOrNull(
  conversationId: string,
  userId: string,
): Promise<any | null> {
  try {
    return await loadConversationForUser(conversationId, userId);
  } catch (error) {
    if (error instanceof HttpError && error.statusCode === 404) {
      return null;
    }
    throw error;
  }
}

export async function ensureUserExists(userId: string): Promise<any> {
  const user = await queryOne(
    `SELECT user_id, username, display_name
     FROM users
     WHERE user_id = $1 AND deleted_at IS NULL`,
    [userId],
  );

  if (!user) {
    throw new HttpError(404, "User not found");
  }

  return {
    userId: user.user_id,
    username: user.username,
    displayName: user.display_name,
  };
}

function mapReaction(row: any) {
  return {
    userId: row.user_id,
    emoji: row.emoji,
    reactedAt: toIso(row.reacted_at),
    updatedAt: toIso(row.updated_at),
  };
}

export async function loadReactions(
  messageIds: string[],
): Promise<Map<string, any[]>> {
  const out = new Map<string, any[]>();
  if (messageIds.length === 0) {
    return out;
  }

  const placeholders = messageIds.map((_, index) => `$${index + 1}`).join(", ");
  const rows = await queryMany(
    `SELECT message_id, user_id, emoji, reacted_at, updated_at
     FROM message_reactions
     WHERE message_id IN (${placeholders})
     ORDER BY reacted_at ASC`,
    messageIds,
  );

  for (const row of rows) {
    const key = String(row.message_id);
    const list = out.get(key) || [];
    list.push(mapReaction(row));
    out.set(key, list);
  }

  return out;
}

export async function getMessageReactions(messageId: string): Promise<any[]> {
  const reactions = await loadReactions([messageId]);
  return reactions.get(messageId) || [];
}

export function mapMessage(message: any, reactions: any[] = []) {
  const mediaUrl =
    message.media_secure_url ||
    message.media_url ||
    message.secure_url ||
    message.url ||
    null;
  return {
    id: message.message_id,
    messageId: message.message_id,
    clientMessageId:
      message.client_message_id || message.client_message_uuid || null,
    conversationId: message.conversation_id,
    senderUserId: message.sender_user_id,
    senderDeviceId: message.sender_device_id || "",
    body: message.body,
    contentType: message.content_type,
    seq: Number(message.seq || 0),
    mediaAssetId: message.media_asset_id || null,
    mediaUrl,
    mediaSecureUrl: mediaUrl,
    mediaResourceType:
      message.media_resource_type || message.resource_type || null,
    mediaWidth:
      message.media_width == null ? null : Number(message.media_width),
    mediaHeight:
      message.media_height == null ? null : Number(message.media_height),
    mediaBytes:
      message.media_bytes == null ? null : Number(message.media_bytes),
    replyToMessageId: message.reply_to_message_id || null,
    replyToId: message.reply_to_message_id || null,
    editVersion: Number(message.edit_version || 0),
    reactions,
    createdAt: toIso(message.created_at),
    deletedForAllAt: toIso(message.deleted_for_all_at),
  };
}

export function toRealtimeMessagePayload(message: any) {
  const mediaUrl =
    message.media_secure_url ||
    message.media_url ||
    message.secure_url ||
    message.url ||
    null;
  return {
    conversationId: message.conversation_id,
    messageId: message.message_id,
    clientMessageId:
      message.client_message_id || message.client_message_uuid || null,
    senderUserId: message.sender_user_id,
    senderDeviceId: message.sender_device_id || "",
    seq: Number(message.seq || 0),
    contentType: message.content_type,
    body: message.body,
    replyToMessageId: message.reply_to_message_id || null,
    replyToId: message.reply_to_message_id || null,
    mediaAssetId: message.media_asset_id || null,
    mediaUrl,
    mediaSecureUrl: mediaUrl,
    mediaResourceType:
      message.media_resource_type || message.resource_type || null,
    mediaWidth:
      message.media_width == null ? null : Number(message.media_width),
    mediaHeight:
      message.media_height == null ? null : Number(message.media_height),
    mediaBytes:
      message.media_bytes == null ? null : Number(message.media_bytes),
    editVersion: Number(message.edit_version || 0),
    deletedForAllAt: toIso(message.deleted_for_all_at),
    createdAt: toIso(message.created_at),
  };
}

export async function hydrateMessageMedia<T extends Record<string, any>>(
  messages: T[],
): Promise<T[]> {
  const mediaAssetIds = [
    ...new Set(
      messages
        .map((message) => normalizeString(message.media_asset_id))
        .filter((id) => id.length > 0),
    ),
  ];

  if (mediaAssetIds.length === 0) {
    return messages;
  }

  const assets = await queryMany(
    `SELECT asset_id, secure_url, url, resource_type, width, height, bytes
     FROM media_assets
     WHERE asset_id = ANY($1::text[])`,
    [mediaAssetIds],
  );
  const assetMap = new Map(
    assets.map((asset) => [String(asset.asset_id), asset]),
  );

  return messages.map((message) => {
    const asset = assetMap.get(normalizeString(message.media_asset_id));
    if (!asset) {
      return message;
    }
    return {
      ...message,
      media_secure_url: asset.secure_url || asset.url || null,
      media_url: asset.secure_url || asset.url || null,
      media_resource_type: asset.resource_type || null,
      media_width: asset.width ?? null,
      media_height: asset.height ?? null,
      media_bytes: asset.bytes ?? null,
    };
  });
}

async function ensureConversationUuid(
  client: pg.PoolClient,
  conversationId: string,
): Promise<string | null> {
  const current = await client.query(
    `SELECT id FROM conversations WHERE conversation_id = $1 LIMIT 1`,
    [conversationId],
  );
  if (current.rows[0]?.id) {
    return String(current.rows[0].id);
  }

  const generated = generateId();
  const updated = await client.query(
    `UPDATE conversations
     SET id = $2
     WHERE conversation_id = $1 AND id IS NULL
     RETURNING id`,
    [conversationId, generated],
  );
  if (updated.rows[0]?.id) {
    return String(updated.rows[0].id);
  }

  const reloaded = await client.query(
    `SELECT id FROM conversations WHERE conversation_id = $1 LIMIT 1`,
    [conversationId],
  );
  return reloaded.rows[0]?.id ? String(reloaded.rows[0].id) : null;
}

async function ensureUserUuid(
  client: pg.PoolClient,
  userId: string,
): Promise<string | null> {
  const current = await client.query(
    `SELECT id FROM users WHERE user_id = $1 LIMIT 1`,
    [userId],
  );
  if (current.rows[0]?.id) {
    return String(current.rows[0].id);
  }

  const generated = generateId();
  const updated = await client.query(
    `UPDATE users
     SET id = $2
     WHERE user_id = $1 AND id IS NULL
     RETURNING id`,
    [userId, generated],
  );
  if (updated.rows[0]?.id) {
    return String(updated.rows[0].id);
  }

  const reloaded = await client.query(
    `SELECT id FROM users WHERE user_id = $1 LIMIT 1`,
    [userId],
  );
  return reloaded.rows[0]?.id ? String(reloaded.rows[0].id) : null;
}

async function loadReplyMessageUuid(
  client: pg.PoolClient,
  conversationId: string,
  messageId?: string | null,
): Promise<string | null> {
  if (!messageId) {
    return null;
  }

  const row = await client.query(
    `SELECT message_uuid
     FROM messages
     WHERE conversation_id = $1 AND message_id = $2
     LIMIT 1`,
    [conversationId, messageId],
  );
  return row.rows[0]?.message_uuid ? String(row.rows[0].message_uuid) : null;
}

async function upsertReadStateWithClient(
  client: pg.PoolClient,
  conversationId: string,
  userId: string,
  lastReadSeq: number,
  lastDeliveredSeq: number,
  ts: Date,
): Promise<void> {
  await client.query(
    `INSERT INTO conversation_reads (conversation_id, user_id, last_read_seq, last_delivered_seq, updated_at)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (conversation_id, user_id)
     DO UPDATE SET
       last_read_seq = GREATEST(conversation_reads.last_read_seq, EXCLUDED.last_read_seq),
       last_delivered_seq = GREATEST(conversation_reads.last_delivered_seq, EXCLUDED.last_delivered_seq),
       updated_at = EXCLUDED.updated_at`,
    [conversationId, userId, lastReadSeq, lastDeliveredSeq, ts],
  );
}

export async function upsertReadState(
  conversation: any,
  userId: string,
  options: { lastReadSeq?: number; lastDeliveredSeq?: number },
): Promise<{ lastReadSeq?: number; lastDeliveredSeq?: number }> {
  const seqCounter = Number(conversation.seqCounter || 0);
  const ts = now();

  if (options.lastReadSeq !== undefined) {
    const lastReadSeq = Math.min(
      Math.max(options.lastReadSeq, 0),
      seqCounter || options.lastReadSeq,
    );
    await query(
      `INSERT INTO conversation_reads (conversation_id, user_id, last_read_seq, last_delivered_seq, updated_at)
       VALUES ($1, $2, $3, 0, $4)
       ON CONFLICT (conversation_id, user_id)
       DO UPDATE SET
         last_read_seq = GREATEST(conversation_reads.last_read_seq, EXCLUDED.last_read_seq),
         updated_at = EXCLUDED.updated_at`,
      [conversation.conversationId, userId, lastReadSeq, ts],
    );
    return { lastReadSeq };
  }

  const requestedDeliveredSeq = options.lastDeliveredSeq || 0;
  const lastDeliveredSeq = Math.min(
    Math.max(requestedDeliveredSeq, 0),
    seqCounter || requestedDeliveredSeq,
  );
  await query(
    `INSERT INTO conversation_reads (conversation_id, user_id, last_read_seq, last_delivered_seq, updated_at)
     VALUES ($1, $2, 0, $3, $4)
     ON CONFLICT (conversation_id, user_id)
     DO UPDATE SET
       last_delivered_seq = GREATEST(conversation_reads.last_delivered_seq, EXCLUDED.last_delivered_seq),
       updated_at = EXCLUDED.updated_at`,
    [conversation.conversationId, userId, lastDeliveredSeq, ts],
  );
  return { lastDeliveredSeq };
}

export async function createMessage(
  conversation: any,
  input: {
    senderUserId: string;
    senderDeviceId: string;
    body: string;
    contentType: string;
    mediaAssetId?: string | null;
    replyToMessageId?: string | null;
    clientMessageId?: string | null;
    clientTimestamp?: unknown;
  },
): Promise<{ message: any; created: boolean }> {
  const ts = now();
  const clientMessageId = normalizeUuid(input.clientMessageId);

  return withTransaction(async (client) => {
    if (clientMessageId) {
      const existing = await client.query(
        `SELECT *
         FROM messages
         WHERE conversation_id = $1
           AND sender_user_id = $2
           AND client_message_id = $3::uuid
         LIMIT 1`,
        [conversation.conversationId, input.senderUserId, clientMessageId],
      );
      if (existing.rows[0]) {
        return { message: existing.rows[0], created: false };
      }
    }

    const conversationUuid = await ensureConversationUuid(
      client,
      conversation.conversationId,
    );
    const senderUuid = await ensureUserUuid(client, input.senderUserId);
    const replyToMessageUuid = await loadReplyMessageUuid(
      client,
      conversation.conversationId,
      input.replyToMessageId || null,
    );

    const seqResult = await client.query(
      `UPDATE conversations
       SET seq_counter = seq_counter + 1, updated_at = $2
       WHERE conversation_id = $1
       RETURNING seq_counter`,
      [conversation.conversationId, ts],
    );

    const nextSeq = Number(seqResult.rows[0]?.seq_counter || 1);
    const messageId = generateId();
    const messageResult = await client.query(
      `INSERT INTO messages (
         message_id, message_uuid, conversation_id, conversation_uuid,
         sender_user_id, sender_uuid, sender_device_id, seq, sequence_id,
         content_type, message_type, body, body_text, reply_to_message_id,
         reply_to_message_uuid, media_asset_id, client_timestamp,
         client_message_id, client_message_uuid, delivery_state, metadata,
         edit_version, deleted_for_all_at, created_at, updated_at
       )
       VALUES (
         $1, $2, $3, $4,
         $5, $6, $7, $8, $9,
         $10, $11, $12, $13, $14,
         $15, $16, $17,
         $18, $19, 'sent', $20,
         0, NULL, $21, $22
       )
       RETURNING *`,
      [
        messageId,
        messageId,
        conversation.conversationId,
        conversationUuid,
        input.senderUserId,
        senderUuid,
        input.senderDeviceId,
        nextSeq,
        nextSeq,
        input.contentType,
        input.contentType,
        input.body,
        input.body,
        input.replyToMessageId || null,
        replyToMessageUuid,
        input.mediaAssetId || null,
        input.clientTimestamp == null ? null : String(input.clientTimestamp),
        clientMessageId,
        clientMessageId,
        JSON.stringify({}),
        ts,
        ts,
      ],
    );

    const message = messageResult.rows[0];
    if (input.mediaAssetId) {
      await client.query(
        `UPDATE chat_attachments
         SET conversation_id = $2,
             message_id = $3,
             status = 'attached',
             updated_at = $4
         WHERE owner_user_id = $1
           AND media_asset_id = $5
           AND deleted_at IS NULL
           AND (conversation_id IS NULL OR conversation_id = $2)
           AND (message_id IS NULL OR message_id = $3)`,
        [
          input.senderUserId,
          conversation.conversationId,
          message.message_id,
          ts,
          input.mediaAssetId,
        ],
      );
    }

    await client.query(
      `UPDATE conversations
       SET updated_at = $2,
           last_message_id = $3,
           last_message_seq = $4,
           last_message_sender_user_id = $5,
           last_message_body = $6,
           last_message_content_type = $7,
           last_message_deleted_for_all_at = NULL,
           last_message_created_at = $8,
           last_message_edit_version = 0
       WHERE conversation_id = $1`,
      [
        conversation.conversationId,
        ts,
        message.message_id,
        message.seq,
        message.sender_user_id,
        message.body,
        message.content_type,
        ts,
      ],
    );

    await upsertReadStateWithClient(
      client,
      conversation.conversationId,
      input.senderUserId,
      nextSeq,
      nextSeq,
      ts,
    );

    return { message, created: true };
  });
}

export async function editMessageForUser(
  conversation: any,
  messageId: string,
  userId: string,
  body: string,
): Promise<any | null> {
  const ts = now();
  const updated = await queryOne(
    `UPDATE messages
     SET body = $4, updated_at = $5, edit_version = edit_version + 1
     WHERE conversation_id = $1
       AND message_id = $2
       AND sender_user_id = $3
       AND deleted_for_all_at IS NULL
     RETURNING *`,
    [conversation.conversationId, messageId, userId, body, ts],
  );

  if (!updated) {
    return null;
  }

  if (conversation.lastMessageId === messageId) {
    await query(
      `UPDATE conversations
       SET last_message_body = $3,
           last_message_content_type = $4,
           last_message_deleted_for_all_at = NULL,
           last_message_edit_version = $5,
           updated_at = $2
       WHERE conversation_id = $1`,
      [
        conversation.conversationId,
        ts,
        body,
        updated.content_type || "text",
        Number(updated.edit_version || 0),
      ],
    );
  }

  return updated;
}

export async function deleteMessageForUser(
  conversation: any,
  messageId: string,
  userId: string,
): Promise<any | null> {
  const ts = now();
  const updated = await queryOne(
    `UPDATE messages
     SET deleted_for_all_at = $4,
         updated_at = $4,
         body = '',
         content_type = 'system'
     WHERE conversation_id = $1
       AND message_id = $2
       AND sender_user_id = $3
       AND deleted_for_all_at IS NULL
     RETURNING *`,
    [conversation.conversationId, messageId, userId, ts],
  );

  if (!updated) {
    return null;
  }

  if (conversation.lastMessageId === messageId) {
    await query(
      `UPDATE conversations
       SET last_message_body = '',
           last_message_content_type = 'system',
           last_message_deleted_for_all_at = $2,
           last_message_edit_version = $3,
           updated_at = $2
       WHERE conversation_id = $1`,
      [conversation.conversationId, ts, Number(updated.edit_version || 0)],
    );
  }

  return updated;
}

export async function setReactionForUser(
  conversationId: string,
  messageId: string,
  userId: string,
  emoji: string | null,
): Promise<any[] | null> {
  const message = await queryOne(
    `SELECT message_id FROM messages WHERE conversation_id = $1 AND message_id = $2`,
    [conversationId, messageId],
  );
  if (!message) {
    return null;
  }

  const ts = now();
  if (emoji === null) {
    await query(
      `DELETE FROM message_reactions WHERE message_id = $1 AND user_id = $2`,
      [messageId, userId],
    );
  } else {
    await query(
      `INSERT INTO message_reactions (message_id, user_id, emoji, reacted_at, updated_at)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (message_id, user_id)
       DO UPDATE SET emoji = EXCLUDED.emoji, updated_at = EXCLUDED.updated_at`,
      [messageId, userId, emoji, ts, ts],
    );
  }

  return getMessageReactions(messageId);
}
