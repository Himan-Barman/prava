import { query, queryMany, queryOne } from "../../lib/pg.js";
import { requireAuth } from "../../lib/auth.js";
import { ensure, now } from "../../lib/security.js";

function parsePreKeys(input) {
  if (!Array.isArray(input)) {
    return [];
  }
  return input
    .map((item) => ({
      keyId: Number.parseInt(String(item?.keyId || ""), 10),
      publicKey: String(item?.publicKey || "").trim(),
    }))
    .filter((item) => Number.isInteger(item.keyId) && item.keyId >= 0 && item.publicKey.length > 0)
    .slice(0, 500);
}

export default async function cryptoService(app) {
  app.post("/devices/register", { preHandler: requireAuth }, async (request) => {
    const body = request.body || {};
    const deviceId = String(body.deviceId || "").trim();

    ensure(deviceId.length >= 3 && deviceId.length <= 128, 400, "Invalid deviceId");

    const signedPreKey = body.signedPreKey || {};
    ensure(Number.isInteger(Number(signedPreKey.keyId)), 400, "Invalid signed pre-key");
    ensure(String(signedPreKey.publicKey || "").trim().length > 0, 400, "Invalid signed pre-key");
    ensure(String(signedPreKey.signature || "").trim().length > 0, 400, "Invalid signed pre-key");

    const ts = now();
    await query(
      `INSERT INTO crypto_devices (user_id, device_id, platform, identity_key, registration_id, signed_pre_key, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (user_id, device_id)
       DO UPDATE SET platform = $3, identity_key = $4, registration_id = $5, signed_pre_key = $6, updated_at = $8`,
      [
        request.user.userId,
        deviceId,
        String(body.platform || "unknown").trim().slice(0, 40),
        String(body.identityKey || "").trim(),
        Number.parseInt(String(body.registrationId || "0"), 10) || 0,
        JSON.stringify({
          keyId: Number.parseInt(String(signedPreKey.keyId || "0"), 10) || 0,
          publicKey: String(signedPreKey.publicKey || "").trim(),
          signature: String(signedPreKey.signature || "").trim(),
        }),
        ts,
        ts,
      ]
    );

    const keys = parsePreKeys(body.oneTimePreKeys);
    if (keys.length > 0) {
      for (const key of keys) {
        await query(
          `INSERT INTO crypto_prekeys (user_id, device_id, key_id, public_key, is_used, created_at)
           VALUES ($1, $2, $3, $4, FALSE, $5)
           ON CONFLICT (user_id, device_id, key_id) DO NOTHING`,
          [request.user.userId, deviceId, key.keyId, key.publicKey, ts]
        );
      }
    }

    return { success: true };
  });

  app.post("/prekeys", { preHandler: requireAuth }, async (request) => {
    const body = request.body || {};
    const deviceId = String(body.deviceId || "").trim();
    ensure(deviceId.length >= 3 && deviceId.length <= 128, 400, "Invalid deviceId");

    const keys = parsePreKeys(body.preKeys);
    if (keys.length === 0) {
      return { added: 0 };
    }

    const ts = now();
    let added = 0;
    for (const key of keys) {
      const result = await query(
        `INSERT INTO crypto_prekeys (user_id, device_id, key_id, public_key, is_used, created_at)
         VALUES ($1, $2, $3, $4, FALSE, $5)
         ON CONFLICT (user_id, device_id, key_id) DO NOTHING`,
        [request.user.userId, deviceId, key.keyId, key.publicKey, ts]
      );
      if (result.rowCount && result.rowCount > 0) {
        added++;
      }
    }

    return { added };
  });

  app.get("/bundle/:userId/:deviceId", { preHandler: requireAuth }, async (request) => {
    const userId = String(request.params.userId || "").trim();
    const deviceId = String(request.params.deviceId || "").trim();
    ensure(userId.length >= 8, 400, "Invalid userId");
    ensure(deviceId.length >= 3, 400, "Invalid deviceId");

    const device = await queryOne(
      `SELECT * FROM crypto_devices WHERE user_id = $1 AND device_id = $2`,
      [userId, deviceId]
    );
    if (!device) {
      return {};
    }

    // Claim one pre-key atomically
    const preKey = await queryOne(
      `UPDATE crypto_prekeys
       SET is_used = TRUE, used_at = $3
       WHERE id = (
         SELECT id FROM crypto_prekeys
         WHERE user_id = $1 AND device_id = $2 AND is_used = FALSE
         ORDER BY key_id ASC LIMIT 1
         FOR UPDATE SKIP LOCKED
       )
       RETURNING *`,
      [userId, deviceId, now()]
    );

    return {
      deviceId: device.device_id,
      identityKey: device.identity_key || "",
      registrationId: Number(device.registration_id || 0),
      signedPreKey: device.signed_pre_key || null,
      oneTimePreKey: preKey
        ? {
          keyId: Number(preKey.key_id || 0),
          publicKey: preKey.public_key || "",
        }
        : null,
    };
  });

  app.get("/devices/:userId", { preHandler: requireAuth }, async (request) => {
    const userId = String(request.params.userId || "").trim();
    ensure(userId.length >= 8, 400, "Invalid userId");

    const devices = await queryMany(
      `SELECT device_id, platform, identity_key, registration_id, signed_pre_key
       FROM crypto_devices WHERE user_id = $1`,
      [userId]
    );

    if (devices.length === 0) {
      return [];
    }

    return devices.map((device) => ({
      deviceId: device.device_id,
      platform: device.platform || "unknown",
      identityKey: device.identity_key || "",
      registrationId: Number(device.registration_id || 0),
      signedPreKey: device.signed_pre_key || null,
      oneTimePreKey: null,
    }));
  });
}
