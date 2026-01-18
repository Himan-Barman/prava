import { apiClient } from '../adapters/api-client';

export interface FeedAuthor {
  id: string;
  username: string;
  displayName: string;
}

export interface FeedPost {
  id: string;
  body: string;
  createdAt: string;
  likeCount: number;
  commentCount: number;
  shareCount: number;
  liked: boolean;
  followed: boolean;
  mentions: string[];
  hashtags: string[];
  relationship?: 'friend' | 'following' | 'other';
  author: FeedAuthor;
}

export interface FeedComment {
  id: string;
  body: string;
  createdAt: string;
  author: FeedAuthor;
}

class FeedService {
  async listFeed(params: { limit?: number; before?: string; mode?: 'following' | 'for-you' } = {}) {
    return apiClient.get<FeedPost[]>('/feed', {
      query: {
        ...(params.limit && { limit: params.limit.toString() }),
        ...(params.before && { before: params.before }),
        ...(params.mode && { mode: params.mode }),
      },
      auth: true,
    });
  }

  async createPost(body: string) {
    return apiClient.post<FeedPost>('/feed', {
      body: { body },
      auth: true,
    });
  }

  async toggleLike(postId: string) {
    return apiClient.post<{ liked: boolean; likeCount: number }>(`/feed/${postId}/like`, {
      auth: true,
    });
  }

  async listComments(postId: string, limit?: number) {
    return apiClient.get<FeedComment[]>(`/feed/${postId}/comments`, {
      query: {
        ...(limit && { limit: limit.toString() }),
      },
      auth: true,
    });
  }

  async addComment(postId: string, body: string) {
    return apiClient.post<{ comment: FeedComment; commentCount: number }>(
      `/feed/${postId}/comments`,
      {
        body: { body },
        auth: true,
      }
    );
  }

  async sharePost(postId: string) {
    return apiClient.post<{ shared: boolean; shareCount: number; created: boolean }>(
      `/feed/${postId}/share`,
      {
        auth: true,
      }
    );
  }
}

export const feedService = new FeedService();
