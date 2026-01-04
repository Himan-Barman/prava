import { z } from 'zod';

export const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
  WS_PORT: z.coerce.number().default(3001),
  WS_MODE: z.enum(['standalone', 'shared']).optional(),

  CORS_ORIGIN: z.string().optional(),

  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().url(),

  JWT_PRIVATE_KEY: z.string().min(1),
  JWT_PUBLIC_KEY: z.string().min(1),

  FCM_SERVICE_ACCOUNT_JSON: z.string().optional(),

  APNS_KEY_ID: z.string().optional(),
  APNS_TEAM_ID: z.string().optional(),
  APNS_BUNDLE_ID: z.string().optional(),
  APNS_PRIVATE_KEY: z.string().optional(),
  APNS_ENV: z.enum(['development', 'production']).optional(),

  S3_ENDPOINT: z.string().optional(),
  S3_REGION: z.string().optional(),
  S3_ACCESS_KEY_ID: z.string().optional(),
  S3_SECRET_ACCESS_KEY: z.string().optional(),
  S3_BUCKET: z.string().optional(),
  S3_PUBLIC_BASE_URL: z.string().optional(),
  S3_FORCE_PATH_STYLE: z.string().optional(),
});

export type EnvConfig = z.infer<typeof envSchema>;
