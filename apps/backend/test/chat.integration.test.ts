import assert from "node:assert/strict";
import { once } from "node:events";
import { AddressInfo } from "node:net";
import test, { after, before } from "node:test";

import websocket from "@fastify/websocket";
import Fastify from "fastify";
import jwt from "jsonwebtoken";
import { MongoMemoryServer } from "mongodb-memory-server";
import WebSocket from "ws";

type SocketEvent = {
  type: string;
  payload: Record<string, unknown>;
};

function authHeader(token: string): Record<string, string> {
  return {
    authorization: `Bearer ${token}`,
    "content-type": "application/json",
  };
}

function signAccessToken(userId: string): string {
  const secret = process.env.JWT_SECRET || "";
  return jwt.sign(
    {
      sub: userId,
      email: `${userId}@example.com`,
      username: userId.slice(0, 16),
    },
    secret,
    {
      issuer: "prava",
      audience: "prava-clients",
      expiresIn: "30m",
    }
  );
}

async function waitForSocketEvent(
  socket: WebSocket,
  expectedType: string,
  timeoutMs = 4000
): Promise<SocketEvent> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      socket.off("message", onMessage);
      reject(new Error(`Timed out waiting for ${expectedType}`));
    }, timeoutMs);

    const onMessage = (raw: WebSocket.RawData) => {
      try {
        const event = JSON.parse(String(raw)) as SocketEvent;
        if (event?.type === expectedType) {
          clearTimeout(timer);
          socket.off("message", onMessage);
          resolve(event);
        }
      } catch {
        // ignore invalid payload
      }
    };

    socket.on("message", onMessage);
  });
}

async function httpJson<T = unknown>(
  baseUrl: string,
  path: string,
  options: {
    method?: string;
    token?: string;
    body?: unknown;
  } = {}
): Promise<{ status: number; data: T }> {
  const response = await fetch(`${baseUrl}${path}`, {
    method: options.method || "GET",
    headers: options.token
      ? authHeader(options.token)
      : { "content-type": "application/json" },
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  });

  const text = await response.text();
  const data = text ? (JSON.parse(text) as T) : ({} as T);
  return { status: response.status, data };
}

let mongoServer: MongoMemoryServer | null = null;
let app: ReturnType<typeof Fastify>;
let baseUrl = "";
let wsBaseUrl = "";
let closeMongo: (() => Promise<void>) | null = null;
let userAToken = "";
let userBToken = "";
let userAId = "";
let userBId = "";

before(async () => {
  userAId = `u_${Date.now()}_a`;
  userBId = `u_${Date.now()}_b`;

  process.env.NODE_ENV = "test";
  process.env.JWT_SECRET = process.env.JWT_SECRET || "test_jwt_secret_key";
  process.env.MONGODB_DB_NAME = process.env.MONGODB_DB_NAME || "prava_chat_test";

  if (!process.env.MONGODB_URI) {
    mongoServer = await MongoMemoryServer.create();
    process.env.MONGODB_URI = mongoServer.getUri();
  }

  const mongoLib = await import("../src/lib/mongo.js");
  await mongoLib.connectMongo();
  closeMongo = mongoLib.closeMongo;
  const db = mongoLib.getDb();

  const now = new Date();
  await db.collection("users").insertMany([
    {
      userId: userAId,
      email: "usera@example.com",
      emailLower: "usera@example.com",
      username: "usera_test",
      usernameLower: "usera_test",
      displayName: "User A",
      displayNameLower: "user a",
      passwordHash: "scrypt$dummy$dummy",
      isVerified: true,
      createdAt: now,
      updatedAt: now,
    },
    {
      userId: userBId,
      email: "userb@example.com",
      emailLower: "userb@example.com",
      username: "userb_test",
      usernameLower: "userb_test",
      displayName: "User B",
      displayNameLower: "user b",
      passwordHash: "scrypt$dummy$dummy",
      isVerified: true,
      createdAt: now,
      updatedAt: now,
    },
  ]);

  userAToken = signAccessToken(userAId);
  userBToken = signAccessToken(userBId);

  const chatService = (await import("../src/services/chat/index.js")).default;
  const realtimeService = (await import("../src/services/realtime/index.js")).default;

  app = Fastify({ logger: false });
  await app.register(websocket, {
    options: {
      maxPayload: 1024 * 1024,
    },
  });
  app.register(realtimeService);
  app.register(chatService, { prefix: "/api/conversations" });

  await app.listen({ host: "127.0.0.1", port: 0 });
  const address = app.server.address() as AddressInfo;
  baseUrl = `http://127.0.0.1:${address.port}`;
  wsBaseUrl = `ws://127.0.0.1:${address.port}`;
});

after(async () => {
  try {
    await app?.close();
  } catch {
    // ignore
  }

  try {
    if (closeMongo) {
      await closeMongo();
    }
  } catch {
    // ignore
  }

  try {
    if (mongoServer) {
      await mongoServer.stop();
    }
  } catch {
    // ignore
  }
});

test("chat routes: dm create, send message, read + delivery + sync", async () => {
  const dmCreate = await httpJson<{ conversationId: string; created?: boolean }>(
    baseUrl,
    "/api/conversations/dm",
    {
      method: "POST",
      token: userAToken,
      body: { otherUserId: userBId },
    }
  );
  assert.equal(dmCreate.status, 200);
  assert.ok(dmCreate.data.conversationId);
  const conversationId = dmCreate.data.conversationId;

  const sendMessage = await httpJson<{ message: { seq: number; messageId: string } }>(
    baseUrl,
    `/api/conversations/${conversationId}/messages`,
    {
      method: "POST",
      token: userAToken,
      body: {
        body: "hello route integration",
        contentType: "text",
        deviceId: "device-a",
        tempId: "tmp-route-1",
      },
    }
  );
  assert.equal(sendMessage.status, 200);
  assert.ok(sendMessage.data.message.messageId);
  assert.equal(sendMessage.data.message.seq, 1);

  const listForB = await httpJson<Array<{ id: string; unreadCount: number }>>(
    baseUrl,
    "/api/conversations",
    {
      token: userBToken,
    }
  );
  assert.equal(listForB.status, 200);
  const rowB = listForB.data.find((item) => item.id === conversationId);
  assert.ok(rowB);
  assert.equal(rowB.unreadCount, 1);

  const read = await httpJson<{ success: boolean; lastReadSeq: number }>(
    baseUrl,
    `/api/conversations/${conversationId}/read`,
    {
      method: "POST",
      token: userBToken,
      body: { lastReadSeq: 1 },
    }
  );
  assert.equal(read.status, 200);
  assert.equal(read.data.lastReadSeq, 1);

  const delivery = await httpJson<{ success: boolean; lastDeliveredSeq: number }>(
    baseUrl,
    `/api/conversations/${conversationId}/delivery`,
    {
      method: "POST",
      token: userBToken,
      body: { lastDeliveredSeq: 1 },
    }
  );
  assert.equal(delivery.status, 200);
  assert.equal(delivery.data.lastDeliveredSeq, 1);

  const reads = await httpJson<Array<{ userId: string; lastReadSeq: number; lastDeliveredSeq: number }>>(
    baseUrl,
    `/api/conversations/${conversationId}/reads`,
    {
      token: userAToken,
    }
  );
  assert.equal(reads.status, 200);
  const readB = reads.data.find((row) => row.userId === userBId);
  assert.ok(readB);
  assert.equal(readB.lastReadSeq, 1);
  assert.equal(readB.lastDeliveredSeq, 1);

  const sync = await httpJson<{ conversations: Array<{ conversationId: string; messages: unknown[] }> }>(
    baseUrl,
    "/api/conversations/sync",
    {
      method: "POST",
      token: userBToken,
      body: {
        conversations: [
          {
            conversationId,
            lastKnownSeq: 0,
          },
        ],
      },
    }
  );
  assert.equal(sync.status, 200);
  assert.equal(sync.data.conversations.length, 1);
  assert.equal(sync.data.conversations[0].conversationId, conversationId);
  assert.equal(sync.data.conversations[0].messages.length, 1);
});

test("realtime websocket: push, ack, read-update", async () => {
  const dmCreate = await httpJson<{ conversationId: string }>(
    baseUrl,
    "/api/conversations/dm",
    {
      method: "POST",
      token: userAToken,
      body: { otherUserId: userBId },
    }
  );
  const conversationId = dmCreate.data.conversationId;
  assert.ok(conversationId);

  const socketA = new WebSocket(
    `${wsBaseUrl}/ws?token=${encodeURIComponent(userAToken)}&deviceId=device-a-ws`
  );
  const socketB = new WebSocket(
    `${wsBaseUrl}/ws?token=${encodeURIComponent(userBToken)}&deviceId=device-b-ws`
  );

  await Promise.all([once(socketA, "open"), once(socketB, "open")]);

  socketA.send(JSON.stringify({
    type: "CONVERSATION_SUBSCRIBE",
    payload: { conversationId },
  }));
  socketB.send(JSON.stringify({
    type: "CONVERSATION_SUBSCRIBE",
    payload: { conversationId },
  }));

  const waitAck = waitForSocketEvent(socketA, "MESSAGE_ACK");
  const waitPush = waitForSocketEvent(socketB, "MESSAGE_PUSH");

  socketA.send(JSON.stringify({
    type: "MESSAGE_SEND",
    payload: {
      conversationId,
      body: "hello websocket integration",
      contentType: "text",
      tempId: "tmp-ws-1",
      deviceId: "device-a-ws",
    },
  }));

  const [ack, push] = await Promise.all([waitAck, waitPush]);

  assert.equal(ack.type, "MESSAGE_ACK");
  assert.equal(String(ack.payload.conversationId), conversationId);
  assert.equal(String(ack.payload.tempId), "tmp-ws-1");
  assert.ok(ack.payload.messageId);
  assert.ok(Number(ack.payload.seq) >= 1);

  assert.equal(push.type, "MESSAGE_PUSH");
  assert.equal(String(push.payload.conversationId), conversationId);
  assert.equal(String(push.payload.body), "hello websocket integration");
  assert.ok(push.payload.messageId);
  assert.equal(Number(push.payload.seq), Number(ack.payload.seq));

  const waitReadUpdate = waitForSocketEvent(socketA, "READ_UPDATE");
  socketB.send(JSON.stringify({
    type: "READ_RECEIPT",
    payload: {
      conversationId,
      lastReadSeq: Number(ack.payload.seq),
    },
  }));
  const readUpdate = await waitReadUpdate;
  assert.equal(readUpdate.type, "READ_UPDATE");
  assert.equal(String(readUpdate.payload.conversationId), conversationId);
  assert.equal(String(readUpdate.payload.userId), userBId);
  assert.equal(Number(readUpdate.payload.lastReadSeq), Number(ack.payload.seq));

  socketA.close();
  socketB.close();
});
