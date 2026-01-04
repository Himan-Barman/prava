import { createClient, RedisClientType } from 'redis';
import { config } from '@/app.config';

let client: RedisClientType | null = null;

export async function getRedis(): Promise<RedisClientType | null> {
  if (client) return client;

  try {
    client = createClient({
      url: config.REDIS_URL,
      socket: {
        reconnectStrategy: (retries) => {
          if (retries > 10) return false; // stop retrying
          return Math.min(retries * 100, 1000);
        },
      },
    });

    client.on('error', (err) => {
      console.error('❌ Redis error:', err.message);
    });

    await client.connect();
    console.log('✅ Redis connected');

    return client;
  } catch (err) {
    console.warn('⚠️ Redis unavailable — continuing without it');
    client = null;
    return null;
  }
}

export async function closeRedis(): Promise<void> {
  if (!client) return;

  try {
    await client.quit();
  } catch {
    try {
      await client.disconnect();
    } catch {
      // ignore
    }
  } finally {
    client = null;
  }
}
