/**
 * Device ID management
 * Generates and persists a unique device identifier for session binding
 */

import { v4 as uuidv4 } from 'uuid';
import { secureStore } from './secure-store';

export function getOrCreateDeviceId(): string {
  let deviceId = secureStore.getDeviceId();

  if (!deviceId) {
    deviceId = uuidv4();
    secureStore.setDeviceId(deviceId);
  }

  return deviceId;
}

export function getDeviceName(): string {
  if (typeof navigator === 'undefined') return 'Web Browser';

  const ua = navigator.userAgent;

  if (ua.includes('Chrome')) return 'Chrome Browser';
  if (ua.includes('Firefox')) return 'Firefox Browser';
  if (ua.includes('Safari') && !ua.includes('Chrome')) return 'Safari Browser';
  if (ua.includes('Edge')) return 'Edge Browser';

  return 'Web Browser';
}

export function getPlatform(): 'web' {
  return 'web';
}
