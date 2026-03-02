import { randomUUID } from "node:crypto";

import { Redis as RedisCtor, type Redis as RedisClient, type RedisOptions } from "ioredis";

import { env } from "../../config/env.js";

export interface ConversationMeta {
  memberIds: string[];
  type?: string;
}

export interface RealtimeConnection {
  socket: { send: (data: string) => void; readyState: number };
  userId: string;
  deviceId: string;
  subscribedConversations: Set<string>;
  conversationMeta: Map<string, ConversationMeta>;
  feedSubscribed: boolean;
}

const OPEN_STATE = 1;
const connectionsByUser = new Map<string, Set<RealtimeConnection>>();
const instanceId = randomUUID();
const channelName = `${env.REDIS_KEY_PREFIX}:realtime`;

let publisher: RedisClient | null = null;
let subscriber: RedisClient | null = null;

function buildRedisOptions(): RedisOptions {
  const options: RedisOptions = {
    maxRetriesPerRequest: 1,
    enableReadyCheck: true,
    lazyConnect: true,
  };

  if (env.REDIS_TLS) {
    options.tls = {};
  }

  return options;
}

function send(connection: RealtimeConnection, type: string, payload: unknown): void {
  if (connection.socket.readyState !== OPEN_STATE) {
    return;
  }

  try {
    connection.socket.send(JSON.stringify({ type, payload }));
  } catch {
    // ignore transport errors
  }
}

function sendToUsers(
  userIds: string[],
  type: string,
  payload: unknown,
  excludeUserId?: string
): void {
  for (const userId of userIds) {
    if (!userId || userId === excludeUserId) continue;
    const connections = connectionsByUser.get(userId);
    if (!connections) continue;
    for (const connection of connections) {
      send(connection, type, payload);
    }
  }
}

function publishEvent(
  userIds: string[],
  type: string,
  payload: unknown,
  excludeUserId?: string
): void {
  sendToUsers(userIds, type, payload, excludeUserId);

  if (!publisher) {
    return;
  }

  try {
    void publisher.publish(
      channelName,
      JSON.stringify({
        instanceId,
        userIds,
        type,
        payload,
        excludeUserId,
      })
    );
  } catch {
    // ignore publish errors
  }
}

export async function initRealtimeHub(): Promise<void> {
  if (!env.REDIS_URL) {
    return;
  }

  publisher = new RedisCtor(env.REDIS_URL, buildRedisOptions());
  subscriber = new RedisCtor(env.REDIS_URL, buildRedisOptions());

  await Promise.all([publisher.connect(), subscriber.connect()]);
  await subscriber.subscribe(channelName);
  subscriber.on("message", (_channel, message) => {
    try {
      const parsed = JSON.parse(message);
      if (!parsed || typeof parsed !== "object") return;
      if (parsed.instanceId === instanceId) return;
      const userIds = Array.isArray(parsed.userIds) ? parsed.userIds : [];
      const type = String(parsed.type || "");
      const payload = parsed.payload;
      const excludeUserId = parsed.excludeUserId ? String(parsed.excludeUserId) : undefined;
      if (!type || userIds.length === 0) return;
      sendToUsers(userIds, type, payload, excludeUserId);
    } catch {
      // ignore invalid payloads
    }
  });
}

export async function closeRealtimeHub(): Promise<void> {
  const currentPublisher = publisher;
  const currentSubscriber = subscriber;
  publisher = null;
  subscriber = null;

  try {
    if (currentSubscriber) {
      await currentSubscriber.unsubscribe(channelName);
      await currentSubscriber.quit();
    }
  } catch {
    try {
      currentSubscriber?.disconnect();
    } catch {}
  }

  try {
    await currentPublisher?.quit();
  } catch {
    try {
      currentPublisher?.disconnect();
    } catch {}
  }
}

export function registerConnection(connection: RealtimeConnection): void {
  const set = connectionsByUser.get(connection.userId) ?? new Set<RealtimeConnection>();
  set.add(connection);
  connectionsByUser.set(connection.userId, set);
}

export function unregisterConnection(connection: RealtimeConnection): void {
  const set = connectionsByUser.get(connection.userId);
  if (!set) return;
  set.delete(connection);
  if (set.size === 0) {
    connectionsByUser.delete(connection.userId);
  }
}

export function publishToUsers(
  userIds: string[],
  type: string,
  payload: unknown,
  excludeUserId?: string
): void {
  if (!userIds || userIds.length === 0) return;
  publishEvent(userIds, type, payload, excludeUserId);
}

export function publishToConversation(
  memberIds: string[],
  type: string,
  payload: unknown,
  excludeUserId?: string
): void {
  if (!memberIds || memberIds.length === 0) return;
  publishEvent(memberIds, type, payload, excludeUserId);
}
