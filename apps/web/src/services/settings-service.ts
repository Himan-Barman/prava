import { apiClient } from '../adapters/api-client';

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
  dataSaver: boolean;
  autoDownload: boolean;
  autoPlayVideos: boolean;
  reduceMotion: boolean;
  themeIndex: number;
  textScale: number;
  languageLabel: string;
}

const defaultSettings: SettingsState = {
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
  dataSaver: false,
  autoDownload: true,
  autoPlayVideos: true,
  reduceMotion: false,
  themeIndex: 0,
  textScale: 1.0,
  languageLabel: 'English',
};

class SettingsService {
  async fetchSettings(): Promise<SettingsState> {
    const data = await apiClient.get<{ settings?: Partial<SettingsState> }>(
      '/users/me/settings',
      { auth: true }
    );
    return { ...defaultSettings, ...(data.settings ?? {}) };
  }

  async updateSettings(update: Partial<SettingsState>): Promise<SettingsState> {
    const data = await apiClient.put<{ settings?: Partial<SettingsState> }>(
      '/users/me/settings',
      {
        auth: true,
        body: update,
      }
    );
    return { ...defaultSettings, ...(data.settings ?? {}) };
  }
}

export const settingsService = new SettingsService();
