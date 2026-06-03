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

async function loadActiveUsers(ids: string[]): Promise<any[]> {
  if (ids.length === 0) {
    return [];
  }
  return queryMany(
    `SELECT user_id, username, display_name
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
  if (conversation.type === "dm") {
    const peerId = (conversation.memberIds || []).find((id) => id !== currentUserId);
    const peer = peerId ? peerMap.get(peerId) : null;
    if (peer) {
      title = userDisplayName(peer);
    }
  }

  const lastSeq = Number(conversation.seqCounter || 0);
  const groupMeta = conversation.type === "group"
    ? getGroupMeta(conversation)
    : undefined;

  return {
    id: conversation.conversationId,
    type: conversation.type,
    title,
    unreadCount: Math.max(0, lastSeq - lastReadSeq),
    updatedAt: toIso(conversation.updatedAt),
    lastMessageId: conversation.lastMessageId || null,
    lastMessageSeq: conversation.lastMessageSeq ?? null,
    lastMessageSenderUserId: conversation.lastMessageSenderUserId || null,
    lastMessageBody: conversation.lastMessageBody || null,
    lastMessageContentType: conversation.lastMessageContentType || null,
    lastMessageDeletedForAllAt: toIso(conversation.lastMessageDeletedForAllAt),
    lastMessageCreatedAt: toIso(conversation.lastMessageCreatedAt),
    memberCount: Array.isArray(conversation.memberIds) ? conversation.memberIds.length : 0,
    isAdmin: groupMeta ? isGroupAdmin(groupMeta, currentUserId) : false,
    myRole: groupMeta ? roleForUser(groupMeta, currentUserId) : "member",
  };
}

export default async function chatService(app: any) {
  app.get("/", { preHandler: requireAuth }, async (request: any) => {
    const limit = parseLimit(request.query?.limit, 30, 1, 100);

    const rows = await queryMany(
      `SELECT c.*
       FROM conversations c
       JOIN conversation_members cm ON cm.conversation_id = c.conversation_id
       WHERE cm.user_id = $1 AND cm.left_at IS NULL
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

  app.get("/:conversationId", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
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

    const memberIds = [request.user.userId, otherUserId].sort();
    const memberHash = normalizeMemberHash(memberIds);
    const ts = now();

    const result = await withTransaction(async (client) => {
      const inserted = await client.query(
        `INSERT INTO conversations (
           conversation_id, type, title, member_hash, owner_user_id, seq_counter,
           created_at, updated_at
         )
         VALUES ($1, 'dm', NULL, $2, $3, 0, $4, $5)
         ON CONFLICT (member_hash) DO NOTHING
         RETURNING conversation_id`,
        [generateId(), memberHash, memberIds[0] || request.user.userId, ts, ts]
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

      if (created) {
        for (const memberId of memberIds) {
          await client.query(
            `INSERT INTO conversation_members (conversation_id, user_id, role, joined_at, left_at)
             VALUES ($1, $2, 'member', $3, NULL)
             ON CONFLICT (conversation_id, user_id)
             DO UPDATE SET left_at = NULL`,
            [conversationId, memberId, ts]
          );
        }
      }

      return { conversationId, created };
    });

    return result;
  });

  app.post("/group", { preHandler: requireAuth }, async (request: any) => {
    const title = normalizeString(request.body?.title).slice(0, 120);
    const memberIds = [...new Set([request.user.userId, ...normalizeIdList(request.body?.memberIds)])];

    ensure(memberIds.length >= 2, 400, "Group must have at least 2 members");
    ensure(memberIds.length <= 1024, 400, "Group member limit exceeded");
    ensure(title.length > 0 && title.length <= 120, 400, "Invalid title");

    const users = await queryMany(
      `SELECT user_id FROM users WHERE user_id = ANY($1::text[]) AND deleted_at IS NULL`,
      [memberIds]
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

    const users = await queryMany(
      `SELECT user_id FROM users WHERE user_id = ANY($1::text[]) AND deleted_at IS NULL`,
      [added]
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

    await loadConversationForUser(conversationId, request.user.userId);

    const limit = parseLimit(request.query?.limit, 50, 1, 100);
    const params: unknown[] = [conversationId];
    let where = "conversation_id = $1";
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

  app.get("/:conversationId/reads", { preHandler: requireAuth }, async (request: any) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await loadConversationForUser(conversationId, request.user.userId);
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

      const deltaMessages = await queryMany(
        `SELECT *
         FROM messages
         WHERE conversation_id = $1 AND seq > $2
         ORDER BY seq ASC
         LIMIT $3`,
        [item.conversationId, item.lastKnownSeq, limitPerConversation]
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
    const memberIds = Array.isArray(conversation.memberIds) ? conversation.memberIds : [];

    const body = normalizeString(request.body?.body);
    const contentType = normalizeString(request.body?.contentType || "text").toLowerCase();
    const deviceId = normalizeString(request.body?.deviceId);
    const tempId = normalizeString(request.body?.tempId);
    const mediaAssetId = normalizeString(request.body?.mediaAssetId);
    const replyToMessageId = normalizeString(request.body?.replyToMessageId);

    ensure(MESSAGE_TYPES.has(contentType), 400, "Invalid content type");
    ensure(body.length > 0 && body.length <= 65535, 400, "Invalid body");
    ensure(deviceId.length >= 3 && deviceId.length <= 128, 400, "Invalid device");

    const message = await createMessage(conversation, {
      senderUserId: request.user.userId,
      senderDeviceId: deviceId,
      body,
      contentType,
      mediaAssetId: mediaAssetId || null,
      replyToMessageId: replyToMessageId || null,
      clientTimestamp: request.body?.clientTimestamp,
    });

    publishToConversation(memberIds, "MESSAGE_PUSH", toRealtimeMessagePayload(message));

    if (tempId) {
      publishToUsers([request.user.userId], "MESSAGE_ACK", {
        conversationId,
        tempId,
        messageId: message.message_id,
        seq: Number(message.seq || 0),
        createdAt: toIso(message.created_at),
      });
    }

    return {
      message: mapMessage(message),
      created: true,
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
    const parsed = Number.parseInt(String(request.body?.lastReadSeq || "0"), 10);
    ensure(!Number.isNaN(parsed) && parsed >= 0, 400, "Invalid lastReadSeq");

    const { lastReadSeq } = await upsertReadState(conversation, request.user.userId, {
      lastReadSeq: parsed,
    });

    publishToConversation(conversation.memberIds, "READ_UPDATE", {
      conversationId,
      userId: request.user.userId,
      lastReadSeq,
    }, request.user.userId);

    return { success: true, lastReadSeq };
  });
}
