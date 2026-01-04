import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import {
  GetObjectCommand,
  HeadObjectCommand,
  PutObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { eq } from 'drizzle-orm';

import { db } from '@/db';
import { mediaAssets } from '@/db/schema/media_assets.schema';
import {
  getPublicBaseUrl,
  getS3Bucket,
  getS3Client,
} from '@/media/s3.client';
import { ConversationsService } from '@/modules/conversations/conversations.service';
import { mediaQueue } from '@/queue/bullmq.config';
import { config } from '@/app.config';

const MAX_MEDIA_BYTES = 100 * 1024 * 1024;
const UPLOAD_URL_TTL_SECONDS = 15 * 60;
const DOWNLOAD_URL_TTL_SECONDS = 15 * 60;

type MediaAssetRow = typeof mediaAssets.$inferSelect;

@Injectable()
export class MediaService {
  constructor(
    private readonly conversations: ConversationsService,
  ) {}

  private getS3ConfigOrThrow() {
    const s3 = getS3Client();
    const bucket = getS3Bucket();

    if (!s3 || !bucket) {
      throw new ServiceUnavailableException(
        'Media storage not configured',
      );
    }

    return { s3, bucket };
  }

  private buildStorageKey(input: {
    userId: string;
    conversationId?: string | null;
    assetId: string;
    fileName?: string | null;
  }) {
    const scope = input.conversationId ?? input.userId;
    const safeName = input.fileName
      ? input.fileName
          .replace(/[^a-zA-Z0-9._-]/g, '_')
          .slice(0, 128)
      : null;

    if (safeName) {
      return `media/${scope}/${input.assetId}/${safeName}`;
    }

    return `media/${scope}/${input.assetId}`;
  }

  private buildPublicUrl(key: string) {
    const base = getPublicBaseUrl();
    if (!base) return null;

    return `${base.replace(/\/+$/, '')}/${key}`;
  }

  private async getDownloadUrl(asset: MediaAssetRow) {
    if (asset.status !== 'ready') return null;

    const publicUrl = this.buildPublicUrl(asset.storageKey);
    if (publicUrl) return publicUrl;

    const { s3, bucket } = this.getS3ConfigOrThrow();
    return getSignedUrl(
      s3,
      new GetObjectCommand({
        Bucket: bucket,
        Key: asset.storageKey,
      }),
      { expiresIn: DOWNLOAD_URL_TTL_SECONDS },
    );
  }

  private async getThumbnailUrl(asset: MediaAssetRow) {
    if (!asset.thumbnailKey) return null;

    const publicUrl = this.buildPublicUrl(asset.thumbnailKey);
    if (publicUrl) return publicUrl;

    const { s3, bucket } = this.getS3ConfigOrThrow();
    return getSignedUrl(
      s3,
      new GetObjectCommand({
        Bucket: bucket,
        Key: asset.thumbnailKey,
      }),
      { expiresIn: DOWNLOAD_URL_TTL_SECONDS },
    );
  }

  async initUpload(input: {
    userId: string;
    conversationId: string;
    contentType: string;
    fileName?: string;
    sizeBytes?: number;
    sha256?: string;
    retentionPolicy?: 'standard' | 'ephemeral';
    encryptionAlgorithm?: string;
    encryptionKeyId?: string;
    encryptionIv?: string;
    encryptionKeyHash?: string;
    metadata?: Record<string, unknown>;
  }) {
    if (
      input.sizeBytes &&
      input.sizeBytes > MAX_MEDIA_BYTES
    ) {
      throw new BadRequestException(
        'Media file exceeds size limit',
      );
    }

    const { s3, bucket } = this.getS3ConfigOrThrow();

    const assetId = randomUUID();
    const storageKey = this.buildStorageKey({
      userId: input.userId,
      conversationId: input.conversationId,
      assetId,
      fileName: input.fileName,
    });
    const now = new Date();

    const [asset] = await db
      .insert(mediaAssets)
      .values({
        id: assetId,
        userId: input.userId,
        conversationId: input.conversationId,
        status: 'pending',
        contentType: input.contentType,
        fileName: input.fileName ?? null,
        sizeBytes: input.sizeBytes ?? null,
        sha256: input.sha256 ?? null,
        storageBucket: bucket,
        storageKey,
        storageRegion: config.S3_REGION ?? null,
        metadata: input.metadata ?? null,
        encryptionAlgorithm: input.encryptionAlgorithm ?? null,
        encryptionKeyId: input.encryptionKeyId ?? null,
        encryptionIv: input.encryptionIv ?? null,
        encryptionKeyHash: input.encryptionKeyHash ?? null,
        retentionPolicy: input.retentionPolicy ?? 'standard',
        updatedAt: now,
      })
      .returning();

    const uploadUrl = await getSignedUrl(
      s3,
      new PutObjectCommand({
        Bucket: bucket,
        Key: storageKey,
        ContentType: input.contentType,
      }),
      { expiresIn: UPLOAD_URL_TTL_SECONDS },
    );

    return {
      assetId: asset.id,
      uploadUrl,
      uploadMethod: 'PUT',
      uploadHeaders: {
        'Content-Type': input.contentType,
      },
      expiresIn: UPLOAD_URL_TTL_SECONDS,
      storageKey: asset.storageKey,
    };
  }

  async completeUpload(input: {
    assetId: string;
    userId: string;
    sizeBytes?: number;
    sha256?: string;
    metadata?: Record<string, unknown>;
    fileName?: string;
  }) {
    if (
      input.sizeBytes &&
      input.sizeBytes > MAX_MEDIA_BYTES
    ) {
      throw new BadRequestException(
        'Media file exceeds size limit',
      );
    }

    const asset = await db.query.mediaAssets.findFirst({
      where: eq(mediaAssets.id, input.assetId),
    });

    if (!asset) {
      throw new NotFoundException('Media not found');
    }

    if (asset.userId !== input.userId) {
      throw new ForbiddenException(
        'Media asset not owned',
      );
    }

    if (asset.status === 'failed') {
      throw new BadRequestException(
        'Media asset upload failed',
      );
    }

    if (asset.status === 'ready') {
      return { assetId: asset.id, status: asset.status };
    }

    if (asset.status === 'processing') {
      return { assetId: asset.id, status: asset.status };
    }

    const now = new Date();
    const [updated] = await db
      .update(mediaAssets)
      .set({
        status: 'uploaded',
        sizeBytes: input.sizeBytes ?? asset.sizeBytes,
        sha256: input.sha256 ?? asset.sha256,
        metadata: input.metadata ?? asset.metadata,
        fileName: input.fileName ?? asset.fileName,
        uploadedAt: now,
        updatedAt: now,
      })
      .where(eq(mediaAssets.id, asset.id))
      .returning();

    try {
      await mediaQueue.add(
        'process-media',
        { assetId: asset.id },
        {
          jobId: `media:${asset.id}`,
          attempts: 3,
          backoff: { type: 'exponential', delay: 5000 },
          removeOnComplete: true,
        },
      );
    } catch (err: any) {
      if (!String(err?.message || '').includes('Job already exists')) {
        throw err;
      }
    }

    return {
      assetId: updated.id,
      status: updated.status,
    };
  }

  async getAssetForUser(input: {
    assetId: string;
    userId: string;
  }) {
    const asset = await db.query.mediaAssets.findFirst({
      where: eq(mediaAssets.id, input.assetId),
    });

    if (!asset) return null;

    let canAccess = asset.userId === input.userId;
    if (!canAccess && asset.conversationId) {
      const member = await this.conversations.getMembership({
        conversationId: asset.conversationId,
        userId: input.userId,
      });
      canAccess = Boolean(member);
    }

    if (!canAccess) {
      throw new ForbiddenException('Media asset is restricted');
    }

    const downloadUrl = await this.getDownloadUrl(asset);
    const thumbnailUrl = await this.getThumbnailUrl(asset);

    return {
      asset: {
        id: asset.id,
        userId: asset.userId,
        conversationId: asset.conversationId,
        status: asset.status,
        contentType: asset.contentType,
        fileName: asset.fileName,
        sizeBytes: asset.sizeBytes,
        sha256: asset.sha256,
        metadata: asset.metadata,
        encryptionAlgorithm: asset.encryptionAlgorithm,
        encryptionKeyId: asset.encryptionKeyId,
        encryptionIv: asset.encryptionIv,
        encryptionKeyHash: asset.encryptionKeyHash,
        thumbnailKey: asset.thumbnailKey,
        thumbnailContentType: asset.thumbnailContentType,
        retentionPolicy: asset.retentionPolicy,
        expiresAt: asset.expiresAt,
        createdAt: asset.createdAt,
        updatedAt: asset.updatedAt,
        uploadedAt: asset.uploadedAt,
        processedAt: asset.processedAt,
      },
      downloadUrl,
      thumbnailUrl,
    };
  }

  async assertAssetReadyForMessage(input: {
    assetId: string;
    userId: string;
    conversationId: string;
  }) {
    const asset = await db.query.mediaAssets.findFirst({
      where: eq(mediaAssets.id, input.assetId),
    });

    if (!asset) {
      throw new BadRequestException('Media asset not found');
    }

    if (asset.userId !== input.userId) {
      throw new ForbiddenException(
        'Media asset not owned',
      );
    }

    if (
      asset.conversationId &&
      asset.conversationId !== input.conversationId
    ) {
      throw new BadRequestException(
        'Media asset is not in this conversation',
      );
    }

    if (!asset.conversationId) {
      await db
        .update(mediaAssets)
        .set({
          conversationId: input.conversationId,
          updatedAt: new Date(),
        })
        .where(eq(mediaAssets.id, asset.id));
    }

    if (asset.status !== 'ready') {
      throw new BadRequestException('Media is not ready');
    }

    return asset;
  }

  async verifyStorageObject(input: {
    assetId: string;
  }) {
    const asset = await db.query.mediaAssets.findFirst({
      where: eq(mediaAssets.id, input.assetId),
    });

    if (!asset) {
      throw new NotFoundException('Media not found');
    }

    const { s3, bucket } = this.getS3ConfigOrThrow();

    const head = await s3.send(
      new HeadObjectCommand({
        Bucket: bucket,
        Key: asset.storageKey,
      }),
    );

    return {
      contentLength: head.ContentLength ?? null,
      contentType: head.ContentType ?? null,
    };
  }
}
