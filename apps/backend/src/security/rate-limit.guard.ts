import {
  CanActivate,
  ExecutionContext,
  Injectable,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { FastifyRequest } from 'fastify';

import { getRedis } from '@/redis/redis.client';
import { redisKeys } from '@/redis/redis.keys';

@Injectable()
export class RateLimitGuard implements CanActivate {
  private readonly WINDOW_SEC = 60;
  private readonly MAX_REQUESTS = 30;

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx
      .switchToHttp()
      .getRequest<FastifyRequest>();

    const ip =
      (req.headers['x-forwarded-for'] as string)?.split(',')[0]?.trim() ??
      req.ip ??
      'unknown';

    const route = req.routeOptions?.url ?? 'global';

    const redis = await getRedis();

    // 🔥 FAIL-OPEN: if Redis is unavailable, allow request
    if (!redis) {
      return true;
    }

    const key = redisKeys.rateLimit(ip, route);
    const now = Date.now();

    try {
      await redis.zAdd(key, {
        score: now,
        value: now.toString(),
      });

      await redis.zRemRangeByScore(
        key,
        0,
        now - this.WINDOW_SEC * 1000,
      );

      const count = await redis.zCard(key);

      if (count > this.MAX_REQUESTS) {
        throw new HttpException(
          'Too many requests, slow down',
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }

      await redis.expire(key, this.WINDOW_SEC);
      return true;
    } catch (err) {
      // 🔥 FAIL-OPEN on Redis command errors
      console.warn('⚠️ Rate limit skipped (Redis error)');
      return true;
    }
  }
}
