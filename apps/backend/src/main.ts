import 'reflect-metadata';

import { NestFactory } from '@nestjs/core';
import {
  FastifyAdapter,
  NestFastifyApplication,
} from '@nestjs/platform-fastify';
import helmet from '@fastify/helmet';
import cors from '@fastify/cors';
import { ValidationPipe } from '@nestjs/common';

import { AppModule } from './app.module';
import { config } from './app.config';
import { startWsServer } from './realtime/ws.server';
import { pool } from './db';
import { closeRedis } from './redis/redis.client';
import { shutdownPubSub } from './redis/redis.pubsub';
import { MetricsInterceptor } from './observability/metrics.interceptor';

async function bootstrap() {
  const wsServer = startWsServer(config.WS_PORT);

  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    new FastifyAdapter({
      logger: config.NODE_ENV !== 'production',
      trustProxy: true, // REQUIRED behind load balancers (NGINX, ALB, Cloudflare)
    }),
  );

  /* ================= GLOBAL VALIDATION ================= */

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true, // strip unknown fields
      forbidNonWhitelisted: true,
      transform: true, // auto DTO transform
    }),
  );
  app.useGlobalInterceptors(new MetricsInterceptor());

  /* ================= SECURITY ================= */

  await app.register(helmet, {
    contentSecurityPolicy: false, // API only
    crossOriginEmbedderPolicy: false,
  });

  await app.register(cors, {
    origin: config.CORS_ORIGIN ?? false,
    credentials: true,
  });

  /* ================= APP SETTINGS ================= */

  app.setGlobalPrefix('api'); // /api/auth/...

  /* ================= START ================= */

  await app.listen({
    port: config.PORT,
    host: '0.0.0.0',
  });

  console.log(
    `dYs? API running on port ${config.PORT} [${config.NODE_ENV}]`,
  );

  let shuttingDown = false;
  const shutdown = async (signal: string) => {
    if (shuttingDown) return;
    shuttingDown = true;
    console.log(`Shutdown initiated (${signal})`);

    await app.close();
    wsServer.close();
    await shutdownPubSub();
    await closeRedis();
    await pool.end();

    process.exit(0);
  };

  process.on('SIGINT', () => {
    void shutdown('SIGINT');
  });

  process.on('SIGTERM', () => {
    void shutdown('SIGTERM');
  });
}

bootstrap().catch((err) => {
  console.error('ƒ?O Fatal bootstrap error', err);
  process.exit(1);
});
