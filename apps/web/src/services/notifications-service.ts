import { apiClient } from '../adapters/api-client';

export interface NotificationActor {
  id: string;
  username: string;
  displayName: string;
  isVerified: boolean;
}

export interface NotificationItem {
  id: string;
  type: string;
  title: string;
  body: string;
  createdAt: string;
  readAt?: string | null;
  data?: Record<string, unknown>;
  actor?: NotificationActor | null;
}

export interface NotificationPage {
  items: NotificationItem[];
  nextCursor?: string | null;
  unreadCount: number;
}

class NotificationsService {
  async fetchNotifications(limit = 20, cursor?: string): Promise<NotificationPage> {
    const query: Record<string, string> = { limit: limit.toString() };
    if (cursor) {
      query.cursor = cursor;
    }

    const data = await apiClient.get<NotificationPage>('/notifications', {
      auth: true,
      query,
    });

    return {
      items: data.items ?? [],
      nextCursor: data.nextCursor ?? null,
      unreadCount: data.unreadCount ?? 0,
    };
  }

  async fetchUnreadCount(): Promise<number> {
    const data = await apiClient.get<{ count?: number }>(
      '/notifications/unread-count',
      { auth: true }
    );
    return typeof data.count === 'number' ? data.count : 0;
  }

  async markRead(notificationId: string) {
    await apiClient.post(`/notifications/${notificationId}/read`, {
      auth: true,
    });
  }

  async markAllRead() {
    await apiClient.post('/notifications/read-all', { auth: true });
  }
}

export const notificationsService = new NotificationsService();
