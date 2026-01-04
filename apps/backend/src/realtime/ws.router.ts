import { ConversationsService } from '@/modules/conversations/conversations.service';
import { MessagesService } from '@/modules/messages/messages.service';
import { WsHub } from './ws.hub';
import { SyncService } from './sync.service';
import { MAX_MESSAGE_BODY_LENGTH } from '@/common/constants';

interface RealtimeSocket {
  send(message: string): void;
  close(code?: number, reason?: string): void;
  subscribe(topic: string): void;
}

interface WSMessage {
  type: string;
  payload?: unknown;
}

interface SyncInitPayload {
  conversations: Array<{
    conversationId: string;
    lastDeliveredSeq: number;
  }>;
}

interface MessageSendPayload {
  conversationId: string;
  body?: string;
  contentType?: 'text' | 'system' | 'media';
  clientTimestamp?: number;
  tempId?: string;
  mediaAssetId?: string;
}

interface ReadReceiptPayload {
  conversationId: string;
  lastReadSeq: number;
}

interface DeliveryReceiptPayload {
  conversationId: string;
  lastDeliveredSeq: number;
}

interface TypingPayload {
  conversationId: string;
}

interface SubscribePayload {
  conversationId: string;
}


interface MessageEditPayload {
  conversationId: string;
  messageId: string;
  body: string;
}

interface MessageDeletePayload {
  conversationId: string;
  messageId: string;
}

interface ReactionPayload {
  conversationId: string;
  messageId: string;
  emoji?: string;
}

const sendEvent = (ws: RealtimeSocket, payload: unknown) => {
  ws.send(JSON.stringify(payload));
};

export async function handleWsMessage(params: {
  ws: RealtimeSocket;
  msg: WSMessage;
  userId: string;
  deviceId: string;
  syncService: SyncService;
  conversationsService: ConversationsService;
  messagesService: MessagesService;
  hub: WsHub;
}) {
  const {
    ws,
    msg,
    userId,
    deviceId,
    syncService,
    conversationsService,
    messagesService,
    hub,
  } = params;

  switch (msg.type) {
    /* =========================================================
       SYNC INIT (device reconnect / fresh login)
    ========================================================= */
    case 'SYNC_INIT': {
      const payload = msg.payload as SyncInitPayload | undefined;

      // hard validation (never trust client)
      if (!payload || !Array.isArray(payload.conversations)) {
        ws.close();
        return;
      }

      for (const convo of payload.conversations) {
        if (
          typeof convo.conversationId !== 'string' ||
          typeof convo.lastDeliveredSeq !== 'number'
        ) {
          continue; // skip bad entry, keep socket alive
        }

        const member = await conversationsService.getMembership({
          conversationId: convo.conversationId,
          userId,
        });
        if (!member) {
          continue;
        }

        const rows = await syncService.syncConversation({
          userId,
          deviceId,
          conversationId: convo.conversationId,
          lastDeliveredSeq: convo.lastDeliveredSeq,
        });

        for (const m of rows) {
          sendEvent(ws, {
            type: 'MESSAGE_PUSH',
            payload: {
              messageId: m.id,
              conversationId: m.conversationId,
              seq: m.seq,
              senderUserId: m.senderUserId,
              senderDeviceId: m.senderDeviceId,
              body: m.body,
              contentType: m.contentType,
              mediaAssetId: m.mediaAssetId,
              editVersion: m.editVersion,
              deletedForAllAt: m.deletedForAllAt,
              createdAt: m.createdAt,
            },
            ts: Date.now(),
          });
        }
      }

      break;
    }

    /* =========================================================
       MESSAGE SEND (real-time)
    ========================================================= */
    case 'MESSAGE_SEND': {
      const payload = msg.payload as MessageSendPayload | undefined;
      if (!payload || typeof payload.conversationId !== 'string') {
        ws.close();
        return;
      }

      const contentType = payload.contentType ?? 'text';
      if (
        contentType !== 'text' &&
        contentType !== 'system' &&
        contentType !== 'media'
      ) {
        sendEvent(ws, {
          type: 'ERROR',
          payload: { code: 'INVALID_TYPE', message: 'Invalid content type' },
          ts: Date.now(),
        });
        return;
      }

      const body = typeof payload.body === 'string' ? payload.body : '';

      if (contentType === 'media') {
        if (typeof payload.mediaAssetId !== 'string') {
          sendEvent(ws, {
            type: 'ERROR',
            payload: {
              code: 'INVALID_MEDIA',
              message: 'Media asset required',
            },
            ts: Date.now(),
          });
          return;
        }

        if (body.length > MAX_MESSAGE_BODY_LENGTH) {
          sendEvent(ws, {
            type: 'ERROR',
            payload: {
              code: 'INVALID_BODY',
              message: 'Invalid body length',
            },
            ts: Date.now(),
          });
          return;
        }
      } else {
        if (
          typeof payload.body !== 'string' ||
          body.length === 0 ||
          body.length > MAX_MESSAGE_BODY_LENGTH
        ) {
          sendEvent(ws, {
            type: 'ERROR',
            payload: {
              code: 'INVALID_BODY',
              message: 'Invalid body length',
            },
            ts: Date.now(),
          });
          return;
        }

        if (payload.mediaAssetId) {
          sendEvent(ws, {
            type: 'ERROR',
            payload: {
              code: 'INVALID_MEDIA',
              message: 'Media asset not allowed',
            },
            ts: Date.now(),
          });
          return;
        }
      }

      const member = await conversationsService.getMembership({
        conversationId: payload.conversationId,
        userId,
      });
      if (!member) {
        sendEvent(ws, {
          type: 'ERROR',
          payload: { code: 'NOT_MEMBER', message: 'Not in conversation' },
          ts: Date.now(),
        });
        return;
      }

      const clientTimestamp = payload.clientTimestamp
        ? new Date(payload.clientTimestamp)
        : null;

      let result;
      try {
        result = await messagesService.sendMessage({
          conversationId: payload.conversationId,
          senderUserId: userId,
          senderDeviceId: deviceId,
          body,
          contentType,
          clientTimestamp,
          clientTempId: payload.tempId ?? null,
          mediaAssetId: payload.mediaAssetId ?? null,
        });
      } catch {
        sendEvent(ws, {
          type: 'ERROR',
          payload: { code: 'SEND_FAILED', message: 'Failed to send message' },
          ts: Date.now(),
        });
        return;
      }

      const inserted = result.message;

      if (result.created) {
        hub.publishToConversation(payload.conversationId, {
          type: 'MESSAGE_PUSH',
          payload: {
            messageId: inserted.id,
            conversationId: payload.conversationId,
            seq: inserted.seq,
            senderUserId: inserted.senderUserId,
            senderDeviceId: inserted.senderDeviceId,
            body: inserted.body,
            contentType: inserted.contentType,
            mediaAssetId: inserted.mediaAssetId,
            editVersion: inserted.editVersion,
            deletedForAllAt: inserted.deletedForAllAt,
            createdAt: inserted.createdAt,
          },
          ts: Date.now(),
        });
      }

      hub.publishToUser(userId, {
        type: 'MESSAGE_ACK',
        payload: {
          tempId: payload.tempId,
          conversationId: payload.conversationId,
          messageId: inserted.id,
          seq: inserted.seq,
          createdAt: inserted.createdAt,
          created: result.created,
        },
        ts: Date.now(),
      });

      break;
    }

    /* =========================================================
       READ RECEIPT
    ========================================================= */
    case 'READ_RECEIPT': {
      const payload = msg.payload as ReadReceiptPayload | undefined;
      if (
        !payload ||
        typeof payload.conversationId !== 'string' ||
        typeof payload.lastReadSeq !== 'number'
      ) {
        ws.close();
        return;
      }

      if (payload.lastReadSeq < 0) {
        sendEvent(ws, {
          type: 'ERROR',
          payload: { code: 'INVALID_READ', message: 'Invalid read cursor' },
          ts: Date.now(),
        });
        return;
      }

      const member = await conversationsService.getMembership({
        conversationId: payload.conversationId,
        userId,
      });
      if (!member) {
        sendEvent(ws, {
          type: 'ERROR',
          payload: { code: 'NOT_MEMBER', message: 'Not in conversation' },
          ts: Date.now(),
        });
        return;
      }

      await messagesService.markRead({
        conversationId: payload.conversationId,
        userId,
        deviceId,
        lastReadSeq: payload.lastReadSeq,
      });

      hub.publishToConversation(payload.conversationId, {
        type: 'READ_UPDATE',
        payload: {
          conversationId: payload.conversationId,
          userId,
          lastReadSeq: payload.lastReadSeq,
        },
        ts: Date.now(),
      });

      break;
    }

    /* =========================================================
       DELIVERY RECEIPT
    ========================================================= */
    case 'DELIVERY_RECEIPT': {
      const payload = msg.payload as DeliveryReceiptPayload | undefined;
      if (
        !payload ||
        typeof payload.conversationId !== 'string' ||
        typeof payload.lastDeliveredSeq !== 'number'
      ) {
        ws.close();
        return;
      }

      if (payload.lastDeliveredSeq < 0) {
        sendEvent(ws, {
          type: 'ERROR',
          payload: {
            code: 'INVALID_DELIVERED',
            message: 'Invalid delivery cursor',
          },
          ts: Date.now(),
        });
        return;
      }

      const member = await conversationsService.getMembership({
        conversationId: payload.conversationId,
        userId,
      });
      if (!member) {
        sendEvent(ws, {
          type: 'ERROR',
          payload: { code: 'NOT_MEMBER', message: 'Not in conversation' },
          ts: Date.now(),
        });
        return;
      }

      await messagesService.markDelivered({
        conversationId: payload.conversationId,
        userId,
        deviceId,
        lastDeliveredSeq: payload.lastDeliveredSeq,
      });

      hub.publishToConversation(payload.conversationId, {
        type: 'DELIVERY_UPDATE',
        payload: {
          conversationId: payload.conversationId,
          userId,
          lastDeliveredSeq: payload.lastDeliveredSeq,
        },
        ts: Date.now(),
      });

      break;
    }

    /* =========================================================
       MESSAGE EDIT
    ========================================================= */
    case 'MESSAGE_EDIT': {
      const payload = msg.payload as MessageEditPayload | undefined;
      if (
        !payload ||
        typeof payload.conversationId !== 'string' ||
        typeof payload.messageId !== 'string' ||
        typeof payload.body !== 'string'
      ) {
        ws.close();
        return;
      }

      if (
        payload.body.length === 0 ||
        payload.body.length > MAX_MESSAGE_BODY_LENGTH
      ) {
        sendEvent(ws, {
          type: 'ERROR',
          payload: { code: 'INVALID_BODY', message: 'Invalid body length' },
          ts: Date.now(),
        });
        return;
      }

      const member = await conversationsService.getMembership({
        conversationId: payload.conversationId,
        userId,
      });
      if (!member) {
        sendEvent(ws, {
          type: 'ERROR',
          payload: { code: 'NOT_MEMBER', message: 'Not in conversation' },
          ts: Date.now(),
        });
        return;
      }

      const updated = await messagesService.editMessage({
        conversationId: payload.conversationId,
        messageId: payload.messageId,
        userId,
        body: payload.body,
      });

      if (!updated) {
        sendEvent(ws, {
          type: 'ERROR',
          payload: { code: 'EDIT_DENIED', message: 'Cannot edit message' },
          ts: Date.now(),
        });
        return;
      }

      hub.publishToConversation(payload.conversationId, {
        type: 'MESSAGE_EDIT',
        payload: {
          conversationId: payload.conversationId,
          messageId: payload.messageId,
          body: updated.body,
          editVersion: updated.editVersion,
        },
        ts: Date.now(),
      });

      break;
    }

    /* =========================================================
       MESSAGE DELETE
    ========================================================= */
    case 'MESSAGE_DELETE': {
      const payload = msg.payload as MessageDeletePayload | undefined;
      if (
        !payload ||
        typeof payload.conversationId !== 'string' ||
        typeof payload.messageId !== 'string'
      ) {
        ws.close();
        return;
      }

      const member = await conversationsService.getMembership({
        conversationId: payload.conversationId,
        userId,
      });
      if (!member) {
        sendEvent(ws, {
          type: 'ERROR',
          payload: { code: 'NOT_MEMBER', message: 'Not in conversation' },
          ts: Date.now(),
        });
        return;
      }

      const updated = await messagesService.deleteMessageForAll({
        conversationId: payload.conversationId,
        messageId: payload.messageId,
        userId,
      });

      if (!updated) {
        sendEvent(ws, {
          type: 'ERROR',
          payload: { code: 'DELETE_DENIED', message: 'Cannot delete message' },
          ts: Date.now(),
        });
        return;
      }

      hub.publishToConversation(payload.conversationId, {
        type: 'MESSAGE_DELETE',
        payload: {
          conversationId: payload.conversationId,
          messageId: payload.messageId,
          deletedForAllAt: updated.deletedForAllAt,
        },
        ts: Date.now(),
      });

      break;
    }

    /* =========================================================
       MESSAGE REACTION
    ========================================================= */
    case 'REACTION_SET': {
      const payload = msg.payload as ReactionPayload | undefined;
      if (
        !payload ||
        typeof payload.conversationId !== 'string' ||
        typeof payload.messageId !== 'string' ||
        typeof payload.emoji !== 'string'
      ) {
        ws.close();
        return;
      }

      if (payload.emoji.length === 0 || payload.emoji.length > 16) {
        sendEvent(ws, {
          type: 'ERROR',
          payload: { code: 'INVALID_REACTION', message: 'Invalid emoji' },
          ts: Date.now(),
        });
        return;
      }

      const member = await conversationsService.getMembership({
        conversationId: payload.conversationId,
        userId,
      });
      if (!member) {
        sendEvent(ws, {
          type: 'ERROR',
          payload: { code: 'NOT_MEMBER', message: 'Not in conversation' },
          ts: Date.now(),
        });
        return;
      }

      const reaction = await messagesService.setReaction({
        conversationId: payload.conversationId,
        messageId: payload.messageId,
        userId,
        emoji: payload.emoji,
      });

      if (!reaction) {
        sendEvent(ws, {
          type: 'ERROR',
          payload: { code: 'REACTION_FAILED', message: 'Failed to react' },
          ts: Date.now(),
        });
        return;
      }

      hub.publishToConversation(payload.conversationId, {
        type: 'REACTION_UPDATE',
        payload: {
          conversationId: payload.conversationId,
          messageId: payload.messageId,
          userId,
          emoji: reaction.emoji,
          updatedAt: reaction.updatedAt,
        },
        ts: Date.now(),
      });

      break;
    }

    case 'REACTION_REMOVE': {
      const payload = msg.payload as ReactionPayload | undefined;
      if (
        !payload ||
        typeof payload.conversationId !== 'string' ||
        typeof payload.messageId !== 'string'
      ) {
        ws.close();
        return;
      }

      const member = await conversationsService.getMembership({
        conversationId: payload.conversationId,
        userId,
      });
      if (!member) {
        sendEvent(ws, {
          type: 'ERROR',
          payload: { code: 'NOT_MEMBER', message: 'Not in conversation' },
          ts: Date.now(),
        });
        return;
      }

      const removed = await messagesService.removeReaction({
        conversationId: payload.conversationId,
        messageId: payload.messageId,
        userId,
      });

      if (!removed) {
        sendEvent(ws, {
          type: 'ERROR',
          payload: { code: 'REACTION_MISSING', message: 'Reaction not found' },
          ts: Date.now(),
        });
        return;
      }

      hub.publishToConversation(payload.conversationId, {
        type: 'REACTION_UPDATE',
        payload: {
          conversationId: payload.conversationId,
          messageId: payload.messageId,
          userId,
          emoji: null,
        },
        ts: Date.now(),
      });

      break;
    }

    /* =========================================================
       TYPING INDICATOR
    ========================================================= */
    case 'TYPING_START':
    case 'TYPING_STOP': {
      const payload = msg.payload as TypingPayload | undefined;
      if (!payload || typeof payload.conversationId !== 'string') {
        ws.close();
        return;
      }

      const member = await conversationsService.getMembership({
        conversationId: payload.conversationId,
        userId,
      });
      if (!member) {
        return;
      }

      hub.publishToConversation(payload.conversationId, {
        type: 'TYPING',
        payload: {
          conversationId: payload.conversationId,
          userId,
          isTyping: msg.type === 'TYPING_START',
        },
        ts: Date.now(),
      });

      break;
    }

    /* =========================================================
       SUBSCRIBE TO CONVERSATION
    ========================================================= */
    case 'CONVERSATION_SUBSCRIBE': {
      const payload = msg.payload as SubscribePayload | undefined;
      if (!payload || typeof payload.conversationId !== 'string') {
        ws.close();
        return;
      }

      const member = await conversationsService.getMembership({
        conversationId: payload.conversationId,
        userId,
      });
      if (!member) {
        sendEvent(ws, {
          type: 'ERROR',
          payload: { code: 'NOT_MEMBER', message: 'Not in conversation' },
          ts: Date.now(),
        });
        return;
      }

      hub.subscribeConversation(ws, payload.conversationId);
      break;
    }

    /* =========================================================
       FEED SUBSCRIBE (global feed)
    ========================================================= */
    case 'FEED_SUBSCRIBE': {
      hub.subscribeFeed(ws);
      break;
    }

    /* =========================================================
       PING
    ========================================================= */
    case 'PING': {
      sendEvent(ws, { type: 'PONG', ts: Date.now() });
      break;
    }

    /* =========================================================
       UNKNOWN MESSAGE
    ========================================================= */
    default: {
      // ignore unknown frames silently
      break;
    }
  }
}
