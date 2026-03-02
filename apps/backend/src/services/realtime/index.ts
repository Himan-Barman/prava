import type { FastifyInstance } from "fastify";

import { getDb } from "../../lib/mongo.js";
import {
  ensure,
  generateId,
  now,
  verifyAccessToken,
} from "../../lib/security.js";
import {
  publishToConversation,
  publishToUsers,
  registerConnection,
  unregisterConnection,
} from "./hub.js";

const MESSAGE_TYPES = new Set(["text", "system", "media"]);

function parseIntStrict(value: unknown): number | null {
  const parsed = Number.parseInt(String(value || ""), 10);
  if (Number.isNaN(parsed)) return null;
  return parsed;
}

function normalizeString(value: unknown): string {
  return String(value || "").trim();
}

function toIso(value: Date): string {
  return value.toISOString();
}

export default async function realtimeService(app: FastifyInstance): Promise<void> {
  const db = getDb();

  const handleConnection = async (socket, request) => {
    const query = request.query as Record<string, unknown> | undefined;
    const token = normalizeString(query?.token);
    const deviceId = normalizeString(query?.deviceId);

    if (!token) {
      socket.close(1008, "Unauthorized");
      return;
    }

    let userId = "";
    try {
      const payload = verifyAccessToken(token);
      userId = payload.sub;
    } catch {
      socket.close(1008, "Unauthorized");
      return;
    }

    const state = {
      socket,
      userId,
      deviceId,
      subscribedConversations: new Set<string>(),
      conversationMeta: new Map<string, { memberIds: string[]; type?: string }>(),
      feedSubscribed: false,
    };

    registerConnection(state);

    const cleanup = () => {
      unregisterConnection(state);
      for (const [conversationId, meta] of state.conversationMeta.entries()) {
        if (meta.type !== "dm") continue;
        publishToConversation(
          meta.memberIds,
          "PRESENCE_UPDATE",
          {
            conversationId,
            userId,
            isOnline: false,
          },
          userId
        );
      }
    };

    socket.on("close", cleanup);
    socket.on("error", cleanup);

    const getConversationMeta = async (conversationId: string) => {
      if (state.conversationMeta.has(conversationId)) {
        return state.conversationMeta.get(conversationId) || null;
      }

      const conversation = await db.collection("conversations").findOne(
        { conversationId, memberIds: userId },
        { projection: { memberIds: 1, type: 1 } }
      );
      if (!conversation) {
        return null;
      }

      const meta = {
        memberIds: Array.isArray(conversation.memberIds)
          ? conversation.memberIds.map((id) => String(id))
          : [],
        type: conversation.type,
      };
      state.conversationMeta.set(conversationId, meta);
      return meta;
    };

    const sendTyping = async (conversationId: string, isTyping: boolean) => {
      const meta = await getConversationMeta(conversationId);
      if (!meta) return;
      publishToConversation(
        meta.memberIds,
        "TYPING",
        { conversationId, userId, isTyping },
        userId
      );
    };

    const sendReadUpdate = async (conversationId: string, lastReadSeq: number) => {
      const meta = await getConversationMeta(conversationId);
      if (!meta) return;
      const conversation = await db.collection("conversations").findOne(
        { conversationId },
        { projection: { seqCounter: 1 } }
      );
      const clampedLastReadSeq = Math.min(
        Math.max(lastReadSeq, 0),
        Number(conversation?.seqCounter || lastReadSeq)
      );

      await db.collection("conversation_reads").updateOne(
        { conversationId, userId },
        {
          $set: {
            conversationId,
            userId,
            lastReadSeq: clampedLastReadSeq,
            updatedAt: now(),
          },
        },
        { upsert: true }
      );

      publishToConversation(
        meta.memberIds,
        "READ_UPDATE",
        { conversationId, userId, lastReadSeq: clampedLastReadSeq },
        userId
      );
    };

    const sendDeliveryUpdate = async (conversationId: string, lastDeliveredSeq: number) => {
      const meta = await getConversationMeta(conversationId);
      if (!meta) return;
      const conversation = await db.collection("conversations").findOne(
        { conversationId },
        { projection: { seqCounter: 1 } }
      );
      const clampedLastDeliveredSeq = Math.min(
        Math.max(lastDeliveredSeq, 0),
        Number(conversation?.seqCounter || lastDeliveredSeq)
      );

      await db.collection("conversation_reads").updateOne(
        { conversationId, userId },
        {
          $set: {
            conversationId,
            userId,
            lastDeliveredSeq: clampedLastDeliveredSeq,
            updatedAt: now(),
          },
        },
        { upsert: true }
      );

      publishToConversation(
        meta.memberIds,
        "DELIVERY_UPDATE",
        { conversationId, userId, lastDeliveredSeq: clampedLastDeliveredSeq },
        userId
      );
    };

    const syncInit = async (payload: Record<string, unknown>) => {
      const rawConversations = Array.isArray(payload.conversations)
        ? payload.conversations
        : [];

      if (rawConversations.length === 0) {
        return;
      }

      const updates: Array<any> = [];
      for (const item of rawConversations) {
        if (!item || typeof item !== "object") continue;
        const row = item as Record<string, unknown>;
        const conversationId = normalizeString(row.conversationId);
        const lastDeliveredSeq = parseIntStrict(row.lastDeliveredSeq);
        if (!conversationId || lastDeliveredSeq == null || lastDeliveredSeq < 0) continue;

        const meta = await getConversationMeta(conversationId);
        if (!meta) continue;

        updates.push({
          updateOne: {
            filter: { conversationId, userId },
            update: {
              $set: {
                conversationId,
                userId,
                lastDeliveredSeq,
                updatedAt: now(),
              },
            },
            upsert: true,
          },
        });
      }

      if (updates.length === 0) {
        return;
      }

      await db.collection("conversation_reads").bulkWrite(updates, { ordered: false });
    };

    const sendMessage = async (payload: Record<string, unknown>) => {
      const conversationId = normalizeString(payload.conversationId);
      ensure(conversationId.length >= 8, 400, "Invalid conversation");

      const meta = await getConversationMeta(conversationId);
      if (!meta) return;

      const body = normalizeString(payload.body);
      const contentType = normalizeString(payload.contentType || "text").toLowerCase();
      const tempId = normalizeString(payload.tempId);
      const mediaAssetId = normalizeString(payload.mediaAssetId);
      const replyToMessageId = normalizeString(payload.replyToMessageId);
      const clientTimestamp = payload.clientTimestamp ?? null;
      const senderDeviceId = normalizeString(payload.deviceId || deviceId);

      ensure(MESSAGE_TYPES.has(contentType), 400, "Invalid content type");
      ensure(body.length > 0 && body.length <= 65535, 400, "Invalid body");
      ensure(senderDeviceId.length >= 3 && senderDeviceId.length <= 128, 400, "Invalid device");

      const ts = now();
      const seqResult = await db.collection("conversations").findOneAndUpdate(
        { conversationId },
        { $inc: { seqCounter: 1 }, $set: { updatedAt: ts } },
        { returnDocument: "after" }
      );
      const seqDoc = seqResult && typeof seqResult === "object" && "value" in seqResult
        ? seqResult.value
        : seqResult;
      const nextSeq = Number(seqDoc?.seqCounter || 1);

      const message = {
        messageId: generateId(),
        conversationId,
        senderUserId: userId,
        senderDeviceId,
        seq: nextSeq,
        contentType,
        body,
        replyToMessageId: replyToMessageId || null,
        mediaAssetId: mediaAssetId || null,
        clientTimestamp,
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
        { conversationId, userId },
        {
          $set: {
            conversationId,
            userId,
            lastReadSeq: message.seq,
            lastDeliveredSeq: message.seq,
            updatedAt: now(),
          },
        },
        { upsert: true }
      );

      publishToConversation(
        meta.memberIds,
        "MESSAGE_PUSH",
        {
          conversationId,
          messageId: message.messageId,
          senderUserId: message.senderUserId,
          senderDeviceId: message.senderDeviceId,
          seq: message.seq,
          contentType: message.contentType,
          body: message.body,
          replyToMessageId: message.replyToMessageId || null,
          mediaAssetId: message.mediaAssetId,
          editVersion: message.editVersion,
          deletedForAllAt: message.deletedForAllAt,
          createdAt: toIso(ts),
        }
      );

      if (tempId) {
        publishToUsers(
          [userId],
          "MESSAGE_ACK",
          {
            conversationId,
            tempId,
            messageId: message.messageId,
            seq: message.seq,
            createdAt: toIso(ts),
          }
        );
      }
    };

    const editMessage = async (payload: Record<string, unknown>) => {
      const conversationId = normalizeString(payload.conversationId);
      const messageId = normalizeString(payload.messageId);
      const body = normalizeString(payload.body);
      if (!conversationId || !messageId || !body) return;

      const meta = await getConversationMeta(conversationId);
      if (!meta) return;

      const ts = now();
      const result = await db.collection("messages").findOneAndUpdate(
        {
          conversationId,
          messageId,
          senderUserId: userId,
          deletedForAllAt: null,
        },
        {
          $set: { body, updatedAt: ts },
          $inc: { editVersion: 1 },
        },
        { returnDocument: "after" }
      );
      const updated = result && typeof result === "object" && "value" in result
        ? result.value
        : result;
      if (!updated) return;

      const conversation = await db.collection("conversations").findOne(
        { conversationId },
        { projection: { lastMessageId: 1 } }
      );
      if (conversation?.lastMessageId === messageId) {
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

      publishToConversation(
        meta.memberIds,
        "MESSAGE_EDIT",
        {
          conversationId,
          messageId,
          body,
          editVersion: Number(updated.editVersion || 0),
        }
      );
    };

    const deleteMessage = async (payload: Record<string, unknown>) => {
      const conversationId = normalizeString(payload.conversationId);
      const messageId = normalizeString(payload.messageId);
      if (!conversationId || !messageId) return;

      const meta = await getConversationMeta(conversationId);
      if (!meta) return;

      const ts = now();
      const result = await db.collection("messages").findOneAndUpdate(
        {
          conversationId,
          messageId,
          senderUserId: userId,
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
        { returnDocument: "after" }
      );
      const updated = result && typeof result === "object" && "value" in result
        ? result.value
        : result;
      if (!updated) return;

      const conversation = await db.collection("conversations").findOne(
        { conversationId },
        { projection: { lastMessageId: 1 } }
      );
      if (conversation?.lastMessageId === messageId) {
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

      publishToConversation(
        meta.memberIds,
        "MESSAGE_DELETE",
        {
          conversationId,
          messageId,
          deletedForAllAt: toIso(ts),
        }
      );
    };

    const setReaction = async (payload: Record<string, unknown>, remove = false) => {
      const conversationId = normalizeString(payload.conversationId);
      const messageId = normalizeString(payload.messageId);
      const emoji = remove ? "" : normalizeString(payload.emoji);
      if (!conversationId || !messageId) return;
      if (!remove && !emoji) return;

      const meta = await getConversationMeta(conversationId);
      if (!meta) return;

      const message = await db.collection("messages").findOne({ conversationId, messageId });
      if (!message) return;

      const ts = now();
      const reactions = Array.isArray(message.reactions) ? [...message.reactions] : [];
      const existingIndex = reactions.findIndex((reaction) => reaction.userId === userId);

      if (remove) {
        if (existingIndex !== -1) {
          reactions.splice(existingIndex, 1);
        }
      } else if (existingIndex === -1) {
        reactions.push({
          userId,
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
        { $set: { reactions } }
      );

      publishToConversation(
        meta.memberIds,
        "REACTION_UPDATE",
        {
          conversationId,
          messageId,
          userId,
          emoji: remove ? null : emoji,
          updatedAt: toIso(ts),
        }
      );
    };

    socket.on("message", async (raw) => {
      let event: { type?: string; payload?: Record<string, unknown> } | null = null;
      try {
        event = JSON.parse(String(raw));
      } catch {
        return;
      }
      if (!event || typeof event !== "object") return;

      const type = String(event.type || "").trim().toUpperCase();
      const payload = (event.payload || {}) as Record<string, unknown>;

      try {
        switch (type) {
          case "CONVERSATION_SUBSCRIBE": {
            const conversationId = normalizeString(payload.conversationId);
            if (!conversationId) return;
            const meta = await getConversationMeta(conversationId);
            if (!meta) return;
            state.subscribedConversations.add(conversationId);
            if (meta.type === "dm") {
              publishToConversation(
                meta.memberIds,
                "PRESENCE_UPDATE",
                { conversationId, userId, isOnline: true },
                userId
              );
            }
            break;
          }
          case "FEED_SUBSCRIBE":
            state.feedSubscribed = true;
            break;
          case "MESSAGE_SEND":
            await sendMessage(payload);
            break;
          case "MESSAGE_EDIT":
            await editMessage(payload);
            break;
          case "MESSAGE_DELETE":
            await deleteMessage(payload);
            break;
          case "REACTION_SET":
            await setReaction(payload, false);
            break;
          case "REACTION_REMOVE":
            await setReaction(payload, true);
            break;
          case "READ_RECEIPT": {
            const conversationId = normalizeString(payload.conversationId);
            const lastReadSeq = parseIntStrict(payload.lastReadSeq);
            if (!conversationId || lastReadSeq == null) return;
            await sendReadUpdate(conversationId, lastReadSeq);
            break;
          }
          case "DELIVERY_RECEIPT": {
            const conversationId = normalizeString(payload.conversationId);
            const lastDeliveredSeq = parseIntStrict(payload.lastDeliveredSeq);
            if (!conversationId || lastDeliveredSeq == null) return;
            await sendDeliveryUpdate(conversationId, lastDeliveredSeq);
            break;
          }
          case "SYNC_INIT":
            await syncInit(payload);
            break;
          case "TYPING_START":
            await sendTyping(normalizeString(payload.conversationId), true);
            break;
          case "TYPING_STOP":
            await sendTyping(normalizeString(payload.conversationId), false);
            break;
          default:
            break;
        }
      } catch {
        // ignore invalid client events
      }
    });
  };

  app.get("/", { websocket: true }, handleConnection);
  app.get("/ws", { websocket: true }, handleConnection);
}
