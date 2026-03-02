import { Redis as RedisCtor, type RedisOptions, type Redis as RedisClient } from "ioredis";

import { env } from "../config/env.js";

let client: RedisClient | undefined;

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

export async function connectRedis(): Promise<RedisClient | null> {
  if (!env.REDIS_URL) {
    return null;
  }

  if (client) {
    return client;
  }

  const redis = new RedisCtor(env.REDIS_URL, buildRedisOptions());
  client = redis;
  await redis.connect();
  return redis;
}

export function getRedis(): RedisClient | undefined {
  return client;
}

export async function closeRedis(): Promise<void> {
  if (!client) {
    return;
  }

  const current = client;
  client = undefined;
  try {
    await current.quit();
  } catch {
    try {
      current.disconnect();
    } catch {}
  }
}
