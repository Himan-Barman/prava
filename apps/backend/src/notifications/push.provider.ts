import admin from 'firebase-admin';
import apn from 'apn';

import { config } from '@/app.config';

type PushPlatform = 'android' | 'ios' | 'web' | 'desktop';

export type PushMessage = {
  title: string;
  body: string;
  data?: Record<string, string>;
};

export type PushSendResult =
  | { ok: true }
  | { ok: false; reason: 'not-configured' | 'invalid-token' | 'error'; detail?: string };

type PushToken = {
  token: string;
  platform: PushPlatform;
};

let fcmApp: admin.app.App | null = null;
let apnProvider: apn.Provider | null = null;
let apnBundleId: string | null = null;

const normalizePem = (value: string) =>
  value.includes('\\n') ? value.replace(/\\n/g, '\n') : value;

const maybeDecode = (value: string) => {
  if (value.includes('BEGIN')) return value;
  try {
    return Buffer.from(value, 'base64').toString('utf8');
  } catch {
    return value;
  }
};

const initFcm = () => {
  if (fcmApp) return;
  const raw = config.FCM_SERVICE_ACCOUNT_JSON;
  if (!raw) return;

  let parsed: any;
  try {
    parsed = JSON.parse(raw);
  } catch {
    try {
      parsed = JSON.parse(Buffer.from(raw, 'base64').toString('utf8'));
    } catch {
      console.warn('FCM service account JSON invalid');
      return;
    }
  }

  if (parsed.private_key) {
    parsed.private_key = normalizePem(parsed.private_key);
  }

  try {
    fcmApp = admin.initializeApp({
      credential: admin.credential.cert(parsed),
    });
  } catch (err) {
    console.warn('FCM init failed');
  }
};

const initApns = () => {
  if (apnProvider) return;

  const keyId = config.APNS_KEY_ID;
  const teamId = config.APNS_TEAM_ID;
  const bundleId = config.APNS_BUNDLE_ID;
  const key = config.APNS_PRIVATE_KEY;

  if (!keyId || !teamId || !bundleId || !key) return;

  apnBundleId = bundleId;

  const normalized = normalizePem(maybeDecode(key));
  apnProvider = new apn.Provider({
    token: {
      key: normalized,
      keyId,
      teamId,
    },
    production: config.APNS_ENV === 'production',
  });
};

const isInvalidFcmToken = (code?: string) =>
  code === 'messaging/invalid-registration-token' ||
  code === 'messaging/registration-token-not-registered';

const isInvalidApnsReason = (reason?: string) =>
  reason === 'BadDeviceToken' ||
  reason === 'Unregistered' ||
  reason === 'DeviceTokenNotForTopic';

export const canSendPush = (platform: PushPlatform) => {
  initFcm();
  initApns();

  if (platform === 'ios') {
    return Boolean(apnProvider);
  }

  return Boolean(fcmApp);
};

export const sendPush = async (
  token: PushToken,
  message: PushMessage,
): Promise<PushSendResult> => {
  initFcm();
  initApns();

  if (token.platform === 'ios') {
    if (!apnProvider || !apnBundleId) {
      return { ok: false, reason: 'not-configured' };
    }

    const notification = new apn.Notification();
    notification.topic = apnBundleId;
    notification.alert = {
      title: message.title,
      body: message.body,
    };
    notification.payload = message.data ?? {};
    notification.sound = 'default';
    notification.contentAvailable = true;

    try {
      const result = await apnProvider.send(notification, token.token);
      const failed = result.failed?.[0];
      if (!failed) return { ok: true };

      const reason = failed.response?.reason ?? failed.error?.reason;
      if (isInvalidApnsReason(reason)) {
        return { ok: false, reason: 'invalid-token', detail: reason };
      }

      return { ok: false, reason: 'error', detail: reason };
    } catch (err: any) {
      return { ok: false, reason: 'error', detail: err?.message };
    }
  }

  if (!fcmApp) {
    return { ok: false, reason: 'not-configured' };
  }

  try {
    await fcmApp.messaging().send({
      token: token.token,
      notification: {
        title: message.title,
        body: message.body,
      },
      data: message.data,
      android: { priority: 'high' },
      webpush: { headers: { Urgency: 'high' } },
    });
    return { ok: true };
  } catch (err: any) {
    const code = err?.code;
    if (isInvalidFcmToken(code)) {
      return { ok: false, reason: 'invalid-token', detail: code };
    }

    return { ok: false, reason: 'error', detail: err?.message };
  }
};
