import { apiClient } from '../adapters/api-client';
import { getOrCreateDeviceId } from '../adapters/device-id';

export interface DeviceSession {
  id: string;
  deviceId: string;
  deviceName: string;
  platform: string;
  createdAt?: string | null;
  lastSeenAt?: string | null;
  expiresAt?: string | null;
}

class SessionService {
  currentDeviceId() {
    return getOrCreateDeviceId();
  }

  async listSessions(): Promise<DeviceSession[]> {
    const data = await apiClient.post<DeviceSession[]>('/auth/sessions', {
      auth: true,
    });
    return Array.isArray(data) ? data : [];
  }

  async revokeSession(deviceId: string) {
    await apiClient.post('/auth/sessions/revoke', {
      auth: true,
      body: { deviceId },
    });
  }

  async revokeOtherSessions(currentDeviceId: string) {
    await apiClient.post('/auth/sessions/revoke-others', {
      auth: true,
      body: { currentDeviceId },
    });
  }
}

export const sessionService = new SessionService();
