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
  recommendationReason?: string | null;
  recommendationReasons?: string[];
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

export interface FeedPageResponse {
  items: FeedPost[];
  nextCursor: string | null;
  metrics?: {
    mode: 'for-you' | 'following';
    candidateCount: number;
    filteredCount: number;
    fallbackUsed: string | null;
    sourceCounts: Record<string, number>;
    durationMs: number;
  };
}

export interface FeedEventPayload {
  type: string;
  postId?: string;
  commentId?: string | null;
  dwellMs?: number;
  source?: string;
  sessionId?: string;
  clientEventId?: string;
  metadata?: Record<string, unknown>;
}

class FeedService {
  async listFeed(params: { limit?: number; before?: string; mode?: 'following' | 'for-you'; tag?: string; sessionId?: string } = {}) {
    return apiClient.get<FeedPost[]>('/feed', {
      query: {
        ...(params.limit && { limit: params.limit.toString() }),
        ...(params.before && { before: params.before }),
        ...(params.mode && { mode: params.mode }),
        ...(params.tag && { tag: params.tag }),
        ...(params.sessionId && { sessionId: params.sessionId }),
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

  async listFeedPage(params: { limit?: number; cursor?: string; before?: string; mode?: 'following' | 'for-you'; sessionId?: string } = {}) {
    const mode = params.mode === 'following' ? 'following' : 'for-you';
    return apiClient.get<FeedPageResponse>(`/feed/${mode}`, {
      query: {
        ...(params.limit && { limit: params.limit.toString() }),
        ...(params.cursor && { cursor: params.cursor }),
        ...(params.before && { before: params.before }),
        ...(params.sessionId && { sessionId: params.sessionId }),
      },
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

  async recordEvents(events: FeedEventPayload[] | FeedEventPayload) {
    const payload = Array.isArray(events) ? { events } : events;
    return apiClient.post<{ accepted: number }>('/feed/events', {
      body: payload,
      auth: true,
    });
  }

  async hidePost(postId: string, reason = 'hidden') {
    return apiClient.post<{ hidden: boolean }>(`/feed/${postId}/hide`, {
      body: { reason },
      auth: true,
    });
  }

  async markNotInterested(postId: string, reason = 'not_interested') {
    return apiClient.post<{ notInterested: boolean }>(`/feed/${postId}/not-interested`, {
      body: { reason },
      auth: true,
    });
  }
}

export const feedService = new FeedService();
