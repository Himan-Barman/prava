import { apiClient } from '../adapters/api-client';
import { getOrCreateDeviceId } from '../adapters/device-id';

export type MessageContentType = 'text' | 'system' | 'media';

export interface ChatReaction {
  userId: string;
  emoji: string;
  reactedAt?: string | null;
  updatedAt?: string | null;
}

export interface Message {
  id: string;
  conversationId: string;
  senderId: string;
  body: string;
  contentType: MessageContentType;
  sequence?: number;
  mediaAssetId?: string | null;
  replyToMessageId?: string | null;
  editVersion?: number;
  reactions?: ChatReaction[];
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
  memberCount?: number;
  isAdmin?: boolean;
  myRole?: 'owner' | 'admin' | 'member';
}

export interface ConversationMember {
  userId: string;
  role: 'owner' | 'admin' | 'member';
  joinedAt?: string | null;
  leftAt?: string | null;
}

export interface ConversationDetail extends ConversationSummary {
  createdBy?: string | null;
  createdAt?: string | null;
}

export interface ConversationReadState {
  userId: string;
  lastReadSeq: number;
  lastDeliveredSeq: number;
  updatedAt?: string | null;
}

export interface ConversationDelta {
  conversationId: string;
  hasMore: boolean;
  currentSeq: number;
  updatedAt?: string | null;
  messages: Message[];
}

type BackendMessage = {
  id?: string;
  messageId?: string;
  conversationId: string;
  senderUserId: string;
  body?: string;
  contentType?: MessageContentType;
  seq?: number;
  mediaAssetId?: string | null;
  replyToMessageId?: string | null;
  editVersion?: number;
  reactions?: ChatReaction[];
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
    mediaAssetId: input.mediaAssetId ?? null,
    replyToMessageId: input.replyToMessageId ?? null,
    editVersion: input.editVersion ?? 0,
    reactions: input.reactions ?? [],
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

  async getConversation(conversationId: string) {
    return apiClient.get<ConversationDetail>(`/conversations/${conversationId}`, {
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

  async updateGroup(conversationId: string, title: string) {
    return apiClient.patch<{ success: boolean; title: string }>(
      `/conversations/${conversationId}`,
      {
        auth: true,
        body: { title },
      }
    );
  }

  async listMembers(conversationId: string) {
    return apiClient.get<ConversationMember[]>(`/conversations/${conversationId}/members`, {
      auth: true,
    });
  }

  async addMembers(conversationId: string, memberIds: string[]) {
    return apiClient.post<{ success: boolean; added: string[] }>(
      `/conversations/${conversationId}/members`,
      {
        auth: true,
        body: { memberIds },
      }
    );
  }

  async removeMember(conversationId: string, memberUserId: string) {
    return apiClient.delete<{ success: boolean }>(
      `/conversations/${conversationId}/members/${memberUserId}`,
      {
        auth: true,
      }
    );
  }

  async leaveGroup(conversationId: string) {
    return apiClient.post<{ success: boolean }>(
      `/conversations/${conversationId}/leave`,
      {
        auth: true,
      }
    );
  }

  async promoteAdmin(conversationId: string, userId: string) {
    return apiClient.post<{ success: boolean }>(
      `/conversations/${conversationId}/admins`,
      {
        auth: true,
        body: { userId },
      }
    );
  }

  async demoteAdmin(conversationId: string, userId: string) {
    return apiClient.delete<{ success: boolean }>(
      `/conversations/${conversationId}/admins/${userId}`,
      {
        auth: true,
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

  async listReadStates(conversationId: string) {
    return apiClient.get<ConversationReadState[]>(
      `/conversations/${conversationId}/reads`,
      {
        auth: true,
      }
    );
  }

  async syncConversations(
    conversations: Array<{ conversationId: string; lastKnownSeq: number }>,
    limitPerConversation = 50
  ) {
    const data = await apiClient.post<{ conversations?: Array<{
      conversationId: string;
      hasMore: boolean;
      currentSeq: number;
      updatedAt?: string | null;
      messages: BackendMessage[];
    }> }>(
      '/conversations/sync',
      {
        auth: true,
        body: {
          conversations,
          limitPerConversation,
        },
      }
    );

    const payload = Array.isArray(data.conversations) ? data.conversations : [];
    return payload.map((item) => ({
      conversationId: item.conversationId,
      hasMore: item.hasMore,
      currentSeq: item.currentSeq,
      updatedAt: item.updatedAt ?? null,
      messages: (Array.isArray(item.messages) ? item.messages : []).map(normalizeMessage),
    })) as ConversationDelta[];
  }

  async sendMessage(
    conversationId: string,
    body: string,
    contentType: MessageContentType = 'text',
    options?: {
      tempId?: string;
      mediaAssetId?: string;
      replyToMessageId?: string;
    }
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
          ...(options?.tempId && { tempId: options.tempId }),
          ...(options?.mediaAssetId && { mediaAssetId: options.mediaAssetId }),
          ...(options?.replyToMessageId && { replyToMessageId: options.replyToMessageId }),
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

  async editMessage(conversationId: string, messageId: string, body: string) {
    return apiClient.patch<{ success: boolean; message?: BackendMessage }>(
      `/conversations/${conversationId}/messages/${messageId}`,
      {
        auth: true,
        body: { body },
      }
    );
  }

  async deleteMessage(conversationId: string, messageId: string) {
    return apiClient.delete<{ success: boolean }>(
      `/conversations/${conversationId}/messages/${messageId}`,
      {
        auth: true,
      }
    );
  }

  async setReaction(conversationId: string, messageId: string, emoji: string) {
    return apiClient.post<{ success: boolean }>(
      `/conversations/${conversationId}/messages/${messageId}/reactions`,
      {
        auth: true,
        body: { emoji },
      }
    );
  }

  async removeReaction(conversationId: string, messageId: string) {
    return apiClient.delete<{ success: boolean }>(
      `/conversations/${conversationId}/messages/${messageId}/reactions`,
      {
        auth: true,
      }
    );
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

  async markDelivered(conversationId: string, lastDeliveredSeq: number) {
    return apiClient.post<{ success: boolean }>(
      `/conversations/${conversationId}/delivery`,
      {
        body: {
          lastDeliveredSeq,
        },
        auth: true,
      }
    );
  }
}

export { normalizeMessage };
export const messagesService = new MessagesService();
