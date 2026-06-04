import type { FastifyInstance } from "fastify";

import {
  ensure,
  verifyAccessToken,
  toIso,
} from "../../lib/security.js";
import { query } from "../../lib/pg.js";
import {
  MESSAGE_TYPES,
  createMessage,
  deleteMessageForUser,
  editMessageForUser,
  loadConversationForUserOrNull,
  normalizeString,
  setReactionForUser,
  toRealtimeMessagePayload,
  upsertReadState,
} from "../chat/store.js";
import {
  publishToConversation,
  publishToUsers,
  registerConnection,
  unregisterConnection,
} from "./hub.js";

function parseIntStrict(value: unknown): number | null {
  const parsed = Number.parseInt(String(value || ""), 10);
  if (Number.isNaN(parsed)) return null;
  return parsed;
}

export default async function realtimeService(app: FastifyInstance): Promise<void> {
  const handleConnection = async (socket: any, request: any) => {
    const params = request.query as Record<string, unknown> | undefined;
    const token = normalizeString(params?.token);
    const deviceId = normalizeString(params?.deviceId);

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

    const touchLastSeen = () => {
      void query(
        `UPDATE users SET last_seen_at = NOW() WHERE user_id = $1`,
        [userId]
      ).catch(() => undefined);
    };

    touchLastSeen();

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
      touchLastSeen();
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

    const getConversation = async (conversationId: string) => {
      const conversation = await loadConversationForUserOrNull(conversationId, userId);
      if (!conversation) {
        return null;
      }

      state.conversationMeta.set(conversationId, {
        memberIds: conversation.memberIds,
        type: conversation.type,
      });
      return conversation;
    };

    const sendTyping = async (conversationId: string, isTyping: boolean) => {
      const conversation = await getConversation(conversationId);
      if (!conversation) return;
      publishToConversation(
        conversation.memberIds,
        "TYPING",
        { conversationId, userId, isTyping },
        userId
      );
    };

    const sendReadUpdate = async (conversationId: string, lastReadSeq: number) => {
      const conversation = await getConversation(conversationId);
      if (!conversation) return;
      const result = await upsertReadState(conversation, userId, { lastReadSeq });
      publishToConversation(
        conversation.memberIds,
        "READ_UPDATE",
        { conversationId, userId, lastReadSeq: result.lastReadSeq },
        userId
      );
    };

    const sendDeliveryUpdate = async (conversationId: string, lastDeliveredSeq: number) => {
      const conversation = await getConversation(conversationId);
      if (!conversation) return;
      const result = await upsertReadState(conversation, userId, { lastDeliveredSeq });
      publishToConversation(
        conversation.memberIds,
        "DELIVERY_UPDATE",
        { conversationId, userId, lastDeliveredSeq: result.lastDeliveredSeq },
        userId
      );
    };

    const syncInit = async (payload: Record<string, unknown>) => {
      const rawConversations = Array.isArray(payload.conversations)
        ? payload.conversations
        : [];

      for (const item of rawConversations) {
        if (!item || typeof item !== "object") continue;
        const row = item as Record<string, unknown>;
        const conversationId = normalizeString(row.conversationId);
        const lastDeliveredSeq = parseIntStrict(row.lastDeliveredSeq);
        if (!conversationId || lastDeliveredSeq == null || lastDeliveredSeq < 0) continue;

        const conversation = await getConversation(conversationId);
        if (!conversation) continue;

        await upsertReadState(conversation, userId, { lastDeliveredSeq });
      }
    };

    const sendMessage = async (payload: Record<string, unknown>) => {
      const conversationId = normalizeString(payload.conversationId);
      ensure(conversationId.length >= 8, 400, "Invalid conversation");

      const conversation = await getConversation(conversationId);
      if (!conversation) return;

      const body = normalizeString(payload.body);
      const contentType = normalizeString(payload.contentType || "text").toLowerCase();
      const tempId = normalizeString(payload.tempId);
      const mediaAssetId = normalizeString(payload.mediaAssetId);
      const replyToMessageId = normalizeString(payload.replyToMessageId);
      const senderDeviceId = normalizeString(payload.deviceId || deviceId);

      ensure(MESSAGE_TYPES.has(contentType), 400, "Invalid content type");
      ensure(body.length > 0 && body.length <= 65535, 400, "Invalid body");
      ensure(senderDeviceId.length >= 3 && senderDeviceId.length <= 128, 400, "Invalid device");

      const message = await createMessage(conversation, {
        senderUserId: userId,
        senderDeviceId,
        body,
        contentType,
        mediaAssetId: mediaAssetId || null,
        replyToMessageId: replyToMessageId || null,
        clientTimestamp: payload.clientTimestamp ?? null,
      });

      publishToConversation(
        conversation.memberIds,
        "MESSAGE_PUSH",
        toRealtimeMessagePayload(message)
      );

      if (tempId) {
        publishToUsers(
          [userId],
          "MESSAGE_ACK",
          {
            conversationId,
            tempId,
            messageId: message.message_id,
            seq: Number(message.seq || 0),
            createdAt: toIso(message.created_at),
          }
        );
      }
    };

    const editMessage = async (payload: Record<string, unknown>) => {
      const conversationId = normalizeString(payload.conversationId);
      const messageId = normalizeString(payload.messageId);
      const body = normalizeString(payload.body);
      if (!conversationId || !messageId || !body) return;

      const conversation = await getConversation(conversationId);
      if (!conversation) return;

      const updated = await editMessageForUser(conversation, messageId, userId, body);
      if (!updated) return;

      publishToConversation(
        conversation.memberIds,
        "MESSAGE_EDIT",
        {
          conversationId,
          messageId,
          body,
          editVersion: Number(updated.edit_version || 0),
        }
      );
    };

    const deleteMessage = async (payload: Record<string, unknown>) => {
      const conversationId = normalizeString(payload.conversationId);
      const messageId = normalizeString(payload.messageId);
      if (!conversationId || !messageId) return;

      const conversation = await getConversation(conversationId);
      if (!conversation) return;

      const updated = await deleteMessageForUser(conversation, messageId, userId);
      if (!updated) return;

      publishToConversation(
        conversation.memberIds,
        "MESSAGE_DELETE",
        {
          conversationId,
          messageId,
          deletedForAllAt: toIso(updated.deleted_for_all_at),
        }
      );
    };

    const setReaction = async (payload: Record<string, unknown>, remove = false) => {
      const conversationId = normalizeString(payload.conversationId);
      const messageId = normalizeString(payload.messageId);
      const emoji = remove ? "" : normalizeString(payload.emoji);
      if (!conversationId || !messageId) return;
      if (!remove && !emoji) return;

      const conversation = await getConversation(conversationId);
      if (!conversation) return;

      const reactions = await setReactionForUser(
        conversationId,
        messageId,
        userId,
        remove ? null : emoji
      );
      if (!reactions) return;

      publishToConversation(
        conversation.memberIds,
        "REACTION_UPDATE",
        {
          conversationId,
          messageId,
          userId,
          emoji: remove ? null : emoji,
          updatedAt: toIso(new Date()),
        }
      );
    };

    socket.on("message", async (raw: unknown) => {
      touchLastSeen();
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
            const conversation = await getConversation(conversationId);
            if (!conversation) return;
            state.subscribedConversations.add(conversationId);
            if (conversation.type === "dm") {
              publishToConversation(
                conversation.memberIds,
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
        // Invalid realtime client events are ignored to keep the socket open.
      }
    });
  };

  app.get("/", { websocket: true }, handleConnection);
  app.get("/ws", { websocket: true }, handleConnection);
}
