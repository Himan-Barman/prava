/**
 * Secure Storage for tokens
 * Web implementation using localStorage with prefix
 */

const PREFIX = 'prava_';

const keys = {
  accessToken: `${PREFIX}access_token`,
  refreshToken: `${PREFIX}refresh_token`,
  userId: `${PREFIX}user_id`,
  deviceId: `${PREFIX}device_id`,
} as const;

export const secureStore = {
  // Access Token
  getAccessToken(): string | null {
    return localStorage.getItem(keys.accessToken);
  },
  setAccessToken(token: string): void {
    localStorage.setItem(keys.accessToken, token);
  },
  removeAccessToken(): void {
    localStorage.removeItem(keys.accessToken);
  },

  // Refresh Token
  getRefreshToken(): string | null {
    return localStorage.getItem(keys.refreshToken);
  },
  setRefreshToken(token: string): void {
    localStorage.setItem(keys.refreshToken, token);
  },
  removeRefreshToken(): void {
    localStorage.removeItem(keys.refreshToken);
  },

  // User ID
  getUserId(): string | null {
    return localStorage.getItem(keys.userId);
  },
  setUserId(id: string): void {
    localStorage.setItem(keys.userId, id);
  },
  removeUserId(): void {
    localStorage.removeItem(keys.userId);
  },

  // Device ID
  getDeviceId(): string | null {
    return localStorage.getItem(keys.deviceId);
  },
  setDeviceId(id: string): void {
    localStorage.setItem(keys.deviceId, id);
  },

  // Clear all session data
  clearSession(): void {
    localStorage.removeItem(keys.accessToken);
    localStorage.removeItem(keys.refreshToken);
    localStorage.removeItem(keys.userId);
    // Keep device ID on logout
  },
};
