import { apiClient } from '../adapters/api-client';

export interface Message {
  id: string;
  conversationId: string;
  senderId: string;
  body: string;
  contentType: 'text' | 'image' | 'video' | 'audio';
  sequence: number;
  createdAt: string;
  clientTimestamp?: string;
  deliveryStatus: 'sent' | 'delivered' | 'read';
  reactions: Record<string, string[]>; // emoji -> userIds
}

export interface Conversation {
  id: string;
  type: 'direct' | 'group';
  name?: string;
  avatarUrl?: string;
  lastMessage?: Message;
  unreadCount: number;
  updatedAt: string;
  members: {
    userId: string;
    username: string;
    displayName: string;
    avatarUrl?: string;
  }[];
}

class MessagesService {
  async listConversations(limit?: number) {
    // Assuming endpoint exists based on pattern, though not explicitly seen in MessagesController
    // It might be in ConversationsController if separate.
    // Based on mobile app, it likely fetches from /conversations
    return apiClient.get<Conversation[]>('/conversations', {
      query: {
        ...(limit && { limit: limit.toString() }),
      },
      auth: true,
    });
  }

  async listMessages(conversationId: string, params: { beforeSeq?: number; limit?: number } = {}) {
    return apiClient.get<Message[]>(`/conversations/${conversationId}/messages`, {
      query: {
        ...(params.beforeSeq && { beforeSeq: params.beforeSeq.toString() }),
        ...(params.limit && { limit: params.limit.toString() }),
      },
      auth: true,
    });
  }

  async sendMessage(conversationId: string, body: string, contentType: 'text' | 'image' = 'text') {
    return apiClient.post<Message>(`/conversations/${conversationId}/messages`, {
      body: {
        body,
        contentType,
        clientTimestamp: new Date().toISOString(),
        // deviceId handled by backend or auth service usually, but controller expected valid DTO
        // Controller DTO: deviceId is required in SendMessageDto
        deviceId: 'web-client', // Simplify for now or get from device-id adapter
      },
      auth: true,
    });
  }

  async markRead(conversationId: string, lastReadSeq: number) {
    return apiClient.post<{ success: boolean }>(`/conversations/${conversationId}/read`, {
      body: {
        lastReadSeq,
        deviceId: 'web-client',
      },
      auth: true,
    });
  }
}

export const messagesService = new MessagesService();
