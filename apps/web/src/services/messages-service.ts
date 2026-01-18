import { apiClient } from '../adapters/api-client';
import { getOrCreateDeviceId } from '../adapters/device-id';

export type MessageContentType = 'text' | 'system' | 'media';

export interface Message {
  id: string;
  conversationId: string;
  senderId: string;
  body: string;
  contentType: MessageContentType;
  sequence?: number;
  createdAt: string;
  deletedForAllAt?: string | null;
}

export interface ConversationSummary {
  id: string;
  type: 'dm' | 'group';
  title: string;
  unreadCount: number;
  updatedAt: string;
  lastMessageId?: string | null;
  lastMessageSeq?: number | null;
  lastMessageSenderUserId?: string | null;
  lastMessageBody?: string | null;
  lastMessageContentType?: MessageContentType | null;
  lastMessageDeletedForAllAt?: string | null;
  lastMessageCreatedAt?: string | null;
}

type BackendMessage = {
  id?: string;
  messageId?: string;
  conversationId: string;
  senderUserId: string;
  body?: string;
  contentType?: MessageContentType;
  seq?: number;
  createdAt?: string;
  deletedForAllAt?: string | null;
};

const normalizeMessage = (input: BackendMessage): Message => {
  return {
    id: input.id ?? input.messageId ?? '',
    conversationId: input.conversationId,
    senderId: input.senderUserId,
    body: input.body ?? '',
    contentType: input.contentType ?? 'text',
    sequence: input.seq,
    createdAt: input.createdAt ?? new Date().toISOString(),
    deletedForAllAt: input.deletedForAllAt ?? null,
  };
};

class MessagesService {
  async listConversations(limit?: number) {
    return apiClient.get<ConversationSummary[]>('/conversations', {
      query: {
        ...(limit && { limit: limit.toString() }),
      },
      auth: true,
    });
  }

  async createDm(otherUserId: string) {
    return apiClient.post<{ conversationId: string; created?: boolean }>(
      '/conversations/dm',
      {
        auth: true,
        body: { otherUserId },
      }
    );
  }

  async createGroup(title: string, memberIds: string[]) {
    return apiClient.post<{ conversationId: string }>(
      '/conversations/group',
      {
        auth: true,
        body: { title, memberIds },
      }
    );
  }

  async listMessages(
    conversationId: string,
    params: { beforeSeq?: number; limit?: number } = {}
  ) {
    const data = await apiClient.get<BackendMessage[]>(
      `/conversations/${conversationId}/messages`,
      {
        query: {
          ...(params.beforeSeq && { beforeSeq: params.beforeSeq.toString() }),
          ...(params.limit && { limit: params.limit.toString() }),
        },
        auth: true,
      }
    );
    return (Array.isArray(data) ? data : []).map(normalizeMessage);
  }

  async sendMessage(
    conversationId: string,
    body: string,
    contentType: MessageContentType = 'text'
  ) {
    const deviceId = getOrCreateDeviceId();
    const data = await apiClient.post<{ message?: BackendMessage }>(
      `/conversations/${conversationId}/messages`,
      {
        body: {
          body,
          contentType,
          clientTimestamp: new Date().toISOString(),
          deviceId,
        },
        auth: true,
      }
    );
    if (data.message) {
      return normalizeMessage(data.message);
    }
    return normalizeMessage({
      conversationId,
      senderUserId: '',
      body,
      contentType,
    });
  }

  async markRead(conversationId: string, lastReadSeq: number) {
    const deviceId = getOrCreateDeviceId();
    return apiClient.post<{ success: boolean }>(
      `/conversations/${conversationId}/read`,
      {
        body: {
          lastReadSeq,
          deviceId,
        },
        auth: true,
      }
    );
  }
}

export { normalizeMessage };
export const messagesService = new MessagesService();
