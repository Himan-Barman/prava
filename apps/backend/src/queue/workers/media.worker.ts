import { Worker } from 'bullmq';
import { HeadObjectCommand } from '@aws-sdk/client-s3';
import { eq } from 'drizzle-orm';

import { connection } from '../bullmq.config';
import { db } from '@/db';
import { mediaAssets } from '@/db/schema/media_assets.schema';
import { getS3Bucket, getS3Client } from '@/media/s3.client';

type MediaJob = {
  assetId: string;
};

export const mediaWorker = new Worker<MediaJob>(
  'media',
  async (job) => {
    if (job.name !== 'process-media') return;

    const asset = await db.query.mediaAssets.findFirst({
      where: eq(mediaAssets.id, job.data.assetId),
    });

    if (!asset) return;
    if (asset.status === 'ready') return;
    if (asset.status === 'failed') return;
    if (asset.status === 'pending') return;

    await db
      .update(mediaAssets)
      .set({ status: 'processing', updatedAt: new Date() })
      .where(eq(mediaAssets.id, asset.id));

    const s3 = getS3Client();
    const bucket = getS3Bucket();
    if (!s3 || !bucket) {
      await db
        .update(mediaAssets)
        .set({ status: 'failed', updatedAt: new Date() })
        .where(eq(mediaAssets.id, asset.id));
      return;
    }

    try {
      const head = await s3.send(
        new HeadObjectCommand({
          Bucket: bucket,
          Key: asset.storageKey,
        }),
      );

      const sizeBytes =
        typeof head.ContentLength === 'number'
          ? head.ContentLength
          : asset.sizeBytes ?? null;
      const contentType = head.ContentType ?? asset.contentType;

      await db
        .update(mediaAssets)
        .set({
          status: 'ready',
          sizeBytes,
          contentType,
          processedAt: new Date(),
          updatedAt: new Date(),
        })
        .where(eq(mediaAssets.id, asset.id));
    } catch (err) {
      const attempts = job.opts.attempts ?? 1;
      const isLastAttempt =
        job.attemptsMade + 1 >= attempts;

      if (isLastAttempt) {
        await db
          .update(mediaAssets)
          .set({ status: 'failed', updatedAt: new Date() })
          .where(eq(mediaAssets.id, asset.id));
      }

      throw err;
    }
  },
  {
    ...connection,
    concurrency: 5,
  },
);
