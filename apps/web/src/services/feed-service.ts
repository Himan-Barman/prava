import { apiClient } from '../adapters/api-client';

export interface FeedPost {
  id: string;
  body: string;
  userId: string;
  user: {
    id: string;
    username: string;
    displayName: string;
    avatarUrl?: string;
  };
  media?: {
    type: 'image' | 'video';
    url: string;
    thumbnailUrl?: string;
  }[];
  stats: {
    likes: number;
    comments: number;
    shares: number;
  };
  hasLiked: boolean;
  createdAt: string;
}

export interface Comment {
  id: string;
  body: string;
  user: {
    id: string;
    username: string;
    displayName: string;
    avatarUrl?: string;
  };
  createdAt: string;
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
    return apiClient.post<{ liked: boolean; count: number }>(`/feed/${postId}/like`, {
      auth: true,
    });
  }

  async listComments(postId: string, limit?: number) {
    return apiClient.get<Comment[]>(`/feed/${postId}/comments`, {
      query: {
        ...(limit && { limit: limit.toString() }),
      },
      auth: true,
    });
  }

  async addComment(postId: string, body: string) {
    return apiClient.post<Comment>(`/feed/${postId}/comments`, {
      body: { body },
      auth: true,
    });
  }

  async sharePost(postId: string) {
    return apiClient.post<void>(`/feed/${postId}/share`, {
      auth: true,
    });
  }
}

export const feedService = new FeedService();
