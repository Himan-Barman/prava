import { apiClient } from '../adapters/api-client';

export interface BlockedUser {
  id: string;
  username: string;
  displayName: string;
  isVerified: boolean;
  blockedAt?: string | null;
}

export interface MutedWord {
  id: string;
  phrase: string;
  createdAt?: string | null;
}

class PrivacyService {
  async fetchBlocked(limit = 30): Promise<BlockedUser[]> {
    const data = await apiClient.get<{ items?: BlockedUser[] }>(
      '/users/me/blocks',
      {
        auth: true,
        query: { limit: limit.toString() },
      }
    );
    return data.items ?? [];
  }

  async blockUser(userId: string) {
    return apiClient.post<{ blocked: boolean }>(`/users/${userId}/block`, {
      auth: true,
    });
  }

  async unblockUser(userId: string) {
    return apiClient.delete<{ blocked: boolean }>(`/users/${userId}/block`, {
      auth: true,
    });
  }

  async fetchMutedWords(limit = 50): Promise<MutedWord[]> {
    const data = await apiClient.get<{ items?: MutedWord[] }>(
      '/users/me/muted-words',
      {
        auth: true,
        query: { limit: limit.toString() },
      }
    );
    return data.items ?? [];
  }

  async addMutedWord(phrase: string): Promise<MutedWord | null> {
    const data = await apiClient.post<{ item?: MutedWord }>(
      '/users/me/muted-words',
      {
        auth: true,
        body: { phrase },
      }
    );
    return data.item ?? null;
  }

  async removeMutedWord(id: string) {
    return apiClient.delete<{ removed: boolean }>(
      `/users/me/muted-words/${id}`,
      { auth: true }
    );
  }
}

export const privacyService = new PrivacyService();
