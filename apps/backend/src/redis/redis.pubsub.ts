import { createClient } from 'redis';
import { config } from '@/app.config';

export const redisPub = createClient({
  url: config.REDIS_URL,
});

export const redisSub = redisPub.duplicate();

let initializing = false;
let ready = false;

export const isPubSubReady = () => ready;

export async function initPubSub() {
  if (ready || initializing) return;
  initializing = true;

  try {
    if (!redisPub.isOpen) {
      await redisPub.connect();
    }

    if (!redisSub.isOpen) {
      await redisSub.connect();
    }

    ready = redisPub.isOpen && redisSub.isOpen;
    if (ready) {
      console.log('Redis Pub/Sub ready');
    }
  } catch {
    ready = false;
    console.warn('Redis Pub/Sub unavailable');
  } finally {
    initializing = false;
  }
}

export async function shutdownPubSub() {
  try {
    if (redisSub.isOpen) {
      await redisSub.quit();
    }
  } catch {
    // ignore
  }

  try {
    if (redisPub.isOpen) {
      await redisPub.quit();
    }
  } catch {
    // ignore
  } finally {
    ready = false;
  }
}
