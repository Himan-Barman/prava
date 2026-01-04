import { S3Client } from '@aws-sdk/client-s3';
import { config } from '@/app.config';

let cachedClient: S3Client | null = null;

export const getS3Client = () => {
  if (cachedClient) return cachedClient;

  if (
    !config.S3_REGION ||
    !config.S3_ACCESS_KEY_ID ||
    !config.S3_SECRET_ACCESS_KEY
  ) {
    return null;
  }

  cachedClient = new S3Client({
    region: config.S3_REGION,
    endpoint: config.S3_ENDPOINT,
    forcePathStyle: Boolean(config.S3_FORCE_PATH_STYLE),
    credentials: {
      accessKeyId: config.S3_ACCESS_KEY_ID,
      secretAccessKey: config.S3_SECRET_ACCESS_KEY,
    },
  });

  return cachedClient;
};

export const getS3Bucket = () => config.S3_BUCKET;

export const getPublicBaseUrl = () => config.S3_PUBLIC_BASE_URL;
