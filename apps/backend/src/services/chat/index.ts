import { getDb } from "../../lib/mongo.js";
import { requireAuth } from "../../lib/auth.js";
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

function parseLimit(raw, fallback, min, max) {
  const parsed = Number.parseInt(String(raw || ""), 10);
  if (Number.isNaN(parsed)) {
    return fallback;
  }
  return Math.max(min, Math.min(max, parsed));
}

function normalizeMemberHash(ids) {
  return [...new Set(ids)].sort().join(":");
}

function normalizeString(value) {
  return String(value || "").trim();
}

function normalizeIdList(value) {
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

function getGroupMeta(conversation) {
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
      .filter((id) => memberIds.includes(id))
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

function roleForUser(groupMeta, userId) {
  if (userId === groupMeta.ownerUserId) {
    return "owner";
  }
  if (groupMeta.adminIds.includes(userId)) {
    return "admin";
  }
  return "member";
}

function isGroupAdmin(groupMeta, userId) {
  return roleForUser(groupMeta, userId) !== "member";
}

function toRealtimeMessagePayload(message) {
  return {
    conversationId: message.conversationId,
    messageId: message.messageId,
    senderUserId: message.senderUserId,
    senderDeviceId: message.senderDeviceId || "",
    seq: message.seq,
    contentType: message.contentType,
    body: message.body,
    mediaAssetId: message.mediaAssetId || null,
    editVersion: Number(message.editVersion || 0),
    deletedForAllAt: toIso(message.deletedForAllAt),
    createdAt: toIso(message.createdAt),
  };
}

function mapMessage(message) {
  return {
    id: message.messageId,
    messageId: message.messageId,
    conversationId: message.conversationId,
    senderUserId: message.senderUserId,
    senderDeviceId: message.senderDeviceId || "",
    body: message.body,
    contentType: message.contentType,
    seq: message.seq,
    mediaAssetId: message.mediaAssetId || null,
    replyToMessageId: message.replyToMessageId || null,
    editVersion: Number(message.editVersion || 0),
    reactions: Array.isArray(message.reactions) ? message.reactions : [],
    createdAt: toIso(message.createdAt),
    deletedForAllAt: toIso(message.deletedForAllAt),
  };
}

async function ensureUserExists(db, userId) {
  const user = await db.collection("users").findOne(
    { userId },
    {
      projection: {
        userId: 1,
        username: 1,
        displayName: 1,
      },
    }
  );
  if (!user) {
    throw new HttpError(404, "User not found");
  }
  return user;
}

async function ensureConversationAccess(db, conversationId, userId) {
  const conversation = await db.collection("conversations").findOne({
    conversationId,
    memberIds: userId,
  });
  if (!conversation) {
    throw new HttpError(404, "Conversation not found");
  }
  return conversation;
}

export default async function chatService(app) {
  const db = getDb();

  app.get("/", { preHandler: requireAuth }, async (request) => {
    const limit = parseLimit(request.query?.limit, 30, 1, 100);

    const conversations = await db.collection("conversations").find(
      {
        memberIds: request.user.userId,
      },
      {
        sort: { updatedAt: -1 },
        limit,
      }
    ).toArray();

    if (conversations.length === 0) {
      return [];
    }

    const conversationIds = conversations.map((row) => row.conversationId);
    const reads = await db.collection("conversation_reads").find(
      {
        userId: request.user.userId,
        conversationId: { $in: conversationIds },
      },
      {
        projection: {
          conversationId: 1,
          lastReadSeq: 1,
        },
      }
    ).toArray();

    const readMap = new Map(reads.map((item) => [item.conversationId, Number(item.lastReadSeq || 0)]));

    const otherUserIds = new Set();
    for (const conversation of conversations) {
      if (conversation.type === "dm") {
        for (const memberId of conversation.memberIds || []) {
          if (memberId !== request.user.userId) {
            otherUserIds.add(memberId);
          }
        }
      }
    }

    const otherUsers = await db.collection("users").find(
      { userId: { $in: [...otherUserIds] } },
      { projection: { userId: 1, username: 1, displayName: 1 } }
    ).toArray();
    const userMap = new Map(otherUsers.map((user) => [user.userId, user]));

    return conversations.map((conversation) => {
      let title = conversation.title || "Conversation";
      if (conversation.type === "dm") {
        const peerId = (conversation.memberIds || []).find((id) => id !== request.user.userId);
        const peer = peerId ? userMap.get(peerId) : null;
        if (peer) {
          title = peer.displayName || peer.username;
        }
      }

      const lastReadSeq = readMap.get(conversation.conversationId) || 0;
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
        memberCount: groupMeta
          ? groupMeta.memberIds.length
          : (Array.isArray(conversation.memberIds) ? conversation.memberIds.length : 0),
        isAdmin: groupMeta
          ? isGroupAdmin(groupMeta, request.user.userId)
          : false,
        myRole: groupMeta
          ? roleForUser(groupMeta, request.user.userId)
          : "member",
      };
    });
  });

  app.get("/:conversationId", { preHandler: requireAuth }, async (request) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await ensureConversationAccess(db, conversationId, request.user.userId);
    const groupMeta = conversation.type === "group" ? getGroupMeta(conversation) : null;

    let title = conversation.title || "Conversation";
    if (conversation.type === "dm") {
      const peerId = (conversation.memberIds || []).find((id) => id !== request.user.userId);
      if (peerId) {
        const peer = await db.collection("users").findOne(
          { userId: peerId },
          {
            projection: {
              username: 1,
              displayName: 1,
            },
          }
        );
        title = peer?.displayName || peer?.username || "Conversation";
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

  app.post("/dm", { preHandler: requireAuth }, async (request) => {
    const otherUserId = String(request.body?.otherUserId || "").trim();
    ensure(otherUserId.length >= 8, 400, "Invalid user");
    ensure(otherUserId !== request.user.userId, 400, "Cannot create DM with self");

    await ensureUserExists(db, otherUserId);

    const memberIds = [request.user.userId, otherUserId].sort();
    const memberHash = normalizeMemberHash(memberIds);
    const ts = now();

    const upsertResult = await db.collection("conversations").updateOne(
      {
        type: "dm",
        memberHash,
      },
      {
        $setOnInsert: {
          conversationId: generateId(),
          type: "dm",
          title: null,
          memberIds,
          ownerUserId: memberIds[0] || request.user.userId,
          adminIds: memberIds,
          memberHash,
          seqCounter: 0,
          createdAt: ts,
          updatedAt: ts,
          lastMessageId: null,
          lastMessageSeq: null,
          lastMessageSenderUserId: null,
          lastMessageBody: null,
          lastMessageContentType: null,
          lastMessageDeletedForAllAt: null,
          lastMessageCreatedAt: null,
        },
      },
      {
        upsert: true,
      }
    );

    const conversation = await db.collection("conversations").findOne({
      type: "dm",
      memberHash,
    });
    if (!conversation) {
      throw new HttpError(500, "Failed to create conversation");
    }

    return {
      conversationId: conversation.conversationId,
      created: upsertResult.upsertedCount > 0,
    };
  });

  app.post("/group", { preHandler: requireAuth }, async (request) => {
    const title = normalizeString(request.body?.title).slice(0, 120);
    const memberIds = [...new Set([request.user.userId, ...normalizeIdList(request.body?.memberIds)])];

    ensure(memberIds.length >= 2, 400, "Group must have at least 2 members");
    ensure(memberIds.length <= 1024, 400, "Group member limit exceeded");
    ensure(title.length > 0 && title.length <= 120, 400, "Invalid title");

    const users = await db.collection("users").find(
      { userId: { $in: memberIds } },
      { projection: { userId: 1 } }
    ).toArray();
    ensure(users.length === memberIds.length, 400, "One or more members not found");

    const ts = now();
    const conversationId = generateId();
    await db.collection("conversations").insertOne({
      conversationId,
      type: "group",
      title,
      memberIds,
      ownerUserId: request.user.userId,
      adminIds: [request.user.userId],
      seqCounter: 0,
      createdAt: ts,
      updatedAt: ts,
      lastMessageId: null,
      lastMessageSeq: null,
      lastMessageSenderUserId: null,
      lastMessageBody: null,
      lastMessageContentType: null,
      lastMessageDeletedForAllAt: null,
      lastMessageCreatedAt: null,
    });

    return { conversationId };
  });

  app.patch("/:conversationId", { preHandler: requireAuth }, async (request) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await ensureConversationAccess(db, conversationId, request.user.userId);
    ensure(conversation.type === "group", 400, "Conversation is not a group");

    const groupMeta = getGroupMeta(conversation);
    ensure(isGroupAdmin(groupMeta, request.user.userId), 403, "Admin privileges required");

    const title = normalizeString(request.body?.title).slice(0, 120);
    ensure(title.length > 0, 400, "Invalid title");

    const ts = now();
    await db.collection("conversations").updateOne(
      { conversationId },
      {
        $set: {
          title,
          updatedAt: ts,
        },
      }
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

  app.post("/:conversationId/members", { preHandler: requireAuth }, async (request) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await ensureConversationAccess(db, conversationId, request.user.userId);
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

    const users = await db.collection("users").find(
      { userId: { $in: added } },
      { projection: { userId: 1 } }
    ).toArray();
    ensure(users.length === added.length, 400, "One or more members not found");

    const memberIds = [...groupMeta.memberIds, ...added];
    const ts = now();
    await db.collection("conversations").updateOne(
      { conversationId },
      {
        $set: {
          memberIds,
          ownerUserId: groupMeta.ownerUserId || request.user.userId,
          adminIds: groupMeta.adminIds,
          updatedAt: ts,
        },
      }
    );

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

  app.delete("/:conversationId/members/:memberUserId", { preHandler: requireAuth }, async (request) => {
    const conversationId = normalizeString(request.params.conversationId);
    const memberUserId = normalizeString(request.params.memberUserId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    ensure(memberUserId.length >= 8, 400, "Invalid user");

    const conversation = await ensureConversationAccess(db, conversationId, request.user.userId);
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

    const memberIds = groupMeta.memberIds.filter((id) => id !== memberUserId);
    const adminIds = groupMeta.adminIds.filter((id) => id !== memberUserId);
    let ownerUserId = groupMeta.ownerUserId;

    if (memberUserId === ownerUserId) {
      const replacement = adminIds[0] || memberIds[0] || "";
      ownerUserId = replacement;
      if (replacement && !adminIds.includes(replacement)) {
        adminIds.push(replacement);
      }
    }

    const ts = now();
    await db.collection("conversations").updateOne(
      { conversationId },
      {
        $set: {
          memberIds,
          adminIds,
          ownerUserId,
          updatedAt: ts,
        },
      }
    );

    publishToConversation(memberIds, "GROUP_MEMBER_REMOVED", {
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

  app.post("/:conversationId/leave", { preHandler: requireAuth }, async (request) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    const memberUserId = request.user.userId;

    const conversation = await ensureConversationAccess(db, conversationId, request.user.userId);
    ensure(conversation.type === "group", 400, "Conversation is not a group");
    const groupMeta = getGroupMeta(conversation);
    ensure(groupMeta.memberIds.includes(memberUserId), 403, "Not a member");

    const memberIds = groupMeta.memberIds.filter((id) => id !== memberUserId);
    const adminIds = groupMeta.adminIds.filter((id) => id !== memberUserId);
    let ownerUserId = groupMeta.ownerUserId;

    if (memberUserId === ownerUserId) {
      const replacement = adminIds[0] || memberIds[0] || "";
      ownerUserId = replacement;
      if (replacement && !adminIds.includes(replacement)) {
        adminIds.push(replacement);
      }
    }

    const ts = now();
    await db.collection("conversations").updateOne(
      { conversationId },
      {
        $set: {
          memberIds,
          adminIds,
          ownerUserId,
          updatedAt: ts,
        },
      }
    );

    publishToConversation(memberIds, "GROUP_MEMBER_LEFT", {
      conversationId,
      userId: memberUserId,
      leftAt: toIso(ts),
    });

    return {
      success: true,
      conversationId,
    };
  });

  app.post("/:conversationId/admins", { preHandler: requireAuth }, async (request) => {
    const conversationId = normalizeString(request.params.conversationId);
    const userId = normalizeString(request.body?.userId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    ensure(userId.length >= 8, 400, "Invalid user");

    const conversation = await ensureConversationAccess(db, conversationId, request.user.userId);
    ensure(conversation.type === "group", 400, "Conversation is not a group");
    const groupMeta = getGroupMeta(conversation);
    ensure(isGroupAdmin(groupMeta, request.user.userId), 403, "Admin privileges required");
    ensure(groupMeta.memberIds.includes(userId), 404, "Member not found");
    ensure(userId !== groupMeta.ownerUserId, 400, "Owner role cannot be changed");

    const adminIds = [...new Set([...groupMeta.adminIds, userId])];
    const ts = now();
    await db.collection("conversations").updateOne(
      { conversationId },
      {
        $set: {
          adminIds,
          ownerUserId: groupMeta.ownerUserId,
          updatedAt: ts,
        },
      }
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

  app.delete("/:conversationId/admins/:memberUserId", { preHandler: requireAuth }, async (request) => {
    const conversationId = normalizeString(request.params.conversationId);
    const memberUserId = normalizeString(request.params.memberUserId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    ensure(memberUserId.length >= 8, 400, "Invalid user");

    const conversation = await ensureConversationAccess(db, conversationId, request.user.userId);
    ensure(conversation.type === "group", 400, "Conversation is not a group");
    const groupMeta = getGroupMeta(conversation);
    ensure(request.user.userId === groupMeta.ownerUserId, 403, "Only owner can remove admins");
    ensure(groupMeta.adminIds.includes(memberUserId), 400, "Member is not an admin");
    ensure(memberUserId !== groupMeta.ownerUserId, 400, "Cannot demote owner");

    const adminIds = groupMeta.adminIds.filter((id) => id !== memberUserId);
    const ts = now();
    await db.collection("conversations").updateOne(
      { conversationId },
      {
        $set: {
          adminIds,
          ownerUserId: groupMeta.ownerUserId,
          updatedAt: ts,
        },
      }
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

  app.get("/:conversationId/members", { preHandler: requireAuth }, async (request) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await ensureConversationAccess(db, conversationId, request.user.userId);
    const groupMeta = getGroupMeta(conversation);
    return groupMeta.memberIds.map((userId) => ({
      userId,
      role: conversation.type === "group" ? roleForUser(groupMeta, userId) : "member",
      joinedAt: toIso(conversation.createdAt),
      leftAt: null,
    }));
  });

  app.get("/:conversationId/messages", { preHandler: requireAuth }, async (request) => {
    const conversationId = String(request.params.conversationId || "").trim();
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    await ensureConversationAccess(db, conversationId, request.user.userId);

    const limit = parseLimit(request.query?.limit, 50, 1, 100);
    const filter: { conversationId: string; seq?: { $lt: number } } = { conversationId };
    const beforeSeqRaw = request.query?.beforeSeq;
    if (beforeSeqRaw !== undefined) {
      const beforeSeq = Number.parseInt(String(beforeSeqRaw), 10);
      if (!Number.isNaN(beforeSeq) && beforeSeq > 0) {
        filter.seq = { $lt: beforeSeq };
      }
    }

    const messages = await db.collection("messages").find(filter, {
      sort: { seq: -1 },
      limit,
    }).toArray();

    return messages.reverse().map(mapMessage);
  });

  app.get("/:conversationId/reads", { preHandler: requireAuth }, async (request) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await ensureConversationAccess(db, conversationId, request.user.userId);
    const memberIds = Array.isArray(conversation.memberIds)
      ? conversation.memberIds.map((id) => String(id))
      : [];

    const reads = await db.collection("conversation_reads").find(
      {
        conversationId,
        userId: { $in: memberIds },
      },
      {
        projection: {
          userId: 1,
          lastReadSeq: 1,
          lastDeliveredSeq: 1,
          updatedAt: 1,
        },
      }
    ).toArray();

    const readsByUserId = new Map(
      reads.map((item) => [
        String(item.userId),
        {
          userId: String(item.userId),
          lastReadSeq: Number(item.lastReadSeq || 0),
          lastDeliveredSeq: Number(item.lastDeliveredSeq || 0),
          updatedAt: toIso(item.updatedAt),
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

  app.post("/sync", { preHandler: requireAuth }, async (request) => {
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
    const seen = new Set();
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
      return {
        conversations: [],
      };
    }

    const allowedConversations = await db.collection("conversations").find(
      {
        conversationId: { $in: normalized.map((item) => item.conversationId) },
        memberIds: request.user.userId,
      },
      {
        projection: {
          conversationId: 1,
          seqCounter: 1,
          updatedAt: 1,
          lastMessageSeq: 1,
        },
      }
    ).toArray();

    const allowedSet = new Set(allowedConversations.map((item) => String(item.conversationId)));
    const conversations: Array<any> = [];
    for (const item of normalized) {
      if (!allowedSet.has(item.conversationId)) continue;

      const deltaMessages = await db.collection("messages").find(
        {
          conversationId: item.conversationId,
          seq: { $gt: item.lastKnownSeq },
        },
        {
          sort: { seq: 1 },
          limit: limitPerConversation,
        }
      ).toArray();

      const meta = allowedConversations.find((c) => c.conversationId === item.conversationId);
      conversations.push({
        conversationId: item.conversationId,
        hasMore: deltaMessages.length === limitPerConversation,
        currentSeq: Number(meta?.seqCounter || meta?.lastMessageSeq || 0),
        updatedAt: toIso(meta?.updatedAt),
        messages: deltaMessages.map(mapMessage),
      });
    }

    return {
      conversations,
    };
  });

  app.post("/:conversationId/messages", { preHandler: requireAuth }, async (request) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await ensureConversationAccess(db, conversationId, request.user.userId);
    const memberIds = Array.isArray(conversation.memberIds)
      ? conversation.memberIds.map((id) => String(id))
      : [];

    const body = normalizeString(request.body?.body);
    const contentType = normalizeString(request.body?.contentType || "text").toLowerCase();
    const deviceId = normalizeString(request.body?.deviceId);
    const tempId = normalizeString(request.body?.tempId);
    const mediaAssetId = normalizeString(request.body?.mediaAssetId);
    const replyToMessageId = normalizeString(request.body?.replyToMessageId);

    ensure(["text", "system", "media"].includes(contentType), 400, "Invalid content type");
    ensure(body.length > 0 && body.length <= 65535, 400, "Invalid body");
    ensure(deviceId.length >= 3 && deviceId.length <= 128, 400, "Invalid device");

    const ts = now();
    const seqResult = await db.collection("conversations").findOneAndUpdate(
      {
        conversationId: conversation.conversationId,
      },
      {
        $inc: { seqCounter: 1 },
        $set: { updatedAt: ts },
      },
      {
        returnDocument: "after",
      }
    );

    const seqDoc = seqResult && typeof seqResult === "object" && "value" in seqResult
      ? seqResult.value
      : seqResult;
    const nextSeq = Number(seqDoc?.seqCounter || 1);

    const message = {
      messageId: generateId(),
      conversationId,
      senderUserId: request.user.userId,
      senderDeviceId: deviceId,
      seq: nextSeq,
      contentType,
      body,
      replyToMessageId: replyToMessageId || null,
      mediaAssetId: mediaAssetId || null,
      clientTimestamp: request.body?.clientTimestamp || null,
      createdAt: ts,
      updatedAt: ts,
      editVersion: 0,
      reactions: [],
      deletedForAllAt: null,
    };

    await db.collection("messages").insertOne(message);

    await db.collection("conversations").updateOne(
      { conversationId },
      {
        $set: {
          updatedAt: ts,
          lastMessageId: message.messageId,
          lastMessageSeq: message.seq,
          lastMessageSenderUserId: message.senderUserId,
          lastMessageBody: message.body,
          lastMessageContentType: message.contentType,
          lastMessageDeletedForAllAt: null,
          lastMessageCreatedAt: ts,
          lastMessageEditVersion: 0,
        },
      }
    );

    await db.collection("conversation_reads").updateOne(
      {
        conversationId,
        userId: request.user.userId,
      },
      {
        $set: {
          conversationId,
          userId: request.user.userId,
          lastReadSeq: message.seq,
          lastDeliveredSeq: message.seq,
          updatedAt: ts,
        },
      },
      {
        upsert: true,
      }
    );

    publishToConversation(memberIds, "MESSAGE_PUSH", toRealtimeMessagePayload(message));

    if (tempId) {
      publishToUsers([request.user.userId], "MESSAGE_ACK", {
        conversationId,
        tempId,
        messageId: message.messageId,
        seq: message.seq,
        createdAt: toIso(ts),
      });
    }

    return {
      message: mapMessage(message),
      created: true,
    };
  });

  app.patch("/:conversationId/messages/:messageId", { preHandler: requireAuth }, async (request) => {
    const conversationId = normalizeString(request.params.conversationId);
    const messageId = normalizeString(request.params.messageId);
    const body = normalizeString(request.body?.body);

    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    ensure(messageId.length >= 8, 400, "Invalid message");
    ensure(body.length > 0 && body.length <= 65535, 400, "Invalid body");

    const conversation = await ensureConversationAccess(db, conversationId, request.user.userId);
    const memberIds = Array.isArray(conversation.memberIds)
      ? conversation.memberIds.map((id) => String(id))
      : [];

    const ts = now();
    const result = await db.collection("messages").findOneAndUpdate(
      {
        conversationId,
        messageId,
        senderUserId: request.user.userId,
        deletedForAllAt: null,
      },
      {
        $set: {
          body,
          updatedAt: ts,
        },
        $inc: {
          editVersion: 1,
        },
      },
      {
        returnDocument: "after",
      }
    );
    const updated = result && typeof result === "object" && "value" in result
      ? result.value
      : result;

    if (!updated) {
      throw new HttpError(404, "Message not found");
    }

    if (conversation.lastMessageId === messageId) {
      await db.collection("conversations").updateOne(
        { conversationId },
        {
          $set: {
            lastMessageBody: body,
            lastMessageContentType: updated.contentType || "text",
            lastMessageDeletedForAllAt: null,
            lastMessageEditVersion: Number(updated.editVersion || 0),
            updatedAt: ts,
          },
        }
      );
    }

    publishToConversation(memberIds, "MESSAGE_EDIT", {
      conversationId,
      messageId,
      body,
      editVersion: Number(updated.editVersion || 0),
    });

    return {
      success: true,
      message: mapMessage(updated),
    };
  });

  app.delete("/:conversationId/messages/:messageId", { preHandler: requireAuth }, async (request) => {
    const conversationId = normalizeString(request.params.conversationId);
    const messageId = normalizeString(request.params.messageId);

    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    ensure(messageId.length >= 8, 400, "Invalid message");

    const conversation = await ensureConversationAccess(db, conversationId, request.user.userId);
    const memberIds = Array.isArray(conversation.memberIds)
      ? conversation.memberIds.map((id) => String(id))
      : [];

    const ts = now();
    const result = await db.collection("messages").findOneAndUpdate(
      {
        conversationId,
        messageId,
        senderUserId: request.user.userId,
        deletedForAllAt: null,
      },
      {
        $set: {
          deletedForAllAt: ts,
          updatedAt: ts,
          body: "",
          contentType: "system",
        },
      },
      {
        returnDocument: "after",
      }
    );
    const updated = result && typeof result === "object" && "value" in result
      ? result.value
      : result;

    if (!updated) {
      throw new HttpError(404, "Message not found");
    }

    if (conversation.lastMessageId === messageId) {
      await db.collection("conversations").updateOne(
        { conversationId },
        {
          $set: {
            lastMessageBody: "",
            lastMessageContentType: "system",
            lastMessageDeletedForAllAt: ts,
            lastMessageEditVersion: Number(updated.editVersion || 0),
            updatedAt: ts,
          },
        }
      );
    }

    publishToConversation(memberIds, "MESSAGE_DELETE", {
      conversationId,
      messageId,
      deletedForAllAt: toIso(ts),
    });

    return {
      success: true,
      deletedForAllAt: toIso(ts),
    };
  });

  app.post("/:conversationId/messages/:messageId/reactions", { preHandler: requireAuth }, async (request) => {
    const conversationId = normalizeString(request.params.conversationId);
    const messageId = normalizeString(request.params.messageId);
    const emoji = normalizeString(request.body?.emoji);

    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    ensure(messageId.length >= 8, 400, "Invalid message");
    ensure(emoji.length > 0 && emoji.length <= 16, 400, "Invalid emoji");

    const conversation = await ensureConversationAccess(db, conversationId, request.user.userId);
    const memberIds = Array.isArray(conversation.memberIds)
      ? conversation.memberIds.map((id) => String(id))
      : [];

    const message = await db.collection("messages").findOne({ conversationId, messageId });
    if (!message) {
      throw new HttpError(404, "Message not found");
    }

    const ts = now();
    const reactions = Array.isArray(message.reactions) ? [...message.reactions] : [];
    const existingIndex = reactions.findIndex((reaction) => reaction.userId === request.user.userId);
    if (existingIndex === -1) {
      reactions.push({
        userId: request.user.userId,
        emoji,
        reactedAt: ts,
        updatedAt: ts,
      });
    } else {
      reactions[existingIndex] = {
        ...reactions[existingIndex],
        emoji,
        updatedAt: ts,
      };
    }

    await db.collection("messages").updateOne(
      { _id: message._id },
      {
        $set: {
          reactions,
          updatedAt: ts,
        },
      }
    );

    publishToConversation(memberIds, "REACTION_UPDATE", {
      conversationId,
      messageId,
      userId: request.user.userId,
      emoji,
      updatedAt: toIso(ts),
    });

    return {
      success: true,
      reactions,
    };
  });

  app.delete("/:conversationId/messages/:messageId/reactions", { preHandler: requireAuth }, async (request) => {
    const conversationId = normalizeString(request.params.conversationId);
    const messageId = normalizeString(request.params.messageId);

    ensure(conversationId.length >= 8, 400, "Invalid conversation");
    ensure(messageId.length >= 8, 400, "Invalid message");

    const conversation = await ensureConversationAccess(db, conversationId, request.user.userId);
    const memberIds = Array.isArray(conversation.memberIds)
      ? conversation.memberIds.map((id) => String(id))
      : [];

    const message = await db.collection("messages").findOne({ conversationId, messageId });
    if (!message) {
      throw new HttpError(404, "Message not found");
    }

    const ts = now();
    const reactions = Array.isArray(message.reactions)
      ? message.reactions.filter((reaction) => reaction.userId !== request.user.userId)
      : [];

    await db.collection("messages").updateOne(
      { _id: message._id },
      {
        $set: {
          reactions,
          updatedAt: ts,
        },
      }
    );

    publishToConversation(memberIds, "REACTION_UPDATE", {
      conversationId,
      messageId,
      userId: request.user.userId,
      emoji: null,
      updatedAt: toIso(ts),
    });

    return {
      success: true,
      reactions,
    };
  });

  app.post("/:conversationId/delivery", { preHandler: requireAuth }, async (request) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await ensureConversationAccess(db, conversationId, request.user.userId);
    const memberIds = Array.isArray(conversation.memberIds)
      ? conversation.memberIds.map((id) => String(id))
      : [];

    const parsed = Number.parseInt(String(request.body?.lastDeliveredSeq || "0"), 10);
    ensure(!Number.isNaN(parsed) && parsed >= 0, 400, "Invalid lastDeliveredSeq");
    const lastDeliveredSeq = Math.min(parsed, Number(conversation.seqCounter || parsed));

    await db.collection("conversation_reads").updateOne(
      {
        conversationId,
        userId: request.user.userId,
      },
      {
        $set: {
          conversationId,
          userId: request.user.userId,
          lastDeliveredSeq,
          updatedAt: now(),
        },
      },
      {
        upsert: true,
      }
    );

    publishToConversation(memberIds, "DELIVERY_UPDATE", {
      conversationId,
      userId: request.user.userId,
      lastDeliveredSeq,
    }, request.user.userId);

    return { success: true, lastDeliveredSeq };
  });

  app.post("/:conversationId/read", { preHandler: requireAuth }, async (request) => {
    const conversationId = normalizeString(request.params.conversationId);
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await ensureConversationAccess(db, conversationId, request.user.userId);
    const memberIds = Array.isArray(conversation.memberIds)
      ? conversation.memberIds.map((id) => String(id))
      : [];

    const parsed = Number.parseInt(String(request.body?.lastReadSeq || "0"), 10);
    ensure(!Number.isNaN(parsed) && parsed >= 0, 400, "Invalid lastReadSeq");
    const lastReadSeq = Math.min(parsed, Number(conversation.seqCounter || parsed));

    await db.collection("conversation_reads").updateOne(
      {
        conversationId,
        userId: request.user.userId,
      },
      {
        $set: {
          conversationId,
          userId: request.user.userId,
          lastReadSeq,
          updatedAt: now(),
        },
      },
      {
        upsert: true,
      }
    );

    publishToConversation(memberIds, "READ_UPDATE", {
      conversationId,
      userId: request.user.userId,
      lastReadSeq,
    }, request.user.userId);

    return { success: true, lastReadSeq };
  });
}
