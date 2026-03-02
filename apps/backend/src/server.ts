import { randomUUID } from "node:crypto";

import compress from "@fastify/compress";
import cors from "@fastify/cors";
import helmet from "@fastify/helmet";
import rateLimit from "@fastify/rate-limit";
import underPressure from "@fastify/under-pressure";
import websocket from "@fastify/websocket";
import Fastify from "fastify";

import { env } from "./config/env.js";
import { closeMongo, connectMongo } from "./lib/mongo.js";
import { closeRedis, connectRedis } from "./lib/redis.js";
import { HttpError } from "./lib/security.js";
import authService from "./services/auth/index.js";
import chatService from "./services/chat/index.js";
import cryptoService from "./services/crypto/index.js";
import feedService from "./services/feed/index.js";
import notificationService from "./services/notification/index.js";
import { closeRealtimeHub, initRealtimeHub } from "./services/realtime/hub.js";
import realtimeService from "./services/realtime/index.js";
import supportService from "./services/support/index.js";
import userService from "./services/user/index.js";

const prettyTransport = env.NODE_ENV === "development"
  ? {
      target: "pino-pretty",
      options: {
        colorize: true,
        translateTime: "SYS:standard",
        ignore: "pid,hostname",
      },
    }
  : undefined;

const app = Fastify({
  trustProxy: env.TRUST_PROXY,
  bodyLimit: env.BODY_LIMIT_BYTES,
  connectionTimeout: env.CONNECTION_TIMEOUT_MS,
  keepAliveTimeout: env.KEEP_ALIVE_TIMEOUT_MS,
  maxParamLength: env.MAX_PARAM_LENGTH,
  requestIdHeader: "x-request-id",
  genReqId: (request) => {
    const incoming = request.headers["x-request-id"];
    if (typeof incoming === "string" && incoming.trim()) {
      return incoming.trim();
    }
    return randomUUID();
  },
  logger: {
    level: env.LOG_LEVEL,
    transport: prettyTransport,
    redact: {
      paths: [
        "req.headers.authorization",
        "req.headers.cookie",
        "res.headers['set-cookie']",
      ],
      censor: "[REDACTED]",
    },
  },
});

let ready = false;
let shuttingDown = false;

function buildCorsOrigin(origins: string[]) {
  if (origins.includes("*")) {
    return true;
  }

  const allowSet = new Set(origins);
  return (origin: string | undefined, callback: (err: Error | null, allow: boolean) => void): void => {
    if (!origin) {
      callback(null, true);
      return;
    }

    callback(null, allowSet.has(origin));
  };
}

async function registerPlugins(): Promise<void> {
  await app.register(websocket, {
    options: {
      maxPayload: 1024 * 1024,
    },
  });

  if (
    env.PRESSURE_MAX_EVENT_LOOP_DELAY_MS
    || env.PRESSURE_MAX_HEAP_USED_BYTES
    || env.PRESSURE_MAX_RSS_BYTES
  ) {
    await app.register(underPressure, {
      maxEventLoopDelay: env.PRESSURE_MAX_EVENT_LOOP_DELAY_MS,
      maxHeapUsedBytes: env.PRESSURE_MAX_HEAP_USED_BYTES,
      maxRssBytes: env.PRESSURE_MAX_RSS_BYTES,
      retryAfter: env.PRESSURE_RETRY_AFTER_SECONDS,
      exposeStatusRoute: false,
    });
  }

  await app.register(helmet, {
    contentSecurityPolicy: false,
    crossOriginResourcePolicy: false,
  });

  await app.register(compress, {
    global: true,
  });

  await app.register(cors, {
    origin: buildCorsOrigin(env.CORS_ORIGINS),
    credentials: true,
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: [
      "Accept",
      "Authorization",
      "Content-Type",
      "X-Request-ID",
      "X-Device-Id",
    ],
    exposedHeaders: ["X-Request-ID"],
    maxAge: 86400,
  });

  const redis = await connectRedis();
  const rateLimitOptions = {
    global: true,
    max: env.RATE_LIMIT_MAX,
    timeWindow: env.RATE_LIMIT_WINDOW_MS,
    errorResponseBuilder: (_, context) => {
      const afterMs = typeof context.after === "number"
        ? context.after
        : Number(context.after || 0);

      return {
        statusCode: 429,
        error: "Too Many Requests",
        message: `Rate limit exceeded, retry in ${Math.ceil(afterMs / 1000)}s`,
      };
    },
  } as const;

  if (redis) {
    await app.register(rateLimit, {
      ...rateLimitOptions,
      redis,
      nameSpace: `${env.REDIS_KEY_PREFIX}:rate-limit`,
    });
  } else {
    await app.register(rateLimit, rateLimitOptions);
  }
}

function registerHooks(): void {
  app.addHook("onRequest", async (request, reply) => {
    reply.header("X-Request-ID", request.id);

    if (shuttingDown) {
      reply
        .code(503)
        .send({
          message: "Service is shutting down",
          requestId: request.id,
        });
    }
  });
}

function registerRoutes(): void {
  app.register(realtimeService);
  app.register(authService, { prefix: "/api/auth" });
  app.register(feedService, { prefix: "/api/feed" });
  app.register(userService, { prefix: "/api/users" });
  app.register(chatService, { prefix: "/api/conversations" });
  app.register(notificationService, { prefix: "/api/notifications" });
  app.register(supportService, { prefix: "/api/support" });
  app.register(cryptoService, { prefix: "/api/crypto" });

  app.get("/health", { config: { rateLimit: false } }, async () => ({
    status: ready ? "ok" : "starting",
    ready,
    uptimeSec: Math.floor(process.uptime()),
    env: env.NODE_ENV,
    db: "mongodb",
  }));

  app.get("/api/health", { config: { rateLimit: false } }, async () => ({
    status: ready ? "ok" : "starting",
    ready,
    uptimeSec: Math.floor(process.uptime()),
    env: env.NODE_ENV,
    db: "mongodb",
  }));

  app.get("/api/ready", { config: { rateLimit: false } }, async (_, reply) => {
    if (!ready || shuttingDown) {
      reply.code(503);
      return {
        ready: false,
      };
    }

    return {
      ready: true,
    };
  });
}

function registerErrorHandlers(): void {
  app.setErrorHandler((error, request, reply) => {
    const unknownError = error as { statusCode?: unknown; message?: unknown };
    const derivedStatusCode = typeof unknownError.statusCode === "number" && Number.isInteger(unknownError.statusCode)
      ? unknownError.statusCode
      : 500;

    const statusCode = error instanceof HttpError
      ? error.statusCode
      : derivedStatusCode;

    const message = error instanceof HttpError
      ? error.message
      : (statusCode >= 500
          ? "Internal server error"
          : (typeof unknownError.message === "string" && unknownError.message.trim()
              ? unknownError.message
              : "Request failed"));

    request.log.error({ err: error }, "request failed");
    reply.code(statusCode).send({
      message,
      requestId: request.id,
    });
  });

  app.setNotFoundHandler((request, reply) => {
    reply.code(404).send({
      message: "Route not found",
      requestId: request.id,
    });
  });
}

async function bootstrap(): Promise<void> {
  registerErrorHandlers();
  await registerPlugins();
  registerHooks();
  registerRoutes();

  await connectMongo();
  try {
    await initRealtimeHub();
  } catch (error) {
    app.log.error({ err: error }, "realtime hub unavailable");
  }
  ready = true;

  await app.listen({
    port: env.PORT,
    host: env.HOST,
  });

  app.log.info({ port: env.PORT, host: env.HOST, env: env.NODE_ENV }, "backend started");
}

async function shutdown(signal: string): Promise<void> {
  if (shuttingDown) {
    return;
  }

  shuttingDown = true;
  ready = false;
  app.log.warn({ signal }, "shutdown requested");

  try {
    await app.close();
  } catch (error) {
    app.log.error({ err: error }, "failed to close fastify cleanly");
  }

  try {
    await closeMongo();
  } catch (error) {
    app.log.error({ err: error }, "failed to close mongo cleanly");
  }

  try {
    await closeRealtimeHub();
  } catch (error) {
    app.log.error({ err: error }, "failed to close realtime hub cleanly");
  }

  try {
    await closeRedis();
  } catch (error) {
    app.log.error({ err: error }, "failed to close redis cleanly");
  }

  process.exit(0);
}

process.on("SIGINT", () => {
  void shutdown("SIGINT");
});

process.on("SIGTERM", () => {
  void shutdown("SIGTERM");
});

process.on("unhandledRejection", (reason) => {
  app.log.error({ err: reason }, "unhandled promise rejection");
  void shutdown("unhandledRejection");
});

process.on("uncaughtException", (error) => {
  app.log.fatal({ err: error }, "uncaught exception");
  void shutdown("uncaughtException");
});

bootstrap().catch((error) => {
  app.log.fatal({ err: error }, "failed to start backend");
  process.exit(1);
});
