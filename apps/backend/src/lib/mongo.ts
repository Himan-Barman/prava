import { Db, MongoClient } from "mongodb";

import { env } from "../config/env.js";

const DEFAULT_DB_NAME = "prava_chat";

let client: MongoClient | undefined;
let db: Db | undefined;

export async function connectMongo(): Promise<Db> {
  if (db) {
    return db;
  }

  const uri = env.MONGODB_URI;
  const maxAttempts = env.MONGODB_CONNECT_RETRIES;
  let attempt = 0;
  let lastError: unknown;

  while (attempt < maxAttempts) {
    attempt += 1;
    try {
      client = new MongoClient(uri, {
        maxPoolSize: env.MONGODB_MAX_POOL_SIZE,
        minPoolSize: env.MONGODB_MIN_POOL_SIZE,
        serverSelectionTimeoutMS: env.MONGODB_SERVER_SELECTION_TIMEOUT_MS,
      });

      await client.connect();
      await client.db("admin").command({ ping: 1 });
      break;
    } catch (error) {
      lastError = error;
      if (client) {
        await client.close().catch(() => undefined);
        client = undefined;
      }

      if (attempt >= maxAttempts) {
        throw error;
      }

      await wait(env.MONGODB_CONNECT_RETRY_DELAY_MS);
    }
  }

  if (!client) {
    throw (lastError instanceof Error
      ? lastError
      : new Error("MongoDB connection failed"));
  }

  const explicitName = env.MONGODB_DB_NAME;
  if (explicitName && explicitName.trim()) {
    db = client.db(explicitName.trim());
  } else {
    try {
      const parsed = new URL(uri);
      const pathname = parsed.pathname.replace(/^\//, "").trim();
      db = client.db(pathname || DEFAULT_DB_NAME);
    } catch {
      db = client.db(DEFAULT_DB_NAME);
    }
  }

  await ensureIndexes(db);
  return db;
}

export function getDb(): Db {
  if (!db) {
    throw new Error("MongoDB is not connected");
  }
  return db;
}

export async function closeMongo(): Promise<void> {
  if (client) {
    await client.close();
  }
  client = undefined;
  db = undefined;
}

async function ensureIndexes(database: Db): Promise<void> {
  await Promise.all([
    database.collection("users").createIndexes([
      { key: { userId: 1 }, unique: true },
      { key: { emailLower: 1 }, unique: true },
      { key: { usernameLower: 1 }, unique: true },
      { key: { displayNameLower: 1 } },
      { key: { createdAt: -1 } },
    ]),
    database.collection("refresh_tokens").createIndexes([
      { key: { tokenHash: 1, deviceId: 1 }, unique: true },
      { key: { userId: 1, revokedAt: 1, expiresAt: 1 } },
    ]),
    database.collection("email_otp_tokens").createIndexes([
      { key: { emailLower: 1, createdAt: -1 } },
      { key: { expiresAt: 1 }, expireAfterSeconds: 0 },
    ]),
    database.collection("username_reservations").createIndexes([
      { key: { usernameLower: 1 }, unique: true },
      { key: { emailLower: 1, expiresAt: -1 } },
      { key: { expiresAt: 1 }, expireAfterSeconds: 0 },
    ]),
    database.collection("password_reset_tokens").createIndexes([
      { key: { tokenHash: 1 }, unique: true },
      { key: { expiresAt: 1 }, expireAfterSeconds: 0 },
    ]),
    database.collection("follows").createIndexes([
      { key: { followerId: 1, followingId: 1 }, unique: true },
      { key: { followingId: 1, followerId: 1 } },
    ]),
    database.collection("posts").createIndexes([
      { key: { postId: 1 }, unique: true },
      { key: { authorId: 1, createdAt: -1 } },
      { key: { createdAt: -1 } },
      { key: { shareOfPostId: 1, authorId: 1 } },
    ]),
    database.collection("post_likes").createIndexes([
      { key: { postId: 1, userId: 1 }, unique: true },
      { key: { userId: 1, createdAt: -1 } },
    ]),
    database.collection("comments").createIndexes([
      { key: { commentId: 1 }, unique: true },
      { key: { postId: 1, createdAt: -1 } },
    ]),
    database.collection("conversations").createIndexes([
      { key: { conversationId: 1 }, unique: true },
      { key: { memberIds: 1, updatedAt: -1 } },
      { key: { type: 1, memberHash: 1 }, unique: true, sparse: true },
    ]),
    database.collection("messages").createIndexes([
      { key: { messageId: 1 }, unique: true },
      { key: { conversationId: 1, seq: -1 }, unique: true },
      { key: { conversationId: 1, createdAt: -1 } },
    ]),
    database.collection("conversation_reads").createIndexes([
      { key: { conversationId: 1, userId: 1 }, unique: true },
      { key: { userId: 1, conversationId: 1 } },
    ]),
    database.collection("user_settings").createIndexes([
      { key: { userId: 1 }, unique: true },
    ]),
    database.collection("user_blocks").createIndexes([
      { key: { blockerId: 1, blockedId: 1 }, unique: true },
      { key: { blockerId: 1, createdAt: -1 } },
    ]),
    database.collection("user_muted_words").createIndexes([
      { key: { userId: 1, phraseLower: 1 }, unique: true },
      { key: { userId: 1, createdAt: -1 } },
    ]),
    database.collection("data_exports").createIndexes([
      { key: { exportId: 1 }, unique: true },
      { key: { userId: 1, createdAt: -1 } },
    ]),
    database.collection("notifications").createIndexes([
      { key: { notificationId: 1 }, unique: true },
      { key: { userId: 1, createdAt: -1 } },
      { key: { userId: 1, readAt: 1 } },
    ]),
    database.collection("support_requests").createIndexes([
      { key: { supportId: 1 }, unique: true },
      { key: { userId: 1, createdAt: -1 } },
    ]),
    database.collection("crypto_devices").createIndexes([
      { key: { userId: 1, deviceId: 1 }, unique: true },
      { key: { userId: 1 } },
    ]),
    database.collection("crypto_prekeys").createIndexes([
      { key: { userId: 1, deviceId: 1, keyId: 1 }, unique: true },
      { key: { userId: 1, deviceId: 1, isUsed: 1, keyId: 1 } },
    ]),
  ]);
}

function wait(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}
