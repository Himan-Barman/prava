import { getRedis } from '@/redis/redis.client';
import { redisKeys } from '@/redis/redis.keys';

const PRESENCE_TTL_SEC = 90;

class PresenceManager {
  async connect(userId: string, deviceId?: string) {
    const redis = await getRedis();
    if (!redis) return;

    const key = redisKeys.presenceDevices(userId);
    const now = Date.now();

    if (deviceId) {
      await redis.zAdd(key, { score: now, value: deviceId });
    }

    await redis.expire(key, PRESENCE_TTL_SEC);
  }

  async disconnect(userId: string, deviceId?: string) {
    const redis = await getRedis();
    if (!redis) return;

    const key = redisKeys.presenceDevices(userId);
    const now = Date.now();

    if (deviceId) {
      await redis.zRem(key, deviceId);
    }

    await redis.zRemRangeByScore(
      key,
      0,
      now - PRESENCE_TTL_SEC * 1000,
    );

    const count = await redis.zCard(key);
    if (count === 0) {
      await redis.del(key);
    }
  }

  async isOnline(userId: string): Promise<boolean> {
    const redis = await getRedis();
    if (!redis) return false;

    const key = redisKeys.presenceDevices(userId);
    const now = Date.now();

    await redis.zRemRangeByScore(
      key,
      0,
      now - PRESENCE_TTL_SEC * 1000,
    );

    return (await redis.zCard(key)) > 0;
  }

  async isDeviceOnline(
    userId: string,
    deviceId: string,
  ): Promise<boolean> {
    const redis = await getRedis();
    if (!redis) return false;

    const key = redisKeys.presenceDevices(userId);
    const now = Date.now();

    const score = await redis.zScore(key, deviceId);
    if (score === null) return false;

    if (Number(score) < now - PRESENCE_TTL_SEC * 1000) {
      await redis.zRem(key, deviceId);
      return false;
    }

    return true;
  }
}

export const presenceManager = new PresenceManager();
