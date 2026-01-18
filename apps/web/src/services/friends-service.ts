import { apiClient } from '../adapters/api-client';

export interface FriendConnectionItem {
  id: string;
  username: string;
  displayName: string;
  bio?: string;
  location?: string;
  isVerified: boolean;
  isOnline?: boolean;
  createdAt?: string | null;
  since?: string | null;
  isFollowing: boolean;
  isFollowedBy: boolean;
}

export interface FriendsResponse {
  requests: FriendConnectionItem[];
  sent: FriendConnectionItem[];
  friends: FriendConnectionItem[];
}

class FriendsService {
  async getConnections(limit = 20): Promise<FriendsResponse> {
    const data = await apiClient.get<FriendsResponse>('/users/me/connections', {
      auth: true,
      query: { limit: limit.toString() },
    });

    return {
      requests: data.requests ?? [],
      sent: data.sent ?? [],
      friends: data.friends ?? [],
    };
  }

  async acceptRequest(userId: string) {
    return apiClient.put(`/users/${userId}/follow`, {
      auth: true,
      body: { follow: true },
    });
  }

  async declineRequest(userId: string) {
    return apiClient.delete(`/users/${userId}/follower`, {
      auth: true,
    });
  }

  async cancelRequest(userId: string) {
    return apiClient.put(`/users/${userId}/follow`, {
      auth: true,
      body: { follow: false },
    });
  }

  async removeFriend(userId: string) {
    return apiClient.delete(`/users/${userId}/connection`, {
      auth: true,
    });
  }
}

export const friendsService = new FriendsService();
