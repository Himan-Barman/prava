import { getDb } from "../../lib/mongo.js";
import { requireAuth } from "../../lib/auth.js";
import {
  HttpError,
  ensure,
  generateId,
  now,
  toIso,
} from "../../lib/security.js";

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
      };
    });
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
    const title = String(request.body?.title || "").trim();
    const incoming = Array.isArray(request.body?.memberIds) ? request.body.memberIds : [];

    const memberIds = [...new Set([request.user.userId, ...incoming.map((id) => String(id || "").trim())])]
      .filter((id) => id.length >= 8);

    ensure(memberIds.length >= 2, 400, "Group must have at least 2 members");
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

  app.get("/:conversationId/members", { preHandler: requireAuth }, async (request) => {
    const conversationId = String(request.params.conversationId || "").trim();
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await ensureConversationAccess(db, conversationId, request.user.userId);
    return (conversation.memberIds || []).map((userId) => ({
      userId,
      role: userId === conversation.memberIds?.[0] ? "owner" : "member",
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

    return messages.map(mapMessage);
  });

  app.post("/:conversationId/messages", { preHandler: requireAuth }, async (request) => {
    const conversationId = String(request.params.conversationId || "").trim();
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    const conversation = await ensureConversationAccess(db, conversationId, request.user.userId);

    const body = String(request.body?.body || "").trim();
    const contentType = String(request.body?.contentType || "text").trim().toLowerCase();
    const deviceId = String(request.body?.deviceId || "").trim();

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
      clientTimestamp: request.body?.clientTimestamp || null,
      createdAt: ts,
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
        },
      }
    );

    return {
      message: mapMessage(message),
      created: true,
    };
  });

  app.post("/:conversationId/read", { preHandler: requireAuth }, async (request) => {
    const conversationId = String(request.params.conversationId || "").trim();
    ensure(conversationId.length >= 8, 400, "Invalid conversation");

    await ensureConversationAccess(db, conversationId, request.user.userId);

    const lastReadSeq = Number.parseInt(String(request.body?.lastReadSeq || "0"), 10);
    ensure(!Number.isNaN(lastReadSeq) && lastReadSeq >= 0, 400, "Invalid lastReadSeq");

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

    return { success: true };
  });
}
