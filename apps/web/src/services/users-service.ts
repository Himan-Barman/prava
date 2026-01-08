import { apiClient } from '../adapters/api-client';

export interface UserProfile {
  id: string;
  username: string;
  displayName: string;
  bio?: string;
  avatarUrl?: string;
  coverUrl?: string;
  stats: {
    followers: number;
    following: number;
    posts: number;
  };
  isFollowing?: boolean;
  isFollower?: boolean;
}

class UsersService {
  async getMe() {
    return apiClient.get<{ userId: string }>('/users/me', { auth: true });
  }

  async getProfile(userId: string) {
    return apiClient.get<UserProfile>(`/users/${userId}/profile`, { auth: true });
  }

  async searchUsers(query: string, limit?: number) {
    return apiClient.get<UserProfile[]>('/users/search', {
      query: {
        query,
        ...(limit && { limit: limit.toString() }),
      },
      auth: true,
    });
  }

  async toggleFollow(targetUserId: string) {
    return apiClient.post<{ following: boolean }>(`/users/${targetUserId}/follow`, {
      auth: true,
    });
  }

  async getConnections(limit?: number) {
    return apiClient.get<UserProfile[]>('/users/me/connections', {
      query: {
        ...(limit && { limit: limit.toString() }),
      },
      auth: true,
    });
  }
}

export const usersService = new UsersService();
