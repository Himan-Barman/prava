import { apiClient } from '../adapters/api-client';

export interface ProfileUser {
  id: string;
  username: string;
  displayName: string;
  bio?: string;
  location?: string;
  website?: string;
  isVerified: boolean;
  createdAt?: string | null;
}

export interface ProfileStats {
  posts: number;
  followers: number;
  following: number;
  likes: number;
}

export interface ProfileFeedPost {
  id: string;
  body: string;
  createdAt: string;
  likeCount: number;
  commentCount: number;
  shareCount: number;
  mentions: string[];
  hashtags: string[];
}

export interface ProfileSummary {
  user: ProfileUser;
  stats: ProfileStats;
  posts: ProfileFeedPost[];
  liked: ProfileFeedPost[];
}

class ProfileService {
  async fetchMyProfile(limit = 12): Promise<ProfileSummary> {
    const data = await apiClient.get<ProfileSummary>('/users/me/profile', {
      auth: true,
      query: { limit: limit.toString() },
    });
    return data;
  }
}

export const profileService = new ProfileService();
