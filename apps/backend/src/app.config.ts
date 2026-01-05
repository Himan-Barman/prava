import 'dotenv/config';

import { z } from 'zod';

const normalizePem = (value: string) =>
  value.includes('\\n') ? value.replace(/\\n/g, '\n') : value;

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']),
  PORT: z.coerce.number().default(3000),
  WS_PORT: z.coerce.number().default(3001),
  WS_MODE: z.enum(['standalone', 'shared']).optional(),

  CORS_ORIGIN: z
    .string()
    .optional()
    .transform((v) => {
      if (!v) return undefined;
      if (v === '*') return '*';
      return v.split(',').map((s) => s.trim());
    }),

  APP_NAME: z.string().optional(),
  RESEND_API_KEY: z.string().min(1).optional(),
  EMAIL_FROM: z.string().min(1).optional(),
  EMAIL_FROM_NAME: z.string().optional(),
  EMAIL_SUPPORT: z.string().optional(),
  EMAIL_TO: z.string().optional(),
  EMAIL_VERIFY_URL: z.string().optional(),
  PASSWORD_RESET_URL: z.string().optional(),

  DATABASE_URL: z.string().min(1),

  JWT_PRIVATE_KEY: z.string().min(1).transform(normalizePem),
  JWT_PUBLIC_KEY: z.string().min(1).transform(normalizePem),

  REDIS_URL: z.string().min(1),

  FCM_SERVICE_ACCOUNT_JSON: z.string().optional(),

  APNS_KEY_ID: z.string().optional(),
  APNS_TEAM_ID: z.string().optional(),
  APNS_BUNDLE_ID: z.string().optional(),
  APNS_PRIVATE_KEY: z.string().optional().transform((v) => {
    if (!v) return v;
    return normalizePem(v);
  }),
  APNS_ENV: z.enum(['development', 'production']).optional(),

  S3_ENDPOINT: z.string().optional(),
  S3_REGION: z.string().optional(),
  S3_ACCESS_KEY_ID: z.string().optional(),
  S3_SECRET_ACCESS_KEY: z.string().optional(),
  S3_BUCKET: z.string().optional(),
  S3_PUBLIC_BASE_URL: z.string().optional(),
  S3_FORCE_PATH_STYLE: z
    .string()
    .optional()
    .transform((v) => v === 'true'),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error('Invalid environment configuration');
  console.error(parsed.error.format());
  process.exit(1);
}

const data = parsed.data;

export const config = {
  ...data,
  EMAIL_SUPPORT: data.EMAIL_SUPPORT ?? data.EMAIL_TO,
};
