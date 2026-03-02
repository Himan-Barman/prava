import { z } from "zod";

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  HOST: z.string().min(1).default("0.0.0.0"),
  PORT: z.coerce.number().int().positive().max(65535).default(3000),
  LOG_LEVEL: z.enum(["fatal", "error", "warn", "info", "debug", "trace", "silent"]).optional(),
  TRUST_PROXY: z.string().optional(),
  BODY_LIMIT_BYTES: z.coerce.number().int().positive().default(1_048_576),
  RATE_LIMIT_MAX: z.coerce.number().int().positive().default(200),
  RATE_LIMIT_WINDOW_MS: z.coerce.number().int().positive().default(60_000),
  CORS_ORIGIN: z.string().optional(),
  MONGODB_URI: z.string().optional(),
  MONGODB_DB_NAME: z.string().optional(),
  MONGODB_MAX_POOL_SIZE: z.coerce.number().int().positive().default(30),
  MONGODB_MIN_POOL_SIZE: z.coerce.number().int().nonnegative().default(2),
  MONGODB_SERVER_SELECTION_TIMEOUT_MS: z.coerce.number().int().positive().default(5000),
  MONGODB_CONNECT_RETRIES: z.coerce.number().int().positive().default(3),
  MONGODB_CONNECT_RETRY_DELAY_MS: z.coerce.number().int().positive().default(1500),
  REDIS_URL: z.string().optional(),
  REDIS_TLS: z.string().optional(),
  REDIS_KEY_PREFIX: z.string().optional(),
  CONNECTION_TIMEOUT_MS: z.coerce.number().int().positive().optional(),
  KEEP_ALIVE_TIMEOUT_MS: z.coerce.number().int().positive().optional(),
  MAX_PARAM_LENGTH: z.coerce.number().int().positive().optional(),
  PRESSURE_MAX_EVENT_LOOP_DELAY_MS: z.coerce.number().int().positive().optional(),
  PRESSURE_MAX_HEAP_USED_BYTES: z.coerce.number().int().positive().optional(),
  PRESSURE_MAX_RSS_BYTES: z.coerce.number().int().positive().optional(),
  PRESSURE_RETRY_AFTER_SECONDS: z.coerce.number().int().positive().optional(),
  JWT_SECRET: z.string().min(1).optional(),
  JWT_PRIVATE_KEY: z.string().min(1).optional(),
  ACCESS_TOKEN_TTL_SECONDS: z.coerce.number().int().positive().default(900),
  REFRESH_TOKEN_TTL_SECONDS: z.coerce.number().int().positive().default(60 * 60 * 24 * 30),
});

type ParsedEnv = z.infer<typeof envSchema>;

const DEFAULT_MONGODB_URI = "mongodb://127.0.0.1:27017/prava_chat";
const DEFAULT_MONGODB_DB_NAME = "prava_chat";

function parseBoolean(value: string | undefined, fallback: boolean): boolean {
  if (!value) {
    return fallback;
  }
  const normalized = value.trim().toLowerCase();
  if (["true", "1", "yes", "on"].includes(normalized)) {
    return true;
  }
  if (["false", "0", "no", "off"].includes(normalized)) {
    return false;
  }
  return fallback;
}

function parseCorsOrigins(value: string | undefined): string[] {
  if (!value || !value.trim()) {
    return ["*"];
  }

  return value
    .split(",")
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
}

function validateJwtSettings(parsed: ParsedEnv): void {
  if (!parsed.JWT_SECRET && !parsed.JWT_PRIVATE_KEY) {
    throw new Error("Either JWT_SECRET or JWT_PRIVATE_KEY is required");
  }
}

function resolveMongoUri(parsed: ParsedEnv): string {
  const configured = parsed.MONGODB_URI?.trim();
  if (!configured) {
    if (parsed.NODE_ENV === "production") {
      throw new Error("MONGODB_URI is required in production");
    }
    return DEFAULT_MONGODB_URI;
  }

  if (configured.includes("<db_password>")) {
    throw new Error("MONGODB_URI contains '<db_password>' placeholder; replace it with the real password");
  }

  return configured;
}

function resolveMongoDbName(parsed: ParsedEnv): string {
  const configured = parsed.MONGODB_DB_NAME?.trim();
  if (configured) {
    return configured;
  }
  return DEFAULT_MONGODB_DB_NAME;
}

const parsed = envSchema.parse(process.env);
validateJwtSettings(parsed);

const defaultLogLevel = parsed.NODE_ENV === "production" ? "info" : "debug";

export const env = {
  ...parsed,
  LOG_LEVEL: parsed.LOG_LEVEL ?? defaultLogLevel,
  TRUST_PROXY: parseBoolean(parsed.TRUST_PROXY, true),
  CORS_ORIGINS: parseCorsOrigins(parsed.CORS_ORIGIN),
  MONGODB_URI: resolveMongoUri(parsed),
  MONGODB_DB_NAME: resolveMongoDbName(parsed),
  REDIS_TLS: parseBoolean(parsed.REDIS_TLS, false),
  REDIS_KEY_PREFIX: parsed.REDIS_KEY_PREFIX ?? "prava",
  CONNECTION_TIMEOUT_MS: parsed.CONNECTION_TIMEOUT_MS ?? 10_000,
  KEEP_ALIVE_TIMEOUT_MS: parsed.KEEP_ALIVE_TIMEOUT_MS ?? 60_000,
  MAX_PARAM_LENGTH: parsed.MAX_PARAM_LENGTH ?? 200,
};

export type AppEnv = typeof env;
