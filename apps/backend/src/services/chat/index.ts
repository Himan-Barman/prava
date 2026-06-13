import { requireAuth } from "../../lib/auth.js";
import { query, queryMany, queryOne, withTransaction } from "../../lib/pg.js";
import {
  HttpError,
  ensure,
  generateId,
  now,
  toIso,
} from "../../lib/security.js";
import {
  publishToConversation,
  publishToUsers,
} from "../realtime/hub.js";
import { enqueueNotificationEvent } from "../notification/repository.js";
import {
  canSendDirectMessage,
} from "../../shared/policies/index.js";
import {
  MESSAGE_TYPES,
  createMessage,
  deleteMessageForUser,
  editMessageForUser,
  ensureUserExists,
  getGroupMeta,
  hydrateConversations,
  isGroupAdmin,
  loadConversationForUser,
  loadConversationForUserOrNull,
  loadReactions,
  mapMessage,
  normalizeIdList,
  normalizeMemberHash,
  normalizeString,
  parseLimit,
  roleForUser,
  setReactionForUser,
  toRealtimeMessagePayload,
  upsertReadState,
} from "./store.js";

function userDisplayName(row: any): string {
  return row?.display_name || row?.username || "Conversation";
}

async function shouldCreateNotification(userId: string, categoryKey: string) {
  const row = await queryOne(
    `SELECT settings FROM user_settings WHERE user_id = $1`,
    [userId]
  );
  const settings = row?.settings || {};
  return settings.pushNotifications !== false && settings[categoryKey] !== false;
}

async function createChatNotifications({
  conversationId,
  conversation,
  memberIds,
  actorUserId,
  body,
}: {
  conversationId: string;
  conversation: any;
  memberIds: string[];
  actorUserId: string;
  body: string;
}) {
  const recipients = memberIds.filter((id) => id !== actorUserId);
  if (recipients.length === 0) return;

  const actor = await queryOne(
    `SELECT username, display_name FROM users WHERE user_id = $1`,
    [actorUserId]
  );
  const actorName = userDisplayName(actor);
  const title = conversation.type === "group"
    ? conversation.title || "New group message"
    : actorName;
  const preview = body.length > 90 ? `${body.slice(0, 87)}...` : body;

  for (const userId of recipients) {
    if (!(await shouldCreateNotification(userId, "notifyChats"))) continue;
    await enqueueNotificationEvent({
      eventType: conversation.type === "group"
        ? "GROUP_MESSAGE_RECEIVED"
        : "DM_MESSAGE_RECEIVED",
      recipientUserId: userId,
      actorUserId,
      entityType: "conversation",
      entityId: conversationId,
      payload: {
        conversationId,
        title,
        body: preview,
      },
    });
  }
}

async function loadActiveUsers(ids: string[]): Promise<any[]> {
  if (ids.length === 0) {
    return [];
  }
  return queryMany(
    `SELECT user_id, username, display_name, avatar_url, last_seen_at
     FROM users
     WHERE user_id = ANY($1::text[]) AND deleted_at IS NULL`,
    [ids]
  );
}

async function loadMessagesWithReactions(rows: any[]): Promise<any[]> {
  const reactionMap = await loadReactions(rows.map((row) => row.message_id));
  return rows.map((row) => mapMessage(row, reactionMap.get(row.message_id) || []));
}

function conversationSummary(conversation: any, currentUserId: string, peerMap: Map<string, any>, lastReadSeq: number) {
  let title = conversation.title || "Conversation";
  let peerUserId = "";
  let peerAvatarUrl = "";
  let peerLastSeenAt: Date | null = null;
  if (conversation.type === "dm") {
    const peerId = (conversation.memberIds || []).find((id) => id !== currentUserId);
    peerUserId = peerId || "";
    const peer = peerId ? peerMap.get(peerId) : null;
    if (peer) {
      title = userDisplayName(peer);
      peerAvatarUrl = peer.avatar_url || "";
      peerLastSeenAt = peer.last_seen_at || null;
    }
  }

  const lastSeq = Number(conversation.seqCounter || 0);
  const groupMeta = conversation.type === "group"
    ? getGroupMeta(conversation)
    : undefined;

  const computedUnread = Math.max(0, lastSeq - lastReadSeq);
  const unreadCount = conversation.markedUnread === true && lastSeq > 0
    ? Math.max(1, computedUnread)
    : computedUnread;

  return {
    id: conversation.conversationId,
    type: conversation.type,
    title,
    unreadCount,
    updatedAt: toIso(conversation.updatedAt),
    lastMessageId: conversation.lastMessageId || null,
    lastMessageSeq: conversation.lastMessageSeq ?? null,
    lastMessageSenderUserId: conversation.lastMessageSenderUserId || null,
    lastMessageBody: conversation.lastMessageBody || null,
    lastMessageContentType: conversation.lastMessageContentType || null,
    lastMessageDeletedForAllAt: toIso(conversation.lastMessageDeletedForAllAt),
    lastMessageCreatedAt: toIso(conversation.lastMessageCreatedAt),
    lastMessageEditVersion: Number(conversation.lastMessageEditVersion || 0),
    memberCount: Array.isArray(conversation.memberIds) ? conversation.memberIds.length : 0,
    isAdmin: groupMeta ? isGroupAdmin(groupMeta, currentUserId) : false,
    myRole: groupMeta ? roleForUser(groupMeta, currentUserId) : "member",
    peerUserId,
    peerAvatarUrl,
    peerLastSeenAt: toIso(peerLastSeenAt),
    requestStatus: conversation.dmRequestStatus || "active",
    requestSenderUserId: conversation.dmRequestSenderUserId || null,
    requestRecipientUserId: conversation.dmRequestRecipientUserId || null,
    requestRespondedAt: toIso(conversation.dmRequestRespondedAt),
    isFavorite: conversation.isFavorite === true,
    isStarred: conversation.isStarred === true,
    isMuted: conversation.isMuted === true,
    isArchived: conversation.isArchived === true,
    markedUnread: conversation.markedUnread === true,
    draftText: conversation.draftText || "",
    draftUpdatedAt: toIso(conversation.draftUpdatedAt),
    clearedBeforeSeq: Number(conversation.clearedBeforeSeq || 0),
    localDeletedAt: toIso(conversation.localDeletedAt),
  };
}

async function areMutualFollowers(a: string, b: string): Promise<boolean> {
  const rows = await queryMany(
    `SELECT follower_id, following_id
     FROM follows
     WHERE (follower_id = $1 AND following_id = $2)
        OR (follower_id = $2 AND following_id = $1)`,
    [a, b]
  );
  const aFollowsB = rows.some((row) => row.follower_id === a && row.following_id === b);
  const bFollowsA = rows.some((row) => row.follower_id === b && row.following_id === a);
  return aFollowsB && bFollowsA;
}

function ensureConversationOpenForUser(conversation: any, userId: string) {
  if (conversation.type !== "dm") {
    return;
  }
  ensure(conversation.dmRequestStatus !== "declined", 403, "Message request was removed");
  if (
    conversation.dmRequestStatus === "pending" &&
    conversation.dmRequestRecipientUserId === userId
  ) {
    throw new HttpError(403, "Accept the message request before opening this chat");
  }
}

async function ensureDmSendAllowed(conversation: any, userId: string) {
  if (conversation.type !== "dm") return;
  const peerId = (conversation.memberIds || []).find((id: string) => id !== userId);
  if (!peerId) return;
  const policy = await canSendDirectMessage(userId, peerId);
  ensure(policy.allowed, 403, "User interaction is blocked");
}

function boolOrCurrent(value: unknown, current: boolean): boolean {
  return value === undefined ? current : value === true;
}

type ConversationPreferencePatch = {
  isFavorite?: boolean;
  isStarred?: boolean;
  isMuted?: boolean;
  isArchived?: boolean;
  markedUnread?: boolean;
  draftText?: string;
  clearedBeforeSeq?: number;
  localDeletedAt?: Date | null;
};

async function loadPreference(conversationId: string, userId: string) {
  const row = await queryOne(
    `SELECT is_favorite, is_starred, is_muted, is_archived, marked_unread,
            draft_text, draft_updated_at, cleared_before_seq, local_deleted_at
     FROM conversation_user_preferences
     WHERE conversation_id = $1 AND user_id = $2`,
    [conversationId, userId]
  );

  return {
    isFavorite: row?.is_favorite === true,
    isStarred: row?.is_starred === true,
    isMuted: row?.is_muted === true,
    isArchived: row?.is_archived === true,
    markedUnread: row?.marked_unread === true,
    draftText: row?.draft_text || "",
    draftUpdatedAt: row?.draft_updated_at || null,
    clearedBeforeSeq: Number(row?.cleared_before_seq || 0),
    localDeletedAt: row?.local_deleted_at || null,
  };
}

async function savePreference(
  conversationId: string,
  userId: string,
  patch: ConversationPreferencePatch
) {
  const current = await loadPreference(conversationId, userId);
  const ts = now();
  const draftText = patch.draftText === undefined
    ? current.draftText
    : normalizeString(patch.draftText).slice(0, 8000);
  const draftUpdatedAt = patch.draftText === undefined
    ? current.draftUpdatedAt
    : (draftText ? ts : null);
  const next = {
    isFavorite: patch.isFavorite ?? current.isFavorite,
    isStarred: patch.isStarred ?? current.isStarred,
    isMuted: patch.isMuted ?? current.isMuted,
    isArchived: patch.isArchived ?? current.isArchived,
    markedUnread: patch.markedUnread ?? current.markedUnread,
    draftText,
    draftUpdatedAt,
    clearedBeforeSeq: patch.clearedBeforeSeq ?? current.clearedBeforeSeq,
    localDeletedAt: patch.localDeletedAt === undefined
      ? current.localDeletedAt
      : patch.localDeletedAt,
  };

  await query(
    `INSERT INTO conversation_user_preferences (
       conversation_id, user_id, is_favorite, is_starred, is_muted,
       is_archived, marked_unread, draft_text, draft_updated_at,
       cleared_before_seq, local_deleted_at, updated_at
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
     ON CONFLICT (conversation_id, user_id)
     DO UPDATE SET
       is_favorite = EXCLUDED.is_favorite,
       is_starred = EXCLUDED.is_starred,
       is_muted = EXCLUDED.is_muted,
       is_archived = EXCLUDED.is_archived,
       marked_unread = EXCLUDED.marked_unread,
       draft_text = EXCLUDED.draft_text,
       draft_updated_at = EXCLUDED.draft_updated_at,
       cleared_before_seq = EXCLUDED.cleared_before_seq,
       local_deleted_at = EXCLUDED.local_deleted_at,
       updated_at = EXCLUDED.updated_at`,
    [
      conversationId,
      userId,
      next.isFavorite,
      next.isStarred,
      next.isMuted,
      next.isArchived,
      next.markedUnread,
      next.draftText,
      next.draftUpdatedAt,
      next.clearedBeforeSeq,
      next.localDeletedAt,
      ts,
    ]
  );

  return {
    isFavorite: next.isFavorite,
    isStarred: next.isStarred,
    isMuted: next.isMuted,
    isArchived: next.isArchived,
    markedUnread: next.markedUnread,
    draftText: next.draftText,
    draftUpdatedAt: toIso(next.draftUpdatedAt),
    clearedBeforeSeq: next.clearedBeforeSeq,
    localDeletedAt: toIso(next.localDeletedAt),
    updatedAt: toIso(ts),
  };
}

async function setConversationFlag(
  conversationId: string,
  userId: string,
  patch: ConversationPreferencePatch
) {
  await loadConversationForUser(conversationId, userId);
  return savePreference(conversationId, userId, patch);
}

function attachmentTypeFromMime(mimeType: string): string {
  if (mimeType.startsWith("image/")) return "image";
  if (mimeType.startsWith("video/")) return "video";
  if (mimeType.startsWith("audio/")) return "audio";
  if (mimeType === "application/pdf" || mimeType.startsWith("text/")) return "document";
  return "file";
}

function mapChatAttachment(row: any) {
  return {
    attachmentId: row.attachment_id,
    ownerUserId: row.owner_user_id,
    conversationId: row.conversation_id || null,
    messageId: row.message_id || null,
    mediaAssetId: row.media_asset_id || null,
    uploadSessionId: row.upload_session_id,
    attachmentType: row.attachment_type || "file",
    fileName: row.file_name || "",
    mimeType: row.mime_type || "application/octet-stream",
    byteSize: Number(row.byte_size || 0),
    status: row.status || "pending",
    metadata: row.metadata || {},
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at),
    deletedAt: toIso(row.deleted_at),
  };
}

function mapGroupInvite(row: any) {
  return {
    inviteId: row.invite_id,
    conversationId: row.conversation_id,
    inviteToken: row.invite_token,
    createdByUserId: row.created_by_user_id,
    maxUses: row.max_uses == null ? null : Number(row.max_uses),
    useCount: Number(row.use_count || 0),
    requiresApproval: row.requires_approval === true,
    status: row.status || "active",
    expiresAt: toIso(row.expires_at),
    createdAt: toIso(row.created_at),
    revokedAt: toIso(row.revoked_at),
  };
}

function mapJoinRequest(row: any) {
  return {
    requestId: row.request_id,
    inviteId: row.invite_id || null,
    conversationId: row.conversation_id,
    requesterUserId: row.requester_user_id,
    status: row.status || "pending",
    decidedByUserId: row.decided_by_user_id || null,
    decidedAt: toIso(row.decided_at),
    createdAt: toIso(row.created_at),
  };
}

async function ensureOwnedMediaAsset(mediaAssetId: string, userId: string) {
  if (!mediaAssetId) return null;
  const row = await queryOne(
    `SELECT asset_id, resource_type, bytes
     FROM media_assets
     WHERE asset_id = $1 AND user_id = $2`,
    [mediaAssetId, userId]
  );
  if (!row) {
    throw new HttpError(404, "Media asset not found");
  }
  return row;
}

async function ensureGroupConversationForAdmin(conversationId: string, userId: string) {
  const conversation = await loadConversationForUser(conversationId, userId);
  ensure(conversation.type === "group", 400, "Conversation is not a group");
  const groupMeta = getGroupMeta(conversation);
  ensure(isGroupAdmin(groupMeta, userId), 403, "Admin privileges required");
  return { conversation, groupMeta };
}

export default async function chatService(app: any) {
  app.get("/", { preHandler: requireAuth }, async (request: any) => {
    const limit = parseLimit(request.query?.limit, 30, 1, 100);
    const archivedOnly = String(request.query?.archived || "").toLowerCase() === "true";
    const includeArchived = String(request.query?.includeArchived || "").toLowerCase() === "true";
    const starredOnly = String(request.query?.starred || "").toLowerCase() === "true";
    const favoriteOnly = String(request.query?.favorite || "").toLowerCase() === "true";

    const preferenceFilters: string[] = [];
    if (archivedOnly) {
      preferenceFilters.push("COALESCE(cup.is_archived, FALSE) = TRUE");
    } else if (!includeArchived) {
      preferenceFilters.push("COALESCE(cup.is_archived, FALSE) = FALSE");
    }
    if (starredOnly) {
      preferenceFilters.push("COALESCE(cup.is_starred, FALSE) = TRUE");
    }
    if (favoriteOnly) {
      preferenceFilters.push("COALESCE(cup.is_favorite, FALSE) = TRUE");
    }

    const rows = await queryMany(
      `SELECT c.*,
              COALESCE(cup.is_favorite, FALSE) AS is_favorite,
              COALESCE(cup.is_starred, FALSE) AS is_starred,
              COALESCE(cup.is_muted, FALSE) AS is_muted,
              COALESCE(cup.is_archived, FALSE) AS is_archived,
              COALESCE(cup.marked_unread, FALSE) AS marked_unread,
              COALESCE(cup.draft_text, '') AS draft_text,
              cup.draft_updated_at AS draft_updated_at,
              COALESCE(cup.cleared_before_seq, 0) AS cleared_before_seq,
              cup.local_deleted_at AS local_deleted_at
       FROM conversations c
       JOIN conversation_members cm ON cm.conversation_id = c.conversation_id
       LEFT JOIN conversation_user_preferences cup
         ON cup.conversation_id = c.conversation_id
        AND cup.user_id = $1
       WHERE cm.user_id = $1 AND cm.left_at IS NULL
         ${preferenceFilters.length > 0 ? `AND ${preferenceFilters.join("\n         AND ")}` : ""}
         AND (
           c.type <> 'dm'
           OR c.dm_request_status = 'active'
           OR c.dm_request_sender_user_id = $1
         )
         AND c.dm_request_status <> 'declined'
         AND (
           cup.local_deleted_at IS NULL
           OR c.seq_counter > COALESCE(cup.cleared_before_seq, 0)
         )
       ORDER BY c.updated_at DESC
       LIMIT $2`,
      [request.user.userId, limit]
    );

    const conversations = await hydrateConversations(rows);
    if (conversations.length === 0) {
      return [];
    }

    const conversationIds = conversations.map((row) => row.conversationId);
    const reads = await queryMany(
      `SELECT conversation_id, last_read_seq
       FROM conversation_reads
       WHERE user_id = $1 AND conversation_id = ANY($2::text[])`,
      [request.user.userId, conversationIds]
    );
    const readMap = new Map(reads.map((item) => [item.conversation_id, Number(item.last_read_seq || 0)]));

    const otherUserIds = new Set<string>();
    for (const conversation of conversations) {
      if (conversation.type === "dm") {
        for (const memberId of conversation.memberIds || []) {
          if (memberId !== request.user.userId) {
            otherUserIds.add(memberId);
          }
        }
      }
    }

    const otherUsers = await loadActiveUsers([...otherUserIds]);
    const userMap = new Map(otherUsers.map((user) => [user.user_id, user]));

    return conversations.map((conversation) =>
      conversationSummary(
        conversation,
        request.user.userId,
        userMap,
        readMap.get(conversation.conversationId) || 0
      )
    );
  });

  app.get("/requests", { preHandler: requireAuth }, async (request: any) => {
    const limit = parseLimit(request.query?.limit, 30, 1, 100);

    const rows = await queryMany(
      `SELECT c.*,
              COALESCE(cup.is_favorite, FALSE) AS is_favorite,
              COALESCE(cup.is_starred, FALSE) AS is_starred,
              COALESCE(cup.is_muted, FALSE) AS is_muted,
              COALESCE(cup.is_archived, FALSE) AS is_archived,
              COALESCE(cup.marked_unread, FALSE) AS marked_unread,
              COALESCE(cup.draft_text, '') AS draft_text,
              cup.draft_updated_at AS draft_updated_at,
              COALESCE(cup.cleared_before_seq, 0) AS cleared_before_seq,
              cup.local_deleted_at AS local_deleted_at
       FROM conversations c
       JOIN conversation_members cm ON cm.conversation_id = c.conversation_id
       LEFT JOIN conversation_user_preferences cup
         ON cup.conversation_id = c.conversation_id
        AND cup.user_id = $1
       WHERE c.type = 'dm'
         AND c.dm_request_status = 'pending'
         AND c.dm_request_recipient_user_id = $1
         AND c.last_message_id IS NOT NULL
         AND cm.user_id = $1
         AND cm.left_at IS NULL
         AND (
           cup.local_deleted_at IS NULL
           OR c.seq_counter > COALESCE(cup.cleared_before_seq, 0)
         )
       ORDER BY c.updated_at DESC
       LIMIT $2`,
      [request.user.userId, limit]
    );

    const conversations = await hydrateConversations(rows);
    if (conversations.length === 0) {
      return [];
    }

    const conversationIds = conversations.map((row) => row.conversationId);
    const reads = await queryMany(
      `SELECT conversation_id, last_read_seq
       FROM conversation_reads
       WHERE user_id = $1 AND conversation_id = ANY($2::text[])`,
      [request.user.userId, conversationIds]
    );
    const readMap = new Map(reads.map((item) => [item.conversation_id, Number(item.last_read_seq || 0)]));

    const otherUserIds = new Set<string>();
    for (const conversation of conversations) {
      for (const memberId of conversation.memberIds || []) {
        if (memberId !== request.user.userId) {
          otherUserIds.add(memberId);
        }
      }
    }

    const otherUsers = await loadActiveUsers([...otherUserIds]);
    const userMap = new Map(otherUsers.map((user) => [user.user_id, user]));

    return conversations.map((conversation) =>
      conversationSummary(
        conversation,
        request.user.userId,
        userMap,
        readMap.get(conversation.conversationId) || 0
      )
    );
  });

  app.post("/requests/:conversationId/accept", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensure(conversation.type === "dm", 400, "Conversation is not a DM");
    ensure(conversation.dmRequestStatus === "pending", 400, "Message request is not pending");
    ensure(conversation.dmRequestRecipientUserId === request.user.userId, 403, "Only the recipient can accept this request");
    await ensureDmSendAllowed(conversation, request.user.userId);

    const ts = now();
    await query(
      `UPDATE conversations
       SET dm_request_status = 'active',
           dm_request_responded_at = $2,
           updated_at = $2
       WHERE conversation_id = $1`,
      [conversationId, ts]
    );

    publishToConversation(conversation.memberIds, "MESSAGE_REQUEST_ACCEPTED", {
      conversationId,
      acceptedBy: request.user.userId,
      acceptedAt: toIso(ts),
    });

    return {
      success: true,
      conversationId,
      requestStatus: "active",
    };
  });

  app.delete("/requests/:conversationId", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensure(conversation.type === "dm", 400, "Conversation is not a DM");
    ensure(conversation.dmRequestStatus === "pending", 400, "Message request is not pending");
    ensure(conversation.dmRequestRecipientUserId === request.user.userId, 403, "Only the recipient can remove this request");

    const ts = now();
    await query(
      `UPDATE conversations
       SET dm_request_status = 'declined',
           dm_request_responded_at = $2,
           updated_at = $2
       WHERE conversation_id = $1`,
      [conversationId, ts]
    );

    publishToConversation(conversation.memberIds, "MESSAGE_REQUEST_DECLINED", {
      conversationId,
      declinedBy: request.user.userId,
      declinedAt: toIso(ts),
    });

    return {
      success: true,
      conversationId,
      requestStatus: "declined",
    };
  });

  app.get("/settings", { preHandler: requireAuth }, async (request: any) => {
    const row = await queryOne(
      `SELECT settings FROM user_settings WHERE user_id = $1`,
      [request.user.userId]
    );
    const settings = row?.settings || {};

    return {
      readReceipts: settings.chatReadReceipts !== false && settings.readReceipts !== false,
      lastSeenVisibility: settings.chatLastSeenVisibility || "everyone",
      onlineStatusVisibility: settings.chatOnlineStatusVisibility || "everyone",
      typingIndicators: settings.chatTypingIndicators !== false,
      messagePreviewNotifications: settings.chatMessagePreviews !== false,
      notificationSound: settings.chatNotificationSound !== false && settings.inAppSounds !== false,
      vibration: settings.chatVibration !== false && settings.inAppHaptics !== false,
      groupNotifications: settings.chatGroupNotifications || "all",
      mediaAutoDownload: settings.chatMediaAutoDownload || "wifi",
      dataSavingMode: settings.chatDataSavingMode === true || settings.dataSaver === true,
      fontScale: Number(settings.chatFontScale || settings.textScale || 1),
      archivedBehavior: settings.chatArchivedBehavior || "keep_archived",
      securityNotice: "Messages are securely transmitted. End-to-end encryption is only shown when verified.",
    };
  });

  app.patch("/settings", { preHandler: requireAuth }, async (request: any) => {
    const body = request.body || {};
    const visibilityValues = new Set(["everyone", "contacts", "nobody"]);
    const groupNotificationValues = new Set(["all", "mentions", "muted"]);
    const mediaValues = new Set(["never", "wifi", "always"]);
    const archivedValues = new Set(["keep_archived", "unarchive_on_message"]);
    const patch: Record<string, unknown> = {};

    if (body.readReceipts !== undefined) patch.chatReadReceipts = body.readReceipts === true;
    if (body.typingIndicators !== undefined) patch.chatTypingIndicators = body.typingIndicators === true;
    if (body.messagePreviewNotifications !== undefined) patch.chatMessagePreviews = body.messagePreviewNotifications === true;
    if (body.notificationSound !== undefined) patch.chatNotificationSound = body.notificationSound === true;
    if (body.vibration !== undefined) patch.chatVibration = body.vibration === true;
    if (body.dataSavingMode !== undefined) patch.chatDataSavingMode = body.dataSavingMode === true;

    const lastSeenVisibility = normalizeString(body.lastSeenVisibility);
    if (lastSeenVisibility && visibilityValues.has(lastSeenVisibility)) {
      patch.chatLastSeenVisibility = lastSeenVisibility;
    }

    const onlineStatusVisibility = normalizeString(body.onlineStatusVisibility);
    if (onlineStatusVisibility && visibilityValues.has(onlineStatusVisibility)) {
      patch.chatOnlineStatusVisibility = onlineStatusVisibility;
    }

    const groupNotifications = normalizeString(body.groupNotifications);
    if (groupNotifications && groupNotificationValues.has(groupNotifications)) {
      patch.chatGroupNotifications = groupNotifications;
    }

    const mediaAutoDownload = normalizeString(body.mediaAutoDownload);
    if (mediaAutoDownload && mediaValues.has(mediaAutoDownload)) {
      patch.chatMediaAutoDownload = mediaAutoDownload;
    }

    const archivedBehavior = normalizeString(body.archivedBehavior);
    if (archivedBehavior && archivedValues.has(archivedBehavior)) {
      patch.chatArchivedBehavior = archivedBehavior;
    }

    if (body.fontScale !== undefined) {
      const scale = Number(body.fontScale);
      if (Number.isFinite(scale)) {
        patch.chatFontScale = Math.max(0.8, Math.min(1.4, scale));
      }
    }

    const ts = now();
    await query(
      `INSERT INTO user_settings (user_id, settings, updated_at)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id)
       DO UPDATE SET
         settings = COALESCE(user_settings.settings, '{}'::jsonb) || EXCLUDED.settings,
         updated_at = EXCLUDED.updated_at`,
      [request.user.userId, JSON.stringify(patch), ts]
    );

    return {
      success: true,
      updatedAt: toIso(ts),
      settings: patch,
    };
  });

  app.post("/attachments/upload-init", { preHandler: requireAuth }, async (request: any) => {
    const body = request.body || {};
    const conversationId = normalizeString(body.conversationId);
    if (conversationId) {
      const conversation = await loadConversationForUser(conversationId, request.user.userId);
      ensureConversationOpenForUser(conversation, request.user.userId);
    }

    const fileName = normalizeString(body.fileName).slice(0, 240);
    const mimeType = normalizeString(body.mimeType || "application/octet-stream")
      .toLowerCase()
      .slice(0, 160);
    const byteSize = Math.max(0, Math.trunc(Number(body.byteSize || 0)));
    const attachmentType = normalizeString(body.attachmentType || attachmentTypeFromMime(mimeType))
      .toLowerCase()
      .slice(0, 40);
    const maxBytes = attachmentType === "video"
      ? 100 * 1024 * 1024
      : attachmentType === "voice_note" || attachmentType === "audio"
        ? 25 * 1024 * 1024
        : 30 * 1024 * 1024;

    ensure(fileName.length > 0 && fileName.length <= 240, 400, "Invalid file name");
    ensure(mimeType.length > 0, 400, "Invalid MIME type");
    ensure(byteSize > 0 && byteSize <= maxBytes, 400, "Invalid file size");

    const attachmentId = generateId();
    const uploadSessionId = generateId();
    const ts = now();
    await query(
      `INSERT INTO chat_attachments (
         attachment_id, owner_user_id, conversation_id, upload_session_id,
         attachment_type, file_name, mime_type, byte_size, status, metadata,
         created_at, updated_at
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'pending', $9, $10, $11)`,
      [
        attachmentId,
        request.user.userId,
        conversationId || null,
        uploadSessionId,
        attachmentType || "file",
        fileName,
        mimeType,
        byteSize,
        JSON.stringify({
          uploadProvider: "media-service",
          maxBytes,
        }),
        ts,
        ts,
      ]
    );

    return {
      attachmentId,
      uploadSessionId,
      provider: "media-service",
      uploadUrl: "/api/media/upload",
      completeUrl: "/api/conversations/attachments/upload-complete",
      maxBytes,
      expiresAt: toIso(new Date(ts.getTime() + 30 * 60 * 1000)),
    };
  });

  app.post("/attachments/upload-complete", { preHandler: requireAuth }, async (request: any) => {
    const attachmentId = normalizeString(request.body?.attachmentId);
    const uploadSessionId = normalizeString(request.body?.uploadSessionId);
    const mediaAssetId = normalizeString(request.body?.mediaAssetId);
    ensure(attachmentId.length >= 8, 400, "Invalid attachment");
    ensure(uploadSessionId.length >= 8, 400, "Invalid upload session");
    ensure(mediaAssetId.length >= 3, 400, "Invalid media asset");

    await ensureOwnedMediaAsset(mediaAssetId, request.user.userId);
    const ts = now();
    const row = await queryOne(
      `UPDATE chat_attachments
       SET media_asset_id = $4,
           status = 'ready',
           updated_at = $5,
           metadata = $6::jsonb
       WHERE attachment_id = $1
         AND upload_session_id = $2
         AND owner_user_id = $3
         AND deleted_at IS NULL
       RETURNING *`,
      [
        attachmentId,
        uploadSessionId,
        request.user.userId,
        mediaAssetId,
        ts,
        JSON.stringify({ completedAt: toIso(ts) }),
      ]
    );
    if (!row) {
      throw new HttpError(404, "Attachment upload session not found");
    }

    return {
      success: true,
      attachment: mapChatAttachment(row),
    };
  });

  app.get("/:conversationId/attachments", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensureConversationOpenForUser(conversation, request.user.userId);
    const limit = parseLimit(request.query?.limit, 30, 1, 100);
    const attachmentType = normalizeString(request.query?.type).toLowerCase();
    const params: unknown[] = [conversationId, limit];
    let typeClause = "";
    if (attachmentType) {
      params.push(attachmentType);
      typeClause = `AND attachment_type = $${params.length}`;
    }

    const rows = await queryMany(
      `SELECT *
       FROM chat_attachments
       WHERE conversation_id = $1
         AND deleted_at IS NULL
         AND status IN ('ready', 'attached')
         ${typeClause}
       ORDER BY created_at DESC
       LIMIT $2`,
      params
    );

    return {
      items: rows.map(mapChatAttachment),
    };
  });

  app.delete("/attachments/:attachmentId", { preHandler: requireAuth }, async (request: any) => {
    const attachmentId = normalizeString(request.params.attachmentId);
    ensure(attachmentId.length >= 8, 400, "Invalid attachment");

    const ts = now();
    const row = await queryOne(
      `UPDATE chat_attachments
       SET status = 'deleted',
           deleted_at = $3,
           updated_at = $3
       WHERE attachment_id = $1
         AND owner_user_id = $2
         AND deleted_at IS NULL
       RETURNING *`,
      [attachmentId, request.user.userId, ts]
    );
    if (!row) {
      throw new HttpError(404, "Attachment not found");
    }

    return {
      success: true,
      attachment: mapChatAttachment(row),
    };
  });

  app.get("/groups/:conversationId/invites", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    await ensureGroupConversationForAdmin(conversationId, request.user.userId);
    const rows = await queryMany(
      `SELECT *
       FROM group_invites
       WHERE conversation_id = $1
       ORDER BY created_at DESC
       LIMIT 50`,
      [conversationId]
    );
    return { items: rows.map(mapGroupInvite) };
  });

  app.post("/groups/:conversationId/invites", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    const { conversation, groupMeta } = await ensureGroupConversationForAdmin(
      conversationId,
      request.user.userId
    );

    const maxUsesRaw = Number.parseInt(String(request.body?.maxUses || ""), 10);
    const maxUses = Number.isNaN(maxUsesRaw)
      ? null
      : Math.max(1, Math.min(10_000, maxUsesRaw));
    const expiresInHoursRaw = Number.parseInt(String(request.body?.expiresInHours || ""), 10);
    const expiresAt = Number.isNaN(expiresInHoursRaw)
      ? null
      : new Date(Date.now() + Math.max(1, Math.min(24 * 90, expiresInHoursRaw)) * 60 * 60 * 1000);
    const requiresApproval = request.body?.requiresApproval === true;
    const inviteId = generateId();
    const inviteToken = generateId();
    const ts = now();

    const row = await queryOne(
      `INSERT INTO group_invites (
         invite_id, conversation_id, invite_token, created_by_user_id,
         max_uses, use_count, requires_approval, status, expires_at, created_at
       )
       VALUES ($1, $2, $3, $4, $5, 0, $6, 'active', $7, $8)
       RETURNING *`,
      [
        inviteId,
        conversationId,
        inviteToken,
        request.user.userId,
        maxUses,
        requiresApproval,
        expiresAt,
        ts,
      ]
    );

    publishToConversation(groupMeta.memberIds, "GROUP_INVITE_CREATED", {
      conversationId,
      inviteId,
      createdBy: request.user.userId,
      requiresApproval,
    });

    return {
      invite: mapGroupInvite(row),
      joinUrl: `/chat/groups/join/${inviteToken}`,
      conversationTitle: conversation.title || "Group",
    };
  });

  app.delete("/groups/:conversationId/invites/:inviteId", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    const inviteId = normalizeString(request.params.inviteId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    ensure(inviteId.length >= 8, 400, "Invalid invite");
    const { groupMeta } = await ensureGroupConversationForAdmin(
      conversationId,
      request.user.userId
    );

    const ts = now();
    const row = await queryOne(
      `UPDATE group_invites
       SET status = 'revoked',
           revoked_at = $3
       WHERE conversation_id = $1
         AND invite_id = $2
         AND status = 'active'
       RETURNING *`,
      [conversationId, inviteId, ts]
    );
    if (!row) {
      throw new HttpError(404, "Invite not found");
    }

    publishToConversation(groupMeta.memberIds, "GROUP_INVITE_REVOKED", {
      conversationId,
      inviteId,
      revokedBy: request.user.userId,
      revokedAt: toIso(ts),
    });

    return {
      success: true,
      invite: mapGroupInvite(row),
    };
  });

  app.post("/groups/join/:inviteToken", { preHandler: requireAuth }, async (request: any) => {
    const inviteToken = normalizeString(request.params.inviteToken);
    ensure(inviteToken.length >= 8, 400, "Invalid invite");

    const invite = await queryOne(
      `SELECT gi.*, c.title, c.type
       FROM group_invites gi
       JOIN conversations c ON c.conversation_id = gi.conversation_id
       WHERE gi.invite_token = $1
         AND gi.status = 'active'
       LIMIT 1`,
      [inviteToken]
    );
    if (!invite || invite.type !== "group") {
      throw new HttpError(404, "Invite not found");
    }
    if (invite.expires_at && new Date(invite.expires_at).getTime() < Date.now()) {
      throw new HttpError(410, "Invite expired");
    }
    if (invite.max_uses != null && Number(invite.use_count || 0) >= Number(invite.max_uses)) {
      throw new HttpError(410, "Invite usage limit reached");
    }

    const conversationId = String(invite.conversation_id);
    const conversation = await loadConversationForUserOrNull(conversationId, request.user.userId);
    if (conversation) {
      return {
        success: true,
        status: "joined",
        conversationId,
        alreadyMember: true,
      };
    }

    const ts = now();
    if (invite.requires_approval === true) {
      const requestId = generateId();
      const row = await queryOne(
        `INSERT INTO group_join_requests (
           request_id, invite_id, conversation_id, requester_user_id,
           status, created_at
         )
         VALUES ($1, $2, $3, $4, 'pending', $5)
         ON CONFLICT (conversation_id, requester_user_id, status)
         DO UPDATE SET invite_id = EXCLUDED.invite_id
         RETURNING *`,
        [requestId, invite.invite_id, conversationId, request.user.userId, ts]
      );

      const fullConversation = await queryOne(
        `SELECT c.*
         FROM conversations c
         WHERE c.conversation_id = $1`,
        [conversationId]
      );
      const hydrated = fullConversation ? await hydrateConversations([fullConversation]) : [];
      const memberIds = hydrated[0]?.memberIds || [];
      publishToConversation(memberIds, "GROUP_JOIN_REQUEST_CREATED", {
        conversationId,
        requestId: row.request_id,
        requesterUserId: request.user.userId,
      });

      return {
        success: true,
        status: "pending",
        request: mapJoinRequest(row),
      };
    }

    await withTransaction(async (client) => {
      await client.query(
        `INSERT INTO conversation_members (conversation_id, user_id, role, joined_at, left_at)
         VALUES ($1, $2, 'member', $3, NULL)
         ON CONFLICT (conversation_id, user_id)
         DO UPDATE SET role = 'member', joined_at = EXCLUDED.joined_at, left_at = NULL`,
        [conversationId, request.user.userId, ts]
      );
      await client.query(
        `UPDATE group_invites SET use_count = use_count + 1 WHERE invite_id = $1`,
        [invite.invite_id]
      );
      await client.query(
        `UPDATE conversations SET updated_at = $2 WHERE conversation_id = $1`,
        [conversationId, ts]
      );
    });

    const loaded = await loadConversationForUser(conversationId, request.user.userId);
    publishToConversation(loaded.memberIds, "GROUP_MEMBER_ADDED", {
      conversationId,
      addedBy: request.user.userId,
      memberIds: [request.user.userId],
      viaInvite: true,
    });

    return {
      success: true,
      status: "joined",
      conversationId,
    };
  });

  app.get("/groups/:conversationId/join-requests", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    await ensureGroupConversationForAdmin(conversationId, request.user.userId);
    const rows = await queryMany(
      `SELECT *
       FROM group_join_requests
       WHERE conversation_id = $1
         AND status = 'pending'
       ORDER BY created_at ASC
       LIMIT 100`,
      [conversationId]
    );
    return { items: rows.map(mapJoinRequest) };
  });

  app.post("/groups/:conversationId/join-requests/:requestId/approve", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    const requestId = normalizeString(request.params.requestId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    ensure(requestId.length >= 8, 400, "Invalid request");
    const { groupMeta } = await ensureGroupConversationForAdmin(
      conversationId,
      request.user.userId
    );

    const joinRequest = await queryOne(
      `SELECT *
       FROM group_join_requests
       WHERE conversation_id = $1
         AND request_id = $2
         AND status = 'pending'`,
      [conversationId, requestId]
    );
    if (!joinRequest) {
      throw new HttpError(404, "Join request not found");
    }

    const ts = now();
    await withTransaction(async (client) => {
      await client.query(
        `UPDATE group_join_requests
         SET status = 'approved',
             decided_by_user_id = $3,
             decided_at = $4
         WHERE conversation_id = $1 AND request_id = $2`,
        [conversationId, requestId, request.user.userId, ts]
      );
      await client.query(
        `INSERT INTO conversation_members (conversation_id, user_id, role, joined_at, left_at)
         VALUES ($1, $2, 'member', $3, NULL)
         ON CONFLICT (conversation_id, user_id)
         DO UPDATE SET role = 'member', joined_at = EXCLUDED.joined_at, left_at = NULL`,
        [conversationId, joinRequest.requester_user_id, ts]
      );
      if (joinRequest.invite_id) {
        await client.query(
          `UPDATE group_invites SET use_count = use_count + 1 WHERE invite_id = $1`,
          [joinRequest.invite_id]
        );
      }
      await client.query(
        `UPDATE conversations SET updated_at = $2 WHERE conversation_id = $1`,
        [conversationId, ts]
      );
    });

    const memberIds = [...new Set([...groupMeta.memberIds, joinRequest.requester_user_id])];
    publishToConversation(memberIds, "GROUP_JOIN_REQUEST_APPROVED", {
      conversationId,
      requestId,
      requesterUserId: joinRequest.requester_user_id,
      approvedBy: request.user.userId,
    });

    return {
      success: true,
      requestId,
      status: "approved",
      userId: joinRequest.requester_user_id,
    };
  });

  app.post("/groups/:conversationId/join-requests/:requestId/reject", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    const requestId = normalizeString(request.params.requestId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    ensure(requestId.length >= 8, 400, "Invalid request");
    const { groupMeta } = await ensureGroupConversationForAdmin(
      conversationId,
      request.user.userId
    );

    const ts = now();
    const row = await queryOne(
      `UPDATE group_join_requests
       SET status = 'rejected',
           decided_by_user_id = $3,
           decided_at = $4
       WHERE conversation_id = $1
         AND request_id = $2
         AND status = 'pending'
       RETURNING *`,
      [conversationId, requestId, request.user.userId, ts]
    );
    if (!row) {
      throw new HttpError(404, "Join request not found");
    }

    publishToConversation([...groupMeta.memberIds, row.requester_user_id], "GROUP_JOIN_REQUEST_REJECTED", {
      conversationId,
      requestId,
      requesterUserId: row.requester_user_id,
      rejectedBy: request.user.userId,
    });

    return {
      success: true,
      request: mapJoinRequest(row),
    };
  });

  app.patch("/groups/:conversationId/members/:memberUserId/role", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    const memberUserId = normalizeString(request.params.memberUserId);
    const role = normalizeString(request.body?.role).toLowerCase();
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    ensure(memberUserId.length >= 8, 400, "Invalid user");
    ensure(["admin", "member"].includes(role), 400, "Invalid role");

    const { groupMeta } = await ensureGroupConversationForAdmin(
      conversationId,
      request.user.userId
    );
    ensure(groupMeta.memberIds.includes(memberUserId), 404, "Member not found");
    ensure(memberUserId !== groupMeta.ownerUserId, 400, "Owner role cannot be changed");
    if (role === "admin" || groupMeta.adminIds.includes(memberUserId)) {
      ensure(request.user.userId === groupMeta.ownerUserId, 403, "Only owner can change admin roles");
    }

    const ts = now();
    await query(
      `UPDATE conversation_members
       SET role = $3
       WHERE conversation_id = $1
         AND user_id = $2
         AND left_at IS NULL`,
      [conversationId, memberUserId, role]
    );
    await query(
      `UPDATE conversations SET updated_at = $2 WHERE conversation_id = $1`,
      [conversationId, ts]
    );

    publishToConversation(groupMeta.memberIds, "GROUP_MEMBER_ROLE", {
      conversationId,
      changedBy: request.user.userId,
      userId: memberUserId,
      role,
    });

    return {
      success: true,
      conversationId,
      userId: memberUserId,
      role,
    };
  });

  app.put("/:conversationId/preferences", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    await loadConversationForUser(conversationId, request.user.userId);

    const incoming = request.body || {};
    const current = await loadPreference(conversationId, request.user.userId);
    const patch: ConversationPreferencePatch = {
      isFavorite: boolOrCurrent(incoming.isFavorite, current.isFavorite),
      isStarred: boolOrCurrent(incoming.isStarred, current.isStarred),
      isMuted: boolOrCurrent(incoming.isMuted, current.isMuted),
      isArchived: boolOrCurrent(incoming.isArchived, current.isArchived),
      markedUnread: boolOrCurrent(incoming.markedUnread, current.markedUnread),
    };
    if (incoming.draftText !== undefined) {
      patch.draftText = incoming.draftText;
    }

    const preferences = await savePreference(conversationId, request.user.userId, patch);

    return {
      success: true,
      preferences,
    };
  });

  app.post("/:conversationId/archive", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    const preferences = await setConversationFlag(conversationId, request.user.userId, {
      isArchived: true,
    });
    return { success: true, preferences };
  });

  app.post("/:conversationId/unarchive", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    const preferences = await setConversationFlag(conversationId, request.user.userId, {
      isArchived: false,
    });
    return { success: true, preferences };
  });

  app.post("/:conversationId/pin", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    const preferences = await setConversationFlag(conversationId, request.user.userId, {
      isStarred: true,
    });
    return { success: true, preferences };
  });

  app.post("/:conversationId/unpin", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    const preferences = await setConversationFlag(conversationId, request.user.userId, {
      isStarred: false,
    });
    return { success: true, preferences };
  });

  app.post("/:conversationId/favourite", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    const preferences = await setConversationFlag(conversationId, request.user.userId, {
      isFavorite: true,
    });
    return { success: true, preferences };
  });

  app.post("/:conversationId/unfavourite", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    const preferences = await setConversationFlag(conversationId, request.user.userId, {
      isFavorite: false,
    });
    return { success: true, preferences };
  });

  app.post("/:conversationId/mute", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    const preferences = await setConversationFlag(conversationId, request.user.userId, {
      isMuted: true,
    });
    return { success: true, preferences };
  });

  app.post("/:conversationId/unmute", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    const preferences = await setConversationFlag(conversationId, request.user.userId, {
      isMuted: false,
    });
    return { success: true, preferences };
  });

  app.post("/:conversationId/clear-local", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensureConversationOpenForUser(conversation, request.user.userId);
    const clearedBeforeSeq = Number(conversation.seqCounter || 0);
    const preferences = await savePreference(conversationId, request.user.userId, {
      clearedBeforeSeq,
      localDeletedAt: null,
      markedUnread: false,
      draftText: "",
    });

    return {
      success: true,
      conversationId,
      clearedBeforeSeq,
      preferences,
    };
  });

  app.delete("/:conversationId", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensureConversationOpenForUser(conversation, request.user.userId);
    const clearedBeforeSeq = Number(conversation.seqCounter || 0);
    const deletedAt = now();
    const preferences = await savePreference(conversationId, request.user.userId, {
      clearedBeforeSeq,
      localDeletedAt: deletedAt,
      isArchived: false,
      markedUnread: false,
      draftText: "",
    });

    return {
      success: true,
      conversationId,
      localDeletedAt: toIso(deletedAt),
      clearedBeforeSeq,
      preferences,
    };
  });

  app.post("/:conversationId/mark-unread", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensureConversationOpenForUser(conversation, request.user.userId);
    const targetReadSeq = Math.max(0, Number(conversation.seqCounter || 0) - 1);
    await upsertReadState(conversation, request.user.userId, {
      lastReadSeq: targetReadSeq,
    });
    const preferences = await savePreference(conversationId, request.user.userId, {
      markedUnread: true,
    });

    return {
      success: true,
      conversationId,
      unreadCount: Number(conversation.seqCounter || 0) > 0 ? 1 : 0,
      preferences,
    };
  });

  app.post("/report", { preHandler: requireAuth }, async (request: any) => {
    const body = request.body || {};
    let conversationId = normalizeString(body.conversationId);
    const messageId = normalizeString(body.messageId);
    const reportedUserId = normalizeString(body.reportedUserId);
    const reason = normalizeString(body.reason || "other").slice(0, 80) || "other";
    const details = normalizeString(body.details).slice(0, 4000);

    if (!conversationId && messageId) {
      const messageRow = await queryOne(
        `SELECT conversation_id FROM messages WHERE message_id = $1`,
        [messageId]
      );
      conversationId = normalizeString(messageRow?.conversation_id);
    }

    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensureConversationOpenForUser(conversation, request.user.userId);

    if (messageId) {
      const message = await queryOne(
        `SELECT message_id FROM messages WHERE conversation_id = $1 AND message_id = $2`,
        [conversationId, messageId]
      );
      ensure(!!message, 404, "Message not found");
    }

    if (reportedUserId) {
      const reportedUser = await queryOne(
        `SELECT user_id FROM users WHERE user_id = $1 AND deleted_at IS NULL`,
        [reportedUserId]
      );
      ensure(!!reportedUser, 404, "Reported user not found");
    }

    const reportId = generateId();
    const ts = now();
    await query(
      `INSERT INTO chat_reports (
         report_id, reporter_user_id, conversation_id, message_id,
         reported_user_id, reason, details, status, created_at
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, 'open', $8)`,
      [
        reportId,
        request.user.userId,
        conversationId,
        messageId || null,
        reportedUserId || null,
        reason,
        details,
        ts,
      ]
    );

    return {
      success: true,
      reportId,
      status: "open",
      createdAt: toIso(ts),
    };
  });

  app.get("/:conversationId/search", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensureConversationOpenForUser(conversation, request.user.userId);
    const preference = await loadPreference(conversationId, request.user.userId);

    const q = normalizeString(request.query?.q).slice(0, 120);
    ensure(q.length >= 2, 400, "Search query is too short");
    const limit = parseLimit(request.query?.limit, 30, 1, 80);

    const messages = await queryMany(
      `SELECT *
       FROM messages
       WHERE conversation_id = $1
         AND seq > $4
         AND deleted_for_all_at IS NULL
         AND COALESCE(body, '') ILIKE $2
       ORDER BY seq DESC
       LIMIT $3`,
      [conversationId, `%${q}%`, limit, preference.clearedBeforeSeq]
    );

    return {
      query: q,
      results: await loadMessagesWithReactions(messages),
    };
  });

  app.get("/:conversationId/pinned-messages", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensureConversationOpenForUser(conversation, request.user.userId);
    const preference = await loadPreference(conversationId, request.user.userId);
    const limit = parseLimit(request.query?.limit, 30, 1, 80);

    const rows = await queryMany(
      `SELECT m.*, cpm.pinned_by_user_id, cpm.pinned_at
       FROM chat_pinned_messages cpm
       JOIN messages m ON m.message_id = cpm.message_id
       WHERE cpm.conversation_id = $1
         AND m.seq > $3
       ORDER BY cpm.pinned_at DESC
       LIMIT $2`,
      [conversationId, limit, preference.clearedBeforeSeq]
    );
    const messages = await loadMessagesWithReactions(rows);

    return messages.map((message, index) => ({
      ...message,
      pinnedByUserId: rows[index]?.pinned_by_user_id || null,
      pinnedAt: toIso(rows[index]?.pinned_at),
    }));
  });

  app.get("/:conversationId", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensureConversationOpenForUser(conversation, request.user.userId);
    const groupMeta = conversation.type === "group" ? getGroupMeta(conversation) : null;

    let title = conversation.title || "Conversation";
    if (conversation.type === "dm") {
      const peerId = (conversation.memberIds || []).find((id) => id !== request.user.userId);
      if (peerId) {
        const peer = await queryOne(
          `SELECT username, display_name FROM users WHERE user_id = $1`,
          [peerId]
        );
        title = userDisplayName(peer);
      }
    }

    return {
      id: conversation.conversationId,
      type: conversation.type,
      title,
      createdBy: conversation.ownerUserId || null,
      createdAt: toIso(conversation.createdAt),
      updatedAt: toIso(conversation.updatedAt),
      memberCount: Array.isArray(conversation.memberIds) ? conversation.memberIds.length : 0,
      isAdmin: groupMeta ? isGroupAdmin(groupMeta, request.user.userId) : false,
      myRole: groupMeta ? roleForUser(groupMeta, request.user.userId) : "member",
      lastMessageId: conversation.lastMessageId || null,
      lastMessageSeq: conversation.lastMessageSeq ?? null,
      lastMessageSenderUserId: conversation.lastMessageSenderUserId || null,
      lastMessageBody: conversation.lastMessageBody || null,
      lastMessageContentType: conversation.lastMessageContentType || null,
      lastMessageDeletedForAllAt: toIso(conversation.lastMessageDeletedForAllAt),
      lastMessageCreatedAt: toIso(conversation.lastMessageCreatedAt),
    };
  });

  app.post("/dm", { preHandler: requireAuth }, async (request: any) => {
    const otherUserId = normalizeString(request.body?.otherUserId);
    ensure(otherUserId.length >= 8, 400, "Invalid user");
    ensure(otherUserId !== request.user.userId, 400, "Cannot create DM with self");

    await ensureUserExists(otherUserId);
    const sendPolicy = await canSendDirectMessage(request.user.userId, otherUserId);
    ensure(sendPolicy.allowed, 403, "User interaction is blocked");

    const memberIds = [request.user.userId, otherUserId].sort();
    const memberHash = normalizeMemberHash(memberIds);
    const ts = now();
    const isFriend = await areMutualFollowers(request.user.userId, otherUserId);
    const requestStatus = isFriend ? "active" : "pending";

    const result = await withTransaction(async (client) => {
      const inserted = await client.query(
        `INSERT INTO conversations (
           conversation_id, type, title, member_hash, owner_user_id, seq_counter,
           dm_request_status, dm_request_sender_user_id, dm_request_recipient_user_id,
           created_at, updated_at
         )
         VALUES ($1, 'dm', NULL, $2, $3, 0, $4, $5, $6, $7, $8)
         ON CONFLICT (member_hash) DO NOTHING
         RETURNING conversation_id`,
        [
          generateId(),
          memberHash,
          memberIds[0] || request.user.userId,
          requestStatus,
          requestStatus === "pending" ? request.user.userId : null,
          requestStatus === "pending" ? otherUserId : null,
          ts,
          ts,
        ]
      );

      let conversationId = inserted.rows[0]?.conversation_id;
      const created = (inserted.rowCount || 0) > 0;
      if (!conversationId) {
        const existing = await client.query(
          `SELECT conversation_id FROM conversations WHERE type = 'dm' AND member_hash = $1`,
          [memberHash]
        );
        conversationId = existing.rows[0]?.conversation_id;
      }

      if (!conversationId) {
        throw new HttpError(500, "Failed to create conversation");
      }

      if (!created && isFriend) {
        await client.query(
          `UPDATE conversations
           SET dm_request_status = 'active',
               dm_request_responded_at = $2,
               updated_at = $2
           WHERE conversation_id = $1
             AND type = 'dm'
             AND dm_request_status <> 'active'`,
          [conversationId, ts]
        );
      }

      for (const memberId of memberIds) {
        await client.query(
          `INSERT INTO conversation_members (conversation_id, user_id, role, joined_at, left_at)
           VALUES ($1, $2, 'member', $3, NULL)
           ON CONFLICT (conversation_id, user_id)
           DO UPDATE SET left_at = NULL`,
          [conversationId, memberId, ts]
        );
      }

      const statusRow = await client.query(
        `SELECT dm_request_status FROM conversations WHERE conversation_id = $1`,
        [conversationId]
      );

      return {
        conversationId,
        created,
        requestStatus: statusRow.rows[0]?.dm_request_status || requestStatus,
      };
    });

    return result;
  });

  app.post("/group", { preHandler: requireAuth }, async (request: any) => {
    const title = normalizeString(request.body?.title).slice(0, 120);
    const memberIds = [...new Set([request.user.userId, ...normalizeIdList(request.body?.memberIds)])];

    ensure(memberIds.length >= 2, 400, "Group must have at least 2 members");
    ensure(memberIds.length <= 1024, 400, "Group member limit exceeded");
    ensure(title.length > 0 && title.length <= 120, 400, "Invalid title");

    const memberPlaceholders = memberIds.map((_, index) => `$${index + 1}`).join(", ");
    const users = await queryMany(
      `SELECT user_id FROM users WHERE user_id IN (${memberPlaceholders}) AND deleted_at IS NULL`,
      memberIds
    );
    ensure(users.length === memberIds.length, 400, "One or more members not found");

    const ts = now();
    const conversationId = generateId();
    await withTransaction(async (client) => {
      await client.query(
        `INSERT INTO conversations (
           conversation_id, type, title, member_hash, owner_user_id, seq_counter,
           created_at, updated_at
         )
         VALUES ($1, 'group', $2, NULL, $3, 0, $4, $5)`,
        [conversationId, title, request.user.userId, ts, ts]
      );

      for (const memberId of memberIds) {
        await client.query(
          `INSERT INTO conversation_members (conversation_id, user_id, role, joined_at, left_at)
           VALUES ($1, $2, $3, $4, NULL)`,
          [conversationId, memberId, memberId === request.user.userId ? "owner" : "member", ts]
        );
      }
    });

    return { conversationId };
  });

  app.patch("/:conversationId", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensure(conversation.type === "group", 400, "Conversation is not a group");

    const groupMeta = getGroupMeta(conversation);
    ensure(isGroupAdmin(groupMeta, request.user.userId), 403, "Admin privileges required");

    const title = normalizeString(request.body?.title).slice(0, 120);
    ensure(title.length > 0, 400, "Invalid title");

    const ts = now();
    await query(
      `UPDATE conversations SET title = $2, updated_at = $3 WHERE conversation_id = $1`,
      [conversationId, title, ts]
    );

    publishToConversation(groupMeta.memberIds, "CONVERSATION_UPDATED", {
      conversationId,
      title,
      updatedAt: toIso(ts),
    });

    return {
      success: true,
      conversationId,
      title,
      updatedAt: toIso(ts),
    };
  });

  app.post("/:conversationId/members", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensure(conversation.type === "group", 400, "Conversation is not a group");

    const groupMeta = getGroupMeta(conversation);
    ensure(isGroupAdmin(groupMeta, request.user.userId), 403, "Admin privileges required");

    const incoming = normalizeIdList(request.body?.memberIds)
      .filter((id) => id !== request.user.userId);
    ensure(incoming.length > 0, 400, "No members to add");

    const existingSet = new Set(groupMeta.memberIds);
    const added = incoming.filter((id) => !existingSet.has(id));
    ensure(added.length > 0, 400, "No new members were added");
    ensure(groupMeta.memberIds.length + added.length <= 1024, 400, "Group member limit exceeded");

    const addedPlaceholders = added.map((_, index) => `$${index + 1}`).join(", ");
    const users = await queryMany(
      `SELECT user_id FROM users WHERE user_id IN (${addedPlaceholders}) AND deleted_at IS NULL`,
      added
    );
    ensure(users.length === added.length, 400, "One or more members not found");

    const ts = now();
    await withTransaction(async (client) => {
      for (const memberId of added) {
        await client.query(
          `INSERT INTO conversation_members (conversation_id, user_id, role, joined_at, left_at)
           VALUES ($1, $2, 'member', $3, NULL)
           ON CONFLICT (conversation_id, user_id)
           DO UPDATE SET role = 'member', joined_at = EXCLUDED.joined_at, left_at = NULL`,
          [conversationId, memberId, ts]
        );
      }

      await client.query(
        `UPDATE conversations SET updated_at = $2 WHERE conversation_id = $1`,
        [conversationId, ts]
      );
    });

    const memberIds = [...groupMeta.memberIds, ...added];
    publishToConversation(memberIds, "GROUP_MEMBER_ADDED", {
      conversationId,
      addedBy: request.user.userId,
      memberIds: added,
    });

    return {
      success: true,
      conversationId,
      added,
      memberCount: memberIds.length,
    };
  });

  app.delete("/:conversationId/members/:memberUserId", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    const memberUserId = normalizeString(request.params.memberUserId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    ensure(memberUserId.length >= 8, 400, "Invalid user");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensure(conversation.type === "group", 400, "Conversation is not a group");

    const groupMeta = getGroupMeta(conversation);
    ensure(groupMeta.memberIds.includes(memberUserId), 404, "Member not found");

    const selfLeave = memberUserId === request.user.userId;
    if (!selfLeave) {
      ensure(isGroupAdmin(groupMeta, request.user.userId), 403, "Admin privileges required");
      if (memberUserId === groupMeta.ownerUserId) {
        throw new HttpError(403, "Cannot remove group owner");
      }
      if (groupMeta.adminIds.includes(memberUserId) && request.user.userId !== groupMeta.ownerUserId) {
        throw new HttpError(403, "Only owner can remove admins");
      }
    }

    const remainingIds = groupMeta.memberIds.filter((id) => id !== memberUserId);
    const remainingAdmins = groupMeta.adminIds.filter((id) => id !== memberUserId);
    let ownerUserId = groupMeta.ownerUserId;

    if (memberUserId === ownerUserId) {
      ownerUserId = remainingAdmins[0] || remainingIds[0] || "";
      if (ownerUserId && !remainingAdmins.includes(ownerUserId)) {
        remainingAdmins.push(ownerUserId);
      }
    }

    const ts = now();
    await withTransaction(async (client) => {
      await client.query(
        `UPDATE conversation_members
         SET left_at = $3, role = 'member'
         WHERE conversation_id = $1 AND user_id = $2`,
        [conversationId, memberUserId, ts]
      );

      for (const memberId of remainingIds) {
        const role = memberId === ownerUserId
          ? "owner"
          : (remainingAdmins.includes(memberId) ? "admin" : "member");
        await client.query(
          `UPDATE conversation_members
           SET role = $3
           WHERE conversation_id = $1 AND user_id = $2 AND left_at IS NULL`,
          [conversationId, memberId, role]
        );
      }

      await client.query(
        `UPDATE conversations
         SET owner_user_id = $2, updated_at = $3
         WHERE conversation_id = $1`,
        [conversationId, ownerUserId || null, ts]
      );
    });

    publishToConversation(remainingIds, "GROUP_MEMBER_REMOVED", {
      conversationId,
      removedBy: request.user.userId,
      memberUserId,
      removedAt: toIso(ts),
    });

    return {
      success: true,
      conversationId,
      removedUserId: memberUserId,
      left: selfLeave,
    };
  });

  app.post("/:conversationId/leave", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const memberUserId = request.user.userId;
    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensure(conversation.type === "group", 400, "Conversation is not a group");

    const groupMeta = getGroupMeta(conversation);
    ensure(groupMeta.memberIds.includes(memberUserId), 403, "Not a member");

    const remainingIds = groupMeta.memberIds.filter((id) => id !== memberUserId);
    const remainingAdmins = groupMeta.adminIds.filter((id) => id !== memberUserId);
    let ownerUserId = groupMeta.ownerUserId;

    if (memberUserId === ownerUserId) {
      ownerUserId = remainingAdmins[0] || remainingIds[0] || "";
      if (ownerUserId && !remainingAdmins.includes(ownerUserId)) {
        remainingAdmins.push(ownerUserId);
      }
    }

    const ts = now();
    await withTransaction(async (client) => {
      await client.query(
        `UPDATE conversation_members
         SET left_at = $3, role = 'member'
         WHERE conversation_id = $1 AND user_id = $2`,
        [conversationId, memberUserId, ts]
      );

      for (const memberId of remainingIds) {
        const role = memberId === ownerUserId
          ? "owner"
          : (remainingAdmins.includes(memberId) ? "admin" : "member");
        await client.query(
          `UPDATE conversation_members
           SET role = $3
           WHERE conversation_id = $1 AND user_id = $2 AND left_at IS NULL`,
          [conversationId, memberId, role]
        );
      }

      await client.query(
        `UPDATE conversations
         SET owner_user_id = $2, updated_at = $3
         WHERE conversation_id = $1`,
        [conversationId, ownerUserId || null, ts]
      );
    });

    publishToConversation(remainingIds, "GROUP_MEMBER_LEFT", {
      conversationId,
      userId: memberUserId,
      leftAt: toIso(ts),
    });

    return {
      success: true,
      conversationId,
    };
  });

  app.post("/:conversationId/admins", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    const userId = normalizeString(request.body?.userId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    ensure(userId.length >= 8, 400, "Invalid user");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensure(conversation.type === "group", 400, "Conversation is not a group");
    const groupMeta = getGroupMeta(conversation);
    ensure(isGroupAdmin(groupMeta, request.user.userId), 403, "Admin privileges required");
    ensure(groupMeta.memberIds.includes(userId), 404, "Member not found");
    ensure(userId !== groupMeta.ownerUserId, 400, "Owner role cannot be changed");

    const ts = now();
    await query(
      `UPDATE conversation_members
       SET role = 'admin'
       WHERE conversation_id = $1 AND user_id = $2 AND left_at IS NULL`,
      [conversationId, userId]
    );
    await query(
      `UPDATE conversations SET updated_at = $2 WHERE conversation_id = $1`,
      [conversationId, ts]
    );

    publishToConversation(groupMeta.memberIds, "GROUP_MEMBER_ROLE", {
      conversationId,
      changedBy: request.user.userId,
      userId,
      role: "admin",
    });

    return {
      success: true,
      conversationId,
      userId,
      role: "admin",
    };
  });

  app.delete("/:conversationId/admins/:memberUserId", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    const memberUserId = normalizeString(request.params.memberUserId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    ensure(memberUserId.length >= 8, 400, "Invalid user");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensure(conversation.type === "group", 400, "Conversation is not a group");
    const groupMeta = getGroupMeta(conversation);
    ensure(request.user.userId === groupMeta.ownerUserId, 403, "Only owner can remove admins");
    ensure(groupMeta.adminIds.includes(memberUserId), 400, "Member is not an admin");
    ensure(memberUserId !== groupMeta.ownerUserId, 400, "Cannot demote owner");

    const ts = now();
    await query(
      `UPDATE conversation_members
       SET role = 'member'
       WHERE conversation_id = $1 AND user_id = $2 AND left_at IS NULL`,
      [conversationId, memberUserId]
    );
    await query(
      `UPDATE conversations SET updated_at = $2 WHERE conversation_id = $1`,
      [conversationId, ts]
    );

    publishToConversation(groupMeta.memberIds, "GROUP_MEMBER_ROLE", {
      conversationId,
      changedBy: request.user.userId,
      userId: memberUserId,
      role: "member",
    });

    return {
      success: true,
      conversationId,
      userId: memberUserId,
      role: "member",
    };
  });

  app.get("/:conversationId/members", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    const groupMeta = getGroupMeta(conversation);
    return (conversation.members || []).map((member) => ({
      userId: member.userId,
      role: conversation.type === "group" ? roleForUser(groupMeta, member.userId) : "member",
      joinedAt: toIso(member.joinedAt),
      leftAt: toIso(member.leftAt),
    }));
  });

  app.get("/:conversationId/messages", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensureConversationOpenForUser(conversation, request.user.userId);
    const preference = await loadPreference(conversationId, request.user.userId);

    const limit = parseLimit(request.query?.limit, 50, 1, 100);
    const params: unknown[] = [conversationId, preference.clearedBeforeSeq];
    let where = "conversation_id = $1 AND seq > $2";
    const beforeSeqRaw = request.query?.beforeSeq;
    if (beforeSeqRaw !== undefined) {
      const beforeSeq = Number.parseInt(String(beforeSeqRaw), 10);
      if (!Number.isNaN(beforeSeq) && beforeSeq > 0) {
        params.push(beforeSeq);
        where += ` AND seq < $${params.length}`;
      }
    }
    params.push(limit);

    const messages = await queryMany(
      `SELECT *
       FROM messages
       WHERE ${where}
       ORDER BY seq DESC
       LIMIT $${params.length}`,
      params
    );

    return (await loadMessagesWithReactions(messages.reverse()));
  });

  app.get("/:conversationId/messages/:messageId/details", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    const messageId = normalizeString(request.params.messageId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    ensure(messageId.length >= 8, 400, "Invalid message");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensureConversationOpenForUser(conversation, request.user.userId);
    const preference = await loadPreference(conversationId, request.user.userId);

    const row = await queryOne(
      `SELECT * FROM messages WHERE conversation_id = $1 AND message_id = $2`,
      [conversationId, messageId]
    );
    if (!row) {
      throw new HttpError(404, "Message not found");
    }
    if (Number(row.seq || 0) <= preference.clearedBeforeSeq) {
      throw new HttpError(404, "Message not found");
    }

    const reactionMap = await loadReactions([messageId]);
    const receipts = await queryMany(
      `SELECT user_id, last_read_seq, last_delivered_seq, updated_at
       FROM conversation_reads
       WHERE conversation_id = $1 AND user_id = ANY($2::text[])`,
      [conversationId, conversation.memberIds || []]
    );
    const receiptMap = new Map(receipts.map((item) => [String(item.user_id), item]));
    const messageSeq = Number(row.seq || 0);

    return {
      message: mapMessage(row, reactionMap.get(messageId) || []),
      receipts: (conversation.memberIds || []).map((userId: string) => {
        const receipt = receiptMap.get(userId);
        const lastReadSeq = Number(receipt?.last_read_seq || 0);
        const lastDeliveredSeq = Number(receipt?.last_delivered_seq || 0);
        return {
          userId,
          delivered: lastDeliveredSeq >= messageSeq,
          seen: lastReadSeq >= messageSeq,
          lastDeliveredSeq,
          lastReadSeq,
      updatedAt: toIso(receipt?.updated_at),
        };
      }),
    };
  });

  app.get("/:conversationId/saved-messages", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensureConversationOpenForUser(conversation, request.user.userId);
    const preference = await loadPreference(conversationId, request.user.userId);
    const limit = parseLimit(request.query?.limit, 30, 1, 80);

    const rows = await queryMany(
      `SELECT m.*, csm.saved_at, csm.note
       FROM chat_saved_messages csm
       JOIN messages m ON m.message_id = csm.message_id
       WHERE csm.conversation_id = $1
         AND csm.user_id = $2
         AND m.seq > $4
       ORDER BY csm.saved_at DESC
       LIMIT $3`,
      [conversationId, request.user.userId, limit, preference.clearedBeforeSeq]
    );
    const messages = await loadMessagesWithReactions(rows);

    return messages.map((message, index) => ({
      ...message,
      savedAt: toIso(rows[index]?.saved_at),
      note: rows[index]?.note || "",
    }));
  });

  app.post("/:conversationId/messages/:messageId/save", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    const messageId = normalizeString(request.params.messageId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    ensure(messageId.length >= 8, 400, "Invalid message");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensureConversationOpenForUser(conversation, request.user.userId);
    const preference = await loadPreference(conversationId, request.user.userId);
    const note = normalizeString(request.body?.note).slice(0, 500);

    const message = await queryOne(
      `SELECT message_id, seq
       FROM messages
       WHERE conversation_id = $1 AND message_id = $2 AND deleted_for_all_at IS NULL`,
      [conversationId, messageId]
    );
    if (!message || Number(message.seq || 0) <= preference.clearedBeforeSeq) {
      throw new HttpError(404, "Message not found");
    }

    const ts = now();
    await query(
      `INSERT INTO chat_saved_messages (conversation_id, message_id, user_id, saved_at, note)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (conversation_id, message_id, user_id)
       DO UPDATE SET saved_at = EXCLUDED.saved_at,
                     note = EXCLUDED.note`,
      [conversationId, messageId, request.user.userId, ts, note]
    );

    return {
      success: true,
      conversationId,
      messageId,
      savedAt: toIso(ts),
      note,
    };
  });

  app.delete("/:conversationId/messages/:messageId/save", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    const messageId = normalizeString(request.params.messageId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    ensure(messageId.length >= 8, 400, "Invalid message");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensureConversationOpenForUser(conversation, request.user.userId);

    const result = await query(
      `DELETE FROM chat_saved_messages
       WHERE conversation_id = $1
         AND message_id = $2
         AND user_id = $3`,
      [conversationId, messageId, request.user.userId]
    );

    return {
      success: true,
      conversationId,
      messageId,
      removed: (result.rowCount || 0) > 0,
    };
  });

  app.post("/:conversationId/messages/:messageId/pin", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    const messageId = normalizeString(request.params.messageId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    ensure(messageId.length >= 8, 400, "Invalid message");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensureConversationOpenForUser(conversation, request.user.userId);
    const preference = await loadPreference(conversationId, request.user.userId);
    if (conversation.type === "group") {
      ensure(isGroupAdmin(getGroupMeta(conversation), request.user.userId), 403, "Admin privileges required");
    }

    const message = await queryOne(
      `SELECT message_id, seq FROM messages WHERE conversation_id = $1 AND message_id = $2`,
      [conversationId, messageId]
    );
    if (!message || Number(message.seq || 0) <= preference.clearedBeforeSeq) {
      throw new HttpError(404, "Message not found");
    }

    const ts = now();
    await query(
      `INSERT INTO chat_pinned_messages (
         conversation_id, message_id, pinned_by_user_id, pinned_at
       )
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (conversation_id, message_id)
       DO UPDATE SET pinned_by_user_id = EXCLUDED.pinned_by_user_id,
                     pinned_at = EXCLUDED.pinned_at`,
      [conversationId, messageId, request.user.userId, ts]
    );

    publishToConversation(conversation.memberIds, "MESSAGE_PINNED", {
      conversationId,
      messageId,
      pinnedByUserId: request.user.userId,
      pinnedAt: toIso(ts),
    });

    return {
      success: true,
      conversationId,
      messageId,
      pinnedByUserId: request.user.userId,
      pinnedAt: toIso(ts),
    };
  });

  app.delete("/:conversationId/messages/:messageId/pin", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    const messageId = normalizeString(request.params.messageId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    ensure(messageId.length >= 8, 400, "Invalid message");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensureConversationOpenForUser(conversation, request.user.userId);
    const preference = await loadPreference(conversationId, request.user.userId);
    if (conversation.type === "group") {
      ensure(isGroupAdmin(getGroupMeta(conversation), request.user.userId), 403, "Admin privileges required");
    }

    const message = await queryOne(
      `SELECT message_id, seq FROM messages WHERE conversation_id = $1 AND message_id = $2`,
      [conversationId, messageId]
    );
    if (!message || Number(message.seq || 0) <= preference.clearedBeforeSeq) {
      throw new HttpError(404, "Message not found");
    }

    await query(
      `DELETE FROM chat_pinned_messages WHERE conversation_id = $1 AND message_id = $2`,
      [conversationId, messageId]
    );

    publishToConversation(conversation.memberIds, "MESSAGE_UNPINNED", {
      conversationId,
      messageId,
      unpinnedByUserId: request.user.userId,
      unpinnedAt: toIso(now()),
    });

    return {
      success: true,
      conversationId,
      messageId,
    };
  });

  app.get("/:conversationId/reads", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensureConversationOpenForUser(conversation, request.user.userId);
    const memberIds = Array.isArray(conversation.memberIds) ? conversation.memberIds : [];

    const reads = await queryMany(
      `SELECT user_id, last_read_seq, last_delivered_seq, updated_at
       FROM conversation_reads
       WHERE conversation_id = $1 AND user_id = ANY($2::text[])`,
      [conversationId, memberIds]
    );

    const readsByUserId = new Map(
      reads.map((item) => [
        String(item.user_id),
        {
          userId: String(item.user_id),
          lastReadSeq: Number(item.last_read_seq || 0),
          lastDeliveredSeq: Number(item.last_delivered_seq || 0),
          updatedAt: toIso(item.updated_at),
        },
      ])
    );

    return memberIds.map((userId) => (
      readsByUserId.get(userId) || {
        userId,
        lastReadSeq: 0,
        lastDeliveredSeq: 0,
        updatedAt: null,
      }
    ));
  });

  app.post("/sync", { preHandler: requireAuth }, async (request: any) => {
    const payload = Array.isArray(request.body?.conversations)
      ? request.body.conversations
      : [];
    const limitPerConversation = parseLimit(
      request.body?.limitPerConversation,
      50,
      1,
      100
    );

    const normalized: Array<{ conversationId: string; lastKnownSeq: number }> = [];
    const seen = new Set<string>();
    for (const row of payload) {
      if (!row || typeof row !== "object") continue;
      const conversationId = normalizeString(row.conversationId);
      if (conversationId.length < 8 || seen.has(conversationId)) continue;
      seen.add(conversationId);
      const lastKnownSeqRaw = Number.parseInt(String(row.lastKnownSeq || "0"), 10);
      normalized.push({
        conversationId,
        lastKnownSeq: Number.isNaN(lastKnownSeqRaw) || lastKnownSeqRaw < 0
          ? 0
          : lastKnownSeqRaw,
      });
    }

    if (normalized.length === 0) {
      return { conversations: [] };
    }

    const requestedConversationIds = normalized.map((item) => item.conversationId);
    const conversationPlaceholders = requestedConversationIds
      .map((_, index) => `$${index + 2}`)
      .join(", ");

    const allowedRows = await queryMany(
      `SELECT c.*
       FROM conversations c
       JOIN conversation_members cm ON cm.conversation_id = c.conversation_id
       WHERE cm.user_id = $1
         AND cm.left_at IS NULL
         AND c.conversation_id IN (${conversationPlaceholders})`,
      [request.user.userId, ...requestedConversationIds]
    );
    const allowedConversations = await hydrateConversations(allowedRows);
    const allowedMap = new Map(allowedConversations.map((item) => [item.conversationId, item]));

    const conversations: Array<any> = [];
    for (const item of normalized) {
      const meta = allowedMap.get(item.conversationId);
      if (!meta) continue;
      if (
        meta.type === "dm" &&
        (meta.dmRequestStatus === "declined" ||
          (
            meta.dmRequestStatus === "pending" &&
            meta.dmRequestRecipientUserId === request.user.userId
          ))
      ) {
        continue;
      }
      const preference = await loadPreference(item.conversationId, request.user.userId);
      const lastKnownSeq = Math.max(item.lastKnownSeq, preference.clearedBeforeSeq);

      const deltaMessages = await queryMany(
        `SELECT *
         FROM messages
         WHERE conversation_id = $1 AND seq > $2
         ORDER BY seq ASC
         LIMIT $3`,
        [item.conversationId, lastKnownSeq, limitPerConversation]
      );

      conversations.push({
        conversationId: item.conversationId,
        hasMore: deltaMessages.length === limitPerConversation,
        currentSeq: Number(meta.seqCounter || meta.lastMessageSeq || 0),
        updatedAt: toIso(meta.updatedAt),
        messages: await loadMessagesWithReactions(deltaMessages),
      });
    }

    return { conversations };
  });

  app.post("/:conversationId/messages", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    await ensureDmSendAllowed(conversation, request.user.userId);
    const memberIds = Array.isArray(conversation.memberIds) ? conversation.memberIds : [];
    if (conversation.type === "dm") {
      ensure(conversation.dmRequestStatus !== "declined", 403, "Message request was removed");
      if (
        conversation.dmRequestStatus === "pending" &&
        conversation.dmRequestRecipientUserId === request.user.userId
      ) {
        throw new HttpError(403, "Accept the message request before replying");
      }
    }

    const body = normalizeString(request.body?.body);
    const contentType = normalizeString(request.body?.contentType || "text").toLowerCase();
    const deviceId = normalizeString(request.body?.deviceId);
    const tempId = normalizeString(request.body?.tempId);
    const clientMessageId = normalizeString(
      request.body?.clientMessageId || request.body?.client_message_id || tempId
    );
    const mediaAssetId = normalizeString(request.body?.mediaAssetId);
    const replyToMessageId = normalizeString(request.body?.replyToMessageId);

    ensure(MESSAGE_TYPES.has(contentType), 400, "Invalid content type");
    ensure(body.length <= 65535, 400, "Invalid body");
    if (contentType === "text" || contentType === "system") {
      ensure(body.length > 0, 400, "Invalid body");
    } else {
      ensure(mediaAssetId.length > 0, 400, "Attachment media is required");
    }
    if (mediaAssetId) {
      await ensureOwnedMediaAsset(mediaAssetId, request.user.userId);
    }
    ensure(deviceId.length >= 3 && deviceId.length <= 128, 400, "Invalid device");

    const result = await createMessage(conversation, {
      senderUserId: request.user.userId,
      senderDeviceId: deviceId,
      body,
      contentType,
      mediaAssetId: mediaAssetId || null,
      replyToMessageId: replyToMessageId || null,
      clientMessageId: clientMessageId || null,
      clientTimestamp: request.body?.clientTimestamp,
    });
    const message = result.message;
    await savePreference(conversationId, request.user.userId, {
      localDeletedAt: null,
    });

    if (result.created) {
      publishToConversation(memberIds, "MESSAGE_PUSH", toRealtimeMessagePayload(message));
      await createChatNotifications({
        conversationId,
        conversation,
        memberIds,
        actorUserId: request.user.userId,
        body,
      });
    }

    if (tempId) {
      publishToUsers([request.user.userId], "MESSAGE_ACK", {
        conversationId,
        tempId,
        clientMessageId: message.client_message_id || message.client_message_uuid || null,
        messageId: message.message_id,
        seq: Number(message.seq || 0),
        createdAt: toIso(message.created_at),
        created: result.created,
      });
    }

    return {
      message: mapMessage(message),
      created: result.created,
    };
  });

  app.patch("/:conversationId/messages/:messageId", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    const messageId = normalizeString(request.params.messageId);
    const body = normalizeString(request.body?.body);

    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    ensure(messageId.length >= 8, 400, "Invalid message");
    ensure(body.length > 0 && body.length <= 65535, 400, "Invalid body");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    const memberIds = Array.isArray(conversation.memberIds) ? conversation.memberIds : [];
    const updated = await editMessageForUser(conversation, messageId, request.user.userId, body);

    if (!updated) {
      throw new HttpError(404, "Message not found");
    }

    publishToConversation(memberIds, "MESSAGE_EDIT", {
      conversationId,
      messageId,
      body,
      editVersion: Number(updated.edit_version || 0),
    });

    const reactions = await loadReactions([messageId]);
    return {
      success: true,
      message: mapMessage(updated, reactions.get(messageId) || []),
    };
  });

  app.delete("/:conversationId/messages/:messageId", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    const messageId = normalizeString(request.params.messageId);

    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    ensure(messageId.length >= 8, 400, "Invalid message");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    const memberIds = Array.isArray(conversation.memberIds) ? conversation.memberIds : [];
    const updated = await deleteMessageForUser(conversation, messageId, request.user.userId);

    if (!updated) {
      throw new HttpError(404, "Message not found");
    }

    publishToConversation(memberIds, "MESSAGE_DELETE", {
      conversationId,
      messageId,
      deletedForAllAt: toIso(updated.deleted_for_all_at),
    });

    return {
      success: true,
      deletedForAllAt: toIso(updated.deleted_for_all_at),
    };
  });

  app.post("/:conversationId/messages/:messageId/reactions", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    const messageId = normalizeString(request.params.messageId);
    const emoji = normalizeString(request.body?.emoji);

    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    ensure(messageId.length >= 8, 400, "Invalid message");
    ensure(emoji.length > 0 && emoji.length <= 16, 400, "Invalid emoji");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    const memberIds = Array.isArray(conversation.memberIds) ? conversation.memberIds : [];
    const reactions = await setReactionForUser(conversationId, messageId, request.user.userId, emoji);
    if (!reactions) {
      throw new HttpError(404, "Message not found");
    }

    publishToConversation(memberIds, "REACTION_UPDATE", {
      conversationId,
      messageId,
      userId: request.user.userId,
      emoji,
      updatedAt: toIso(now()),
    });

    return {
      success: true,
      reactions,
    };
  });

  app.delete("/:conversationId/messages/:messageId/reactions", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    const messageId = normalizeString(request.params.messageId);

    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    ensure(messageId.length >= 8, 400, "Invalid message");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    const memberIds = Array.isArray(conversation.memberIds) ? conversation.memberIds : [];
    const reactions = await setReactionForUser(conversationId, messageId, request.user.userId, null);
    if (!reactions) {
      throw new HttpError(404, "Message not found");
    }

    publishToConversation(memberIds, "REACTION_UPDATE", {
      conversationId,
      messageId,
      userId: request.user.userId,
      emoji: null,
      updatedAt: toIso(now()),
    });

    return {
      success: true,
      reactions,
    };
  });

  app.post("/:conversationId/delivery", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensureConversationOpenForUser(conversation, request.user.userId);
    const parsed = Number.parseInt(String(request.body?.lastDeliveredSeq || "0"), 10);
    ensure(!Number.isNaN(parsed) && parsed >= 0, 400, "Invalid lastDeliveredSeq");

    const { lastDeliveredSeq } = await upsertReadState(conversation, request.user.userId, {
      lastDeliveredSeq: parsed,
    });

    publishToConversation(conversation.memberIds, "DELIVERY_UPDATE", {
      conversationId,
      userId: request.user.userId,
      lastDeliveredSeq,
    }, request.user.userId);

    return { success: true, lastDeliveredSeq };
  });

  app.post("/:conversationId/read", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
    ensureConversationOpenForUser(conversation, request.user.userId);
    const parsed = Number.parseInt(String(request.body?.lastReadSeq || "0"), 10);
    ensure(!Number.isNaN(parsed) && parsed >= 0, 400, "Invalid lastReadSeq");

    const { lastReadSeq } = await upsertReadState(conversation, request.user.userId, {
      lastReadSeq: parsed,
    });
    await savePreference(conversationId, request.user.userId, {
      markedUnread: false,
    });

    publishToConversation(conversation.memberIds, "READ_UPDATE", {
      conversationId,
      userId: request.user.userId,
      lastReadSeq,
    }, request.user.userId);

    return { success: true, lastReadSeq };
  });
}
