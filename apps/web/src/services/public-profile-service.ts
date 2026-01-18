import { apiClient } from '../adapters/api-client';

export interface PublicProfileUser {
  id: string;
  username: string;
  displayName: string;
  bio?: string;
  location?: string;
  website?: string;
  isVerified: boolean;
  createdAt?: string | null;
}

export interface PublicProfileStats {
  posts: number;
  followers: number;
  following: number;
  likes: number;
}

export interface PublicProfilePost {
  id: string;
  body: string;
  createdAt: string;
  likeCount: number;
  commentCount: number;
  shareCount: number;
  mentions: string[];
  hashtags: string[];
}

export interface PublicProfileRelationship {
  isFollowing: boolean;
  isFollowedBy: boolean;
}

export interface PublicProfileSummary {
  user: PublicProfileUser;
  stats: PublicProfileStats;
  posts: PublicProfilePost[];
  relationship: PublicProfileRelationship;
}

class PublicProfileService {
  async fetchProfile(userId: string, limit = 12): Promise<PublicProfileSummary> {
    const data = await apiClient.get<PublicProfileSummary>(`/users/${userId}/profile`, {
      auth: true,
      query: { limit: limit.toString() },
    });
    return data;
  }
}

export const publicProfileService = new PublicProfileService();
