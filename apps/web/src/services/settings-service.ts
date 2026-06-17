import { apiClient } from '../adapters/api-client';

export type SettingsCategoryKey =
  | 'profile_visibility'
  | 'privacy'
  | 'security'
  | 'notifications'
  | 'chats'
  | 'feed'
  | 'friends'
  | 'appearance'
  | 'accessibility'
  | 'data_storage'
  | 'ai_personalization'
  | 'creator';

export interface SettingsState {
  privateAccount: boolean;
  activityStatus: boolean;
  readReceipts: boolean;
  messagePreview: boolean;
  sensitiveContent: boolean;
  locationSharing: boolean;
  twoFactor: boolean;
  loginAlerts: boolean;
  appLock: boolean;
  biometrics: boolean;
  pushNotifications: boolean;
  emailNotifications: boolean;
  inAppSounds: boolean;
  inAppHaptics: boolean;
  notifyPosts: boolean;
  notifyChats: boolean;
  notifyMentions: boolean;
  notifyFollows: boolean;
  dataSaver: boolean;
  autoDownload: boolean;
  autoPlayVideos: boolean;
  reduceMotion: boolean;
  themeIndex: number;
  textScale: number;
  languageLabel: string;
  whoCanMessage: string;
  whoCanAddToGroups: string;
  defaultFeedMode: string;
  personalizationLevel: string;
  contentSafetyLevel: string;
  displayDensity: string;
  fontSize: string;
  mediaQuality: string;
  quietHours: boolean;
  showRecommendedPosts: boolean;
  showTrendingPosts: boolean;
  showFriendsFirst: boolean;
  highContrast: boolean;
  boldText: boolean;
  reduceTransparency: boolean;
  largerTouchTargets: boolean;
  screenReaderEnhancedLabels: boolean;
  disableAutoplay: boolean;
  aiPersonalizedFeed: boolean;
  aiFriendSuggestions: boolean;
  aiPostRecommendations: boolean;
  aiSmartReplies: boolean;
  creatorMode: boolean;
  professionalMode: boolean;
  publicContactButton: boolean;
  showCreatorBadge: boolean;
}

export interface SettingsAccount {
  id: string;
  displayName: string;
  username: string;
  email: string;
  avatarUrl: string;
  isVerified: boolean;
  accountType: string;
  language: string;
  countryRegion: string;
  profileCompletion: number;
  createdAt?: string | null;
}

export interface SettingsBundle {
  account?: SettingsAccount;
  profile_visibility?: Record<string, unknown>;
  privacy?: Record<string, unknown>;
  security?: Record<string, unknown>;
  notifications?: Record<string, unknown>;
  chats?: Record<string, unknown>;
  feed?: Record<string, unknown>;
  friends?: Record<string, unknown>;
  appearance?: Record<string, unknown>;
  accessibility?: Record<string, unknown>;
  data_storage?: Record<string, unknown>;
  ai_personalization?: Record<string, unknown>;
  creator?: Record<string, unknown>;
  allowed_values?: Record<string, string[]>;
  warnings?: Record<string, string[]>;
  capabilities?: Record<string, unknown>;
  feature_availability?: Record<string, unknown>;
  legacy?: Partial<SettingsState>;
  last_updated?: string;
}

export interface SettingsSearchItem {
  title: string;
  subtitle: string;
  category: string;
}

export interface SettingsAuditItem {
  category: string;
  key: string;
  sensitivity: string;
  changedAt?: string | null;
}

export const defaultSettings: SettingsState = {
  privateAccount: false,
  activityStatus: true,
  readReceipts: true,
  messagePreview: true,
  sensitiveContent: false,
  locationSharing: false,
  twoFactor: false,
  loginAlerts: true,
  appLock: false,
  biometrics: true,
  pushNotifications: true,
  emailNotifications: false,
  inAppSounds: true,
  inAppHaptics: true,
  notifyPosts: true,
  notifyChats: true,
  notifyMentions: true,
  notifyFollows: true,
  dataSaver: false,
  autoDownload: true,
  autoPlayVideos: true,
  reduceMotion: false,
  themeIndex: 0,
  textScale: 1,
  languageLabel: 'English',
  whoCanMessage: 'everyone',
  whoCanAddToGroups: 'friends',
  defaultFeedMode: 'forYou',
  personalizationLevel: 'balanced',
  contentSafetyLevel: 'balanced',
  displayDensity: 'comfortable',
  fontSize: 'default',
  mediaQuality: 'auto',
  quietHours: false,
  showRecommendedPosts: true,
  showTrendingPosts: true,
  showFriendsFirst: false,
  highContrast: false,
  boldText: false,
  reduceTransparency: false,
  largerTouchTargets: false,
  screenReaderEnhancedLabels: true,
  disableAutoplay: false,
  aiPersonalizedFeed: true,
  aiFriendSuggestions: true,
  aiPostRecommendations: true,
  aiSmartReplies: false,
  creatorMode: false,
  professionalMode: false,
  publicContactButton: false,
  showCreatorBadge: false,
};

const categoryEndpoints: Record<SettingsCategoryKey, string> = {
  profile_visibility: '/settings/profile-visibility',
  privacy: '/settings/privacy',
  security: '/settings/security',
  notifications: '/settings/notifications',
  chats: '/settings/chats',
  feed: '/settings/feed',
  friends: '/settings/friends',
  appearance: '/settings/appearance',
  accessibility: '/settings/accessibility',
  data_storage: '/settings/data-storage',
  ai_personalization: '/settings/ai',
  creator: '/settings/creator',
};

function mergeLegacy(bundle: SettingsBundle | { settings?: Partial<SettingsState> } | Partial<SettingsState>): SettingsState {
  if ('legacy' in bundle && bundle.legacy) {
    return { ...defaultSettings, ...bundle.legacy };
  }
  if ('settings' in bundle && bundle.settings) {
    return { ...defaultSettings, ...bundle.settings };
  }
  return { ...defaultSettings, ...(bundle as Partial<SettingsState>) };
}

class SettingsService {
  async fetchBundle(): Promise<SettingsBundle> {
    return apiClient.get<SettingsBundle>('/settings', { auth: true });
  }

  async fetchSettings(): Promise<SettingsState> {
    const bundle = await this.fetchBundle();
    return mergeLegacy(bundle);
  }

  async fetchSummary() {
    return apiClient.get('/settings/summary', { auth: true });
  }

  async searchSettings(query: string) {
    return apiClient.get<{ items?: SettingsSearchItem[]; groups?: Record<string, SettingsSearchItem[]> }>(
      '/settings/search',
      { auth: true, query: { q: query } }
    );
  }

  async fetchAudit(): Promise<SettingsAuditItem[]> {
    const data = await apiClient.get<{ items?: SettingsAuditItem[] }>('/settings/audit', { auth: true });
    return data.items ?? [];
  }

  async updateSettings(update: Partial<SettingsState>): Promise<SettingsState> {
    const bundle = await apiClient.patch<SettingsBundle>('/settings', {
      auth: true,
      body: update,
    });
    return mergeLegacy(bundle);
  }

  async updateCategory(category: SettingsCategoryKey, update: Record<string, unknown>): Promise<SettingsBundle> {
    return apiClient.patch<SettingsBundle>(categoryEndpoints[category], {
      auth: true,
      body: update,
    });
  }

  async runPrivacyCheckup() {
    return apiClient.post<{ score: number; recommendations: string[] }>('/settings/privacy-checkup', { auth: true });
  }

  async runSecurityCheckup() {
    return apiClient.post<{ score: number; recommendations: string[] }>('/settings/security-checkup', { auth: true });
  }

  async resetFeedPersonalization() {
    return apiClient.post<{ reset: boolean; settings?: SettingsBundle }>('/settings/reset-feed-personalization', { auth: true });
  }

  async clearSearchHistory() {
    return apiClient.post<{ cleared: boolean }>('/settings/clear-search-history', { auth: true });
  }

  async clearCacheMetadata() {
    return apiClient.post<{ cleared: boolean }>('/settings/clear-cache-metadata', { auth: true });
  }

  async requestDataExport() {
    return apiClient.post<{ id: string; status: string; createdAt: string }>('/data-export', { auth: true });
  }

  async logoutAllSessions() {
    return apiClient.post<{ success: boolean }>('/sessions/logout-all', { auth: true });
  }

  async deactivateAccount(password: string, reason?: string) {
    return apiClient.post<{ pending: boolean; requestId: string }>('/account/deactivate', {
      auth: true,
      body: { password, reason },
    });
  }

  async requestAccountDeletion(password: string, confirmation: string, reason?: string) {
    return apiClient.post<{ deletionRequested: boolean; requestId: string; recoveryUntil: string }>(
      '/account/delete-request',
      { auth: true, body: { password, confirmation, reason } }
    );
  }

  async cancelAccountDeletion() {
    return apiClient.post<{ canceled: boolean }>('/account/delete-cancel', { auth: true });
  }
}

export const settingsService = new SettingsService();
