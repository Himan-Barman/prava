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
  MONGODB_URI: z.string().min(1).default("mongodb://127.0.0.1:27017/prava_chat"),
  MONGODB_DB_NAME: z.string().min(1).default("prava_chat"),
  JWT_SECRET: z.string().min(1).optional(),
  JWT_PRIVATE_KEY: z.string().min(1).optional(),
  ACCESS_TOKEN_TTL_SECONDS: z.coerce.number().int().positive().default(900),
  REFRESH_TOKEN_TTL_SECONDS: z.coerce.number().int().positive().default(60 * 60 * 24 * 30),
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

const parsed = envSchema.parse(process.env);
validateJwtSettings(parsed);

const defaultLogLevel = parsed.NODE_ENV === "production" ? "info" : "debug";

export const env = {
  ...parsed,
  LOG_LEVEL: parsed.LOG_LEVEL ?? defaultLogLevel,
  TRUST_PROXY: parseBoolean(parsed.TRUST_PROXY, true),
  CORS_ORIGINS: parseCorsOrigins(parsed.CORS_ORIGIN),
};

export type AppEnv = typeof env;
