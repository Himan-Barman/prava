import { apiClient } from '../adapters/api-client';

export interface FeedAuthor {
  id: string;
  username: string;
  displayName: string;
  avatarUrl?: string;
}

export interface FeedPost {
  id: string;
  body: string;
  createdAt: string;
  likeCount: number;
  commentCount: number;
  shareCount: number;
  readCount?: number;
  rankScore?: number;
  liked: boolean;
  followed: boolean;
  mentions: string[];
  hashtags: string[];
  relationship?: 'friend' | 'following' | 'other';
  author: FeedAuthor;
}

export interface FeedComment {
  id: string;
  postId: string;
  parentCommentId?: string | null;
  body: string;
  createdAt: string;
  likeCount: number;
  replyCount: number;
  liked: boolean;
  author: FeedAuthor;
}

export interface FeedTag {
  tag: string;
  postCount: number;
  rankScore: number;
  lastPostAt?: string | null;
}

class FeedService {
  async listFeed(params: { limit?: number; before?: string; mode?: 'following' | 'for-you'; tag?: string } = {}) {
    return apiClient.get<FeedPost[]>('/feed', {
      query: {
        ...(params.limit && { limit: params.limit.toString() }),
        ...(params.before && { before: params.before }),
        ...(params.mode && { mode: params.mode }),
        ...(params.tag && { tag: params.tag }),
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

  async getPost(postId: string) {
    return apiClient.get<FeedPost | null>(`/feed/${postId}`, {
      auth: true,
    });
  }

  async listTags(limit = 16) {
    return apiClient.get<FeedTag[]>('/feed/tags', {
      query: { limit: limit.toString() },
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

  async addComment(postId: string, body: string, parentCommentId?: string) {
    return apiClient.post<{ comment: FeedComment; commentCount: number }>(
      `/feed/${postId}/comments`,
      {
        body: { body, ...(parentCommentId && { parentCommentId }) },
        auth: true,
      }
    );
  }

  async toggleCommentLike(postId: string, commentId: string) {
    return apiClient.post<{ liked: boolean; likeCount: number; commentId: string }>(
      `/feed/${postId}/comments/${commentId}/like`,
      {
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
