/**
 * Auth Service
 * Matches mobile's auth_service.dart
 */

import { apiClient } from '../adapters/api-client';
import { secureStore } from '../adapters/secure-store';
import { getOrCreateDeviceId, getDeviceName, getPlatform } from '../adapters/device-id';

export interface AuthSession {
  userId: string;
  email: string;
  accessToken: string;
  refreshToken: string;
  isVerified: boolean;
}

interface AuthResponse {
  accessToken: string;
  refreshToken: string;
  user: {
    id: string;
    email: string;
    isVerified: boolean;
    username?: string;
  };
}

interface UsernameAvailableResponse {
  available: boolean;
}

class AuthService {
  async login(email: string, password: string): Promise<AuthSession> {
    const deviceId = getOrCreateDeviceId();
    const deviceName = getDeviceName();
    const platform = getPlatform();

    const data = await apiClient.post<AuthResponse>('/auth/login', {
      body: {
        email,
        password,
        deviceId,
        deviceName,
        platform,
      },
    });

    const session = this.parseSession(data);
    await this.saveSession(session);
    return session;
  }

  async register(email: string, password: string, username?: string): Promise<AuthSession> {
    const deviceId = getOrCreateDeviceId();
    const deviceName = getDeviceName();
    const platform = getPlatform();

    const body: Record<string, string> = {
      email,
      password,
      deviceId,
      deviceName,
      platform,
    };

    if (username) {
      body.username = username;
    }

    const data = await apiClient.post<AuthResponse>('/auth/register', { body });

    const session = this.parseSession(data);
    await this.saveSession(session);
    return session;
  }

  async isUsernameAvailable(username: string): Promise<boolean> {
    const data = await apiClient.get<UsernameAvailableResponse>('/users/username-available', {
      query: { username },
    });
    return data.available === true;
  }

  async requestEmailOtp(email: string): Promise<void> {
    await apiClient.post('/auth/email-otp/request', {
      body: { email },
    });
  }

  async verifyEmailOtp(email: string, code: string): Promise<void> {
    await apiClient.post('/auth/email-otp/verify', {
      body: { email, code },
    });
  }

  async requestPasswordReset(email: string): Promise<void> {
    await apiClient.post('/auth/password-reset/request', {
      body: { email },
    });
  }

  async confirmPasswordReset(token: string, newPassword: string): Promise<void> {
    await apiClient.post('/auth/password-reset/confirm', {
      body: { token, newPassword },
    });
  }

  async updateUserDetails(details: {
    firstName: string;
    lastName: string;
    phoneCountryCode: string;
    phoneNumber: string;
  }): Promise<void> {
    await apiClient.put('/users/me/details', {
      body: details,
      auth: true,
    });
  }

  async logout(): Promise<void> {
    const deviceId = getOrCreateDeviceId();
    try {
      await apiClient.post('/auth/logout', {
        auth: true,
        body: { deviceId },
      });
    } catch {
      // Ignore logout errors
    }
    secureStore.clearSession();
  }

  isLoggedIn(): boolean {
    return !!secureStore.getAccessToken();
  }

  getUserId(): string | null {
    return secureStore.getUserId();
  }

  private parseSession(data: AuthResponse): AuthSession {
    return {
      userId: data.user?.id || '',
      email: data.user?.email || '',
      accessToken: data.accessToken || '',
      refreshToken: data.refreshToken || '',
      isVerified: data.user?.isVerified === true,
    };
  }

  private async saveSession(session: AuthSession): Promise<void> {
    if (session.accessToken) {
      secureStore.setAccessToken(session.accessToken);
    }
    if (session.refreshToken) {
      secureStore.setRefreshToken(session.refreshToken);
    }
    if (session.userId) {
      secureStore.setUserId(session.userId);
    }
  }
}

export const authService = new AuthService();
