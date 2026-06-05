import { apiClient } from '../adapters/api-client';

export interface UserSearchResult {
  id: string;
  username: string;
  displayName: string;
  avatarUrl?: string;
  isVerified: boolean;
  isFollowing: boolean;
  isFollowedBy: boolean;
}

export interface SmartHashtagResult {
  tag: string;
  postCount: number;
  rankScore: number;
  lastPostAt?: string | null;
}

export interface SmartPostSearchResult {
  id: string;
  body: string;
  createdAt: string;
  likeCount: number;
  commentCount: number;
  shareCount: number;
  hashtags: string[];
  author: {
    id: string;
    username: string;
    displayName: string;
    avatarUrl?: string;
    isVerified?: boolean;
  };
}

export interface SmartSearchResponse {
  accounts: UserSearchResult[];
  hashtags: SmartHashtagResult[];
  posts: SmartPostSearchResult[];
}

class UsersService {
  async getMe() {
    return apiClient.get<{ userId: string }>('/users/me', { auth: true });
  }

  async searchUsers(query: string, limit?: number): Promise<UserSearchResult[]> {
    const data = await apiClient.get<{ results?: UserSearchResult[] }>(
      '/users/search',
      {
        query: {
          query,
          ...(limit && { limit: limit.toString() }),
        },
        auth: true,
      }
    );
    return data.results ?? [];
  }

  async smartSearch(query: string, limit = 8): Promise<SmartSearchResponse> {
    const data = await apiClient.get<Partial<SmartSearchResponse>>('/users/smart-search', {
      query: {
        query,
        limit: limit.toString(),
      },
      auth: true,
    });
    return {
      accounts: data.accounts ?? [],
      hashtags: data.hashtags ?? [],
      posts: data.posts ?? [],
    };
  }

  async toggleFollow(targetUserId: string) {
    return apiClient.post<{ following: boolean }>(`/users/${targetUserId}/follow`, {
      auth: true,
    });
  }

  async setFollow(targetUserId: string, follow: boolean) {
    return apiClient.put<{ following: boolean; changed?: boolean }>(
      `/users/${targetUserId}/follow`,
      {
        auth: true,
        body: { follow },
      }
    );
  }

  async removeFollower(targetUserId: string) {
    return apiClient.delete<{ removed: boolean }>(`/users/${targetUserId}/follower`, {
      auth: true,
    });
  }

  async removeConnection(targetUserId: string) {
    return apiClient.delete<{ removed: boolean }>(
      `/users/${targetUserId}/connection`,
      { auth: true }
    );
  }
}

export const usersService = new UsersService();
