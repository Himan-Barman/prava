import { getDb } from "../../lib/mongo.js";
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
  const db = getDb();

  app.post("/devices/register", { preHandler: requireAuth }, async (request) => {
    const body = request.body || {};
    const deviceId = String(body.deviceId || "").trim();

    ensure(deviceId.length >= 3 && deviceId.length <= 128, 400, "Invalid deviceId");

    const signedPreKey = body.signedPreKey || {};
    ensure(Number.isInteger(Number(signedPreKey.keyId)), 400, "Invalid signed pre-key");
    ensure(String(signedPreKey.publicKey || "").trim().length > 0, 400, "Invalid signed pre-key");
    ensure(String(signedPreKey.signature || "").trim().length > 0, 400, "Invalid signed pre-key");

    const ts = now();
    await db.collection("crypto_devices").updateOne(
      {
        userId: request.user.userId,
        deviceId,
      },
      {
        $set: {
          userId: request.user.userId,
          deviceId,
          platform: String(body.platform || "unknown").trim().slice(0, 40),
          identityKey: String(body.identityKey || "").trim(),
          registrationId: Number.parseInt(String(body.registrationId || "0"), 10) || 0,
          signedPreKey: {
            keyId: Number.parseInt(String(signedPreKey.keyId || "0"), 10) || 0,
            publicKey: String(signedPreKey.publicKey || "").trim(),
            signature: String(signedPreKey.signature || "").trim(),
          },
          updatedAt: ts,
        },
        $setOnInsert: {
          createdAt: ts,
        },
      },
      {
        upsert: true,
      }
    );

    const keys = parsePreKeys(body.oneTimePreKeys);
    if (keys.length > 0) {
      const ops = keys.map((key) => ({
        updateOne: {
          filter: {
            userId: request.user.userId,
            deviceId,
            keyId: key.keyId,
          },
          update: {
            $setOnInsert: {
              userId: request.user.userId,
              deviceId,
              keyId: key.keyId,
              publicKey: key.publicKey,
              isUsed: false,
              createdAt: ts,
            },
          },
          upsert: true,
        },
      }));
      await db.collection("crypto_prekeys").bulkWrite(ops, { ordered: false });
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
    const ops = keys.map((key) => ({
      updateOne: {
        filter: {
          userId: request.user.userId,
          deviceId,
          keyId: key.keyId,
        },
        update: {
          $setOnInsert: {
            userId: request.user.userId,
            deviceId,
            keyId: key.keyId,
            publicKey: key.publicKey,
            isUsed: false,
            createdAt: ts,
          },
        },
        upsert: true,
      },
    }));
    const result = await db.collection("crypto_prekeys").bulkWrite(ops, { ordered: false });

    return {
      added: Number(result.upsertedCount || 0),
    };
  });

  app.get("/bundle/:userId/:deviceId", { preHandler: requireAuth }, async (request) => {
    const userId = String(request.params.userId || "").trim();
    const deviceId = String(request.params.deviceId || "").trim();
    ensure(userId.length >= 8, 400, "Invalid userId");
    ensure(deviceId.length >= 3, 400, "Invalid deviceId");

    const device = await db.collection("crypto_devices").findOne({
      userId,
      deviceId,
    });
    if (!device) {
      return {};
    }

    const preKey = await db.collection("crypto_prekeys").findOneAndUpdate(
      {
        userId,
        deviceId,
        isUsed: false,
      },
      {
        $set: {
          isUsed: true,
          usedAt: now(),
        },
      },
      {
        sort: { keyId: 1 },
        returnDocument: "after",
      }
    );
    const preKeyDoc = preKey && typeof preKey === "object" && "value" in preKey
      ? preKey.value
      : preKey;

    return {
      deviceId: device.deviceId,
      identityKey: device.identityKey || "",
      registrationId: Number(device.registrationId || 0),
      signedPreKey: device.signedPreKey || null,
      oneTimePreKey: preKeyDoc
        ? {
            keyId: Number(preKeyDoc.keyId || 0),
            publicKey: preKeyDoc.publicKey || "",
          }
        : null,
    };
  });

  app.get("/devices/:userId", { preHandler: requireAuth }, async (request) => {
    const userId = String(request.params.userId || "").trim();
    ensure(userId.length >= 8, 400, "Invalid userId");

    const devices = await db.collection("crypto_devices").find(
      { userId },
      {
        projection: {
          deviceId: 1,
          platform: 1,
          identityKey: 1,
          registrationId: 1,
          signedPreKey: 1,
        },
      }
    ).toArray();

    if (devices.length === 0) {
      return [];
    }

    const output: Array<{
      deviceId: string;
      platform: string;
      identityKey: string;
      registrationId: number;
      signedPreKey: unknown;
      oneTimePreKey: null;
    }> = [];
    for (const device of devices) {
      output.push({
        deviceId: device.deviceId,
        platform: device.platform || "unknown",
        identityKey: device.identityKey || "",
        registrationId: Number(device.registrationId || 0),
        signedPreKey: device.signedPreKey || null,
        oneTimePreKey: null,
      });
    }

    return output;
  });
}
