import { env } from "../../config/env.js";
import { query, queryMany } from "../../lib/pg.js";
import { incrementMetric } from "../../shared/metrics/index.js";

export type PushPayload = {
  token: string;
  title: string;
  body: string;
  data: Record<string, string>;
  priority: "normal" | "high";
};

export type PushSendResult = {
  ok: boolean;
  providerMessageId?: string;
  transient?: boolean;
  invalidToken?: boolean;
  errorCode?: string;
  errorMessage?: string;
};

export interface PushProvider {
  readonly name: string;
  send(payload: PushPayload): Promise<PushSendResult>;
}

export class NoopPushProvider implements PushProvider {
  readonly name = "noop";

  async send(): Promise<PushSendResult> {
    return { ok: true, providerMessageId: "noop" };
  }
}

export class FcmPushProvider implements PushProvider {
  readonly name = "fcm";

  constructor(private readonly serverKey: string) {}

  async send(payload: PushPayload): Promise<PushSendResult> {
    try {
      const response = await fetch("https://fcm.googleapis.com/fcm/send", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: `key=${this.serverKey}`,
        },
        body: JSON.stringify({
          to: payload.token,
          priority: payload.priority,
          notification: {
            title: payload.title,
            body: payload.body,
          },
          data: payload.data,
        }),
      });
      const body: any = await response.json().catch(() => ({}));
      if (response.ok) {
        const messageId = body?.results?.[0]?.message_id || body?.message_id;
        const error = body?.results?.[0]?.error;
        if (error) {
          return {
            ok: false,
            transient: ["Unavailable", "InternalServerError", "DeviceMessageRateExceeded"].includes(String(error)),
            invalidToken: ["InvalidRegistration", "NotRegistered"].includes(String(error)),
            errorCode: String(error),
            errorMessage: String(error),
          };
        }
        return { ok: true, providerMessageId: String(messageId || "") || undefined };
      }
      return {
        ok: false,
        transient: response.status >= 500 || response.status === 429,
        errorCode: String(response.status),
        errorMessage: JSON.stringify(body).slice(0, 500),
      };
    } catch (error) {
      return {
        ok: false,
        transient: true,
        errorCode: "network_error",
        errorMessage: error instanceof Error ? error.message : String(error),
      };
    }
  }
}

export function createPushProvider(): PushProvider {
  const key = env.FCM_SERVER_KEY?.trim();
  if (!key) {
    return new NoopPushProvider();
  }
  return new FcmPushProvider(key);
}

export async function sendQueuedPushDeliveries(
  limit = 100,
  provider: PushProvider = createPushProvider()
) {
  const rows = await queryMany(
    `SELECT d.delivery_id::text AS delivery_id, d.notification_id, d.attempt_count,
            n.title, n.body, n.data, n.priority, ud.id::text AS device_uuid,
            ud.push_token, ud.push_provider
     FROM notification_deliveries d
     JOIN notifications n ON n.notification_id = d.notification_id
     JOIN user_devices ud ON ud.id = d.device_id
     WHERE d.channel = 'push'
       AND d.status IN ('queued', 'retry')
       AND (d.next_retry_at IS NULL OR d.next_retry_at <= NOW())
       AND ud.push_token IS NOT NULL
       AND ud.invalidated_at IS NULL
       AND ud.revoked_at IS NULL
     ORDER BY d.created_at ASC
     LIMIT $1`,
    [limit]
  );

  let sent = 0;
  let failed = 0;
  for (const row of rows) {
    const data = typeof row.data === "object" && row.data ? row.data : {};
    const result = await provider.send({
      token: String(row.push_token),
      title: String(row.title || "Prava"),
      body: String(row.body || ""),
      priority: row.priority === "critical" || row.priority === "high" ? "high" : "normal",
      data: Object.fromEntries(
        Object.entries({
          notificationId: row.notification_id,
          deepLink: (data as any).deepLink || "/notifications",
          type: (data as any).notificationType || "SYSTEM_ANNOUNCEMENT",
        }).map(([key, value]) => [key, String(value)])
      ),
    });

    if (result.ok) {
      await query(
        `UPDATE notification_deliveries
         SET status = 'sent',
             provider_message_id = $2,
             attempt_count = attempt_count + 1,
             sent_at = NOW(),
             updated_at = NOW()
         WHERE delivery_id = $1`,
        [row.delivery_id, result.providerMessageId || null]
      );
      sent += 1;
      continue;
    }

    failed += 1;
    const nextStatus = result.invalidToken ? "failed" : (result.transient ? "retry" : "failed");
    const nextRetryAt = result.transient
      ? new Date(Date.now() + Math.min(60 * 60 * 1000, 1000 * 2 ** Math.min(8, Number(row.attempt_count || 0))))
      : null;
    await query(
      `UPDATE notification_deliveries
       SET status = $2,
           attempt_count = attempt_count + 1,
           next_retry_at = $3,
           failed_at = CASE WHEN $2 = 'failed' THEN NOW() ELSE failed_at END,
           error_code = $4,
           error_message = $5,
           updated_at = NOW()
       WHERE delivery_id = $1`,
      [
        row.delivery_id,
        nextStatus,
        nextRetryAt,
        result.errorCode || null,
        (result.errorMessage || "").slice(0, 500) || null,
      ]
    );
    if (result.invalidToken) {
      await query(
        `UPDATE user_devices
         SET invalidated_at = COALESCE(invalidated_at, NOW()),
             updated_at = NOW()
         WHERE id = $1`,
        [row.device_uuid]
      );
    }
  }

  incrementMetric("notifications.push_attempted", rows.length);
  incrementMetric("notifications.push_sent", sent);
  incrementMetric("notifications.push_failed", failed);
  return { attempted: rows.length, sent, failed, provider: provider.name };
}
