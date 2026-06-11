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

  // PostgreSQL (Supabase)
  DATABASE_URL: z.string().optional(),
  PG_POOL_MAX: z.coerce.number().int().positive().default(20),
  PG_POOL_IDLE_TIMEOUT_MS: z.coerce.number().int().positive().default(30_000),
  PG_CONNECT_TIMEOUT_MS: z.coerce.number().int().positive().default(10_000),
  PG_STATEMENT_TIMEOUT_MS: z.coerce.number().int().positive().default(30_000),

  // Cloudinary
  CLOUDINARY_CLOUD_NAME: z.string().optional(),
  CLOUDINARY_API_KEY: z.string().optional(),
  CLOUDINARY_API_SECRET: z.string().optional(),

  // Email
  RESEND_API_KEY: z.string().optional(),
  EMAIL_FROM: z.string().optional(),
  EMAIL_REPLY_TO: z.string().optional(),
  APP_NAME: z.string().min(1).default("Prava"),
  APP_PUBLIC_URL: z.string().optional(),
  OTP_EXPIRES_MINUTES: z.coerce.number().int().positive().default(10),
  USERNAME_RESERVATION_MINUTES: z.coerce.number().int().positive().default(5),

  // Redis
  REDIS_URL: z.string().optional(),
  REDIS_TLS: z.string().optional(),
  REDIS_KEY_PREFIX: z.string().optional(),

  // Server tuning
  CONNECTION_TIMEOUT_MS: z.coerce.number().int().positive().optional(),
  KEEP_ALIVE_TIMEOUT_MS: z.coerce.number().int().positive().optional(),
  MAX_PARAM_LENGTH: z.coerce.number().int().positive().optional(),
  PRESSURE_MAX_EVENT_LOOP_DELAY_MS: z.coerce.number().int().positive().optional(),
  PRESSURE_MAX_HEAP_USED_BYTES: z.coerce.number().int().positive().optional(),
  PRESSURE_MAX_RSS_BYTES: z.coerce.number().int().positive().optional(),
  PRESSURE_RETRY_AFTER_SECONDS: z.coerce.number().int().positive().optional(),

  // Auth
  JWT_SECRET: z.string().min(1).optional(),
  JWT_PRIVATE_KEY: z.string().min(1).optional(),
  JWT_PUBLIC_KEY: z.string().min(1).optional(),
  ACCESS_TOKEN_TTL_SECONDS: z.coerce.number().int().positive().default(900),
  REFRESH_TOKEN_TTL_SECONDS: z.coerce.number().int().positive().default(60 * 60 * 24 * 30),
  PASSWORD_ARGON2_MEMORY_COST: z.coerce.number().int().positive().default(19_456),
  PASSWORD_ARGON2_TIME_COST: z.coerce.number().int().positive().default(2),
  PASSWORD_ARGON2_PARALLELISM: z.coerce.number().int().positive().default(1),
});

type ParsedEnv = z.infer<typeof envSchema>;

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

function normalizeOptionalString(value: string | undefined): string | undefined {
  const normalized = value?.trim();
  return normalized ? normalized : undefined;
}

function validateEmailSettings(parsed: ParsedEnv): void {
  const from = normalizeOptionalString(parsed.EMAIL_FROM);
  const replyTo = normalizeOptionalString(parsed.EMAIL_REPLY_TO);

  if (from && !from.includes("@")) {
    throw new Error("EMAIL_FROM must be a valid sender value like 'Prava <no-reply@yourdomain.com>'");
  }

  if (replyTo && !replyTo.includes("@")) {
    throw new Error("EMAIL_REPLY_TO must be a valid email address");
  }
}

function resolveDatabaseUrl(parsed: ParsedEnv): string {
  const configured = parsed.DATABASE_URL?.trim();
  if (!configured) {
    if (parsed.NODE_ENV === "production") {
      throw new Error("DATABASE_URL is required in production");
    }
    return "postgresql://postgres:postgres@127.0.0.1:5432/prava";
  }

  if (configured.includes("<password>") || configured.includes("<db_password>")) {
    throw new Error("DATABASE_URL contains a placeholder; replace it with the real password");
  }

  return configured;
}

const parsed = envSchema.parse(process.env);
validateJwtSettings(parsed);
validateEmailSettings(parsed);

const defaultLogLevel = parsed.NODE_ENV === "production" ? "info" : "debug";

export const env = {
  ...parsed,
  LOG_LEVEL: parsed.LOG_LEVEL ?? defaultLogLevel,
  TRUST_PROXY: parseBoolean(parsed.TRUST_PROXY, true),
  CORS_ORIGINS: parseCorsOrigins(parsed.CORS_ORIGIN),
  DATABASE_URL: resolveDatabaseUrl(parsed),
  RESEND_API_KEY: normalizeOptionalString(parsed.RESEND_API_KEY),
  EMAIL_FROM: normalizeOptionalString(parsed.EMAIL_FROM),
  EMAIL_REPLY_TO: normalizeOptionalString(parsed.EMAIL_REPLY_TO),
  APP_NAME: parsed.APP_NAME.trim(),
  APP_PUBLIC_URL: normalizeOptionalString(parsed.APP_PUBLIC_URL),
  CLOUDINARY_CLOUD_NAME: normalizeOptionalString(parsed.CLOUDINARY_CLOUD_NAME),
  CLOUDINARY_API_KEY: normalizeOptionalString(parsed.CLOUDINARY_API_KEY),
  CLOUDINARY_API_SECRET: normalizeOptionalString(parsed.CLOUDINARY_API_SECRET),
  REDIS_TLS: parseBoolean(parsed.REDIS_TLS, false),
  REDIS_KEY_PREFIX: parsed.REDIS_KEY_PREFIX ?? "prava",
  CONNECTION_TIMEOUT_MS: parsed.CONNECTION_TIMEOUT_MS ?? 10_000,
  KEEP_ALIVE_TIMEOUT_MS: parsed.KEEP_ALIVE_TIMEOUT_MS ?? 60_000,
  MAX_PARAM_LENGTH: parsed.MAX_PARAM_LENGTH ?? 200,
};

export type AppEnv = typeof env;
