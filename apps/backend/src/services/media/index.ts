import { requireAuth } from "../../lib/auth.js";
import {
  deleteMedia,
  isCloudinaryConfigured,
  uploadMedia,
} from "../../lib/cloudinary.js";
import { query, queryMany, queryOne } from "../../lib/pg.js";
import {
  HttpError,
  ensure,
  now,
  toIso,
} from "../../lib/security.js";

function normalizeString(value: unknown): string {
  return String(value || "").trim();
}

function parseLimit(raw: unknown, fallback: number, min: number, max: number): number {
  const parsed = Number.parseInt(String(raw || ""), 10);
  if (Number.isNaN(parsed)) {
    return fallback;
  }
  return Math.max(min, Math.min(max, parsed));
}

function mapMediaAsset(row: any) {
  return {
    assetId: row.asset_id,
    publicId: row.public_id,
    url: row.url,
    secureUrl: row.secure_url,
    resourceType: row.resource_type,
    format: row.format || "",
    width: row.width ?? null,
    height: row.height ?? null,
    bytes: row.bytes == null ? null : Number(row.bytes),
    folder: row.folder || "",
    context: row.context || "general",
    createdAt: toIso(row.created_at),
  };
}

export default async function mediaService(app: any) {
  app.get("/", { preHandler: requireAuth }, async (request: any) => {
    const limit = parseLimit(request.query?.limit, 30, 1, 100);
    const rows = await queryMany(
      `SELECT *
       FROM media_assets
       WHERE user_id = $1
       ORDER BY created_at DESC
       LIMIT $2`,
      [request.user.userId, limit]
    );

    return {
      items: rows.map(mapMediaAsset),
    };
  });

  app.get("/:assetId", { preHandler: requireAuth }, async (request: any) => {
    const assetId = normalizeString(request.params.assetId);
    ensure(assetId.length >= 3, 400, "Invalid asset");

    const row = await queryOne(
      `SELECT *
       FROM media_assets
       WHERE asset_id = $1 AND user_id = $2`,
      [assetId, request.user.userId]
    );
    if (!row) {
      throw new HttpError(404, "Media asset not found");
    }

    return { asset: mapMediaAsset(row) };
  });

  app.post("/upload", { preHandler: requireAuth }, async (request: any) => {
    if (!isCloudinaryConfigured()) {
      throw new HttpError(503, "Media uploads are not configured");
    }

    const body = request.body || {};
    const source = normalizeString(body.file || body.url || body.dataUri);
    ensure(source.length > 0, 400, "Missing upload source");

    const resourceType = normalizeString(body.resourceType || "auto").toLowerCase();
    ensure(["auto", "image", "video", "raw"].includes(resourceType), 400, "Invalid resource type");

    const context = normalizeString(body.context || "general").slice(0, 80) || "general";
    const folder = normalizeString(body.folder || "prava").slice(0, 120) || "prava";

    const uploaded = await uploadMedia(source, {
      folder,
      resourceType: resourceType as "auto" | "image" | "video" | "raw",
    });
    const createdAt = now();

    await query(
      `INSERT INTO media_assets (
         asset_id, user_id, public_id, url, secure_url, resource_type, format,
         width, height, bytes, folder, context, created_at
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
       ON CONFLICT (asset_id) DO NOTHING`,
      [
        uploaded.assetId,
        request.user.userId,
        uploaded.publicId,
        uploaded.url,
        uploaded.secureUrl,
        uploaded.resourceType,
        uploaded.format,
        uploaded.width,
        uploaded.height,
        uploaded.bytes,
        folder,
        context,
        createdAt,
      ]
    );

    return {
      asset: {
        ...uploaded,
        folder,
        context,
        createdAt: toIso(createdAt),
      },
    };
  });

  app.delete("/:assetId", { preHandler: requireAuth }, async (request: any) => {
    const assetId = normalizeString(request.params.assetId);
    ensure(assetId.length >= 3, 400, "Invalid asset");

    const row = await queryOne(
      `SELECT public_id, resource_type
       FROM media_assets
       WHERE asset_id = $1 AND user_id = $2`,
      [assetId, request.user.userId]
    );
    if (!row) {
      throw new HttpError(404, "Media asset not found");
    }

    await deleteMedia(row.public_id, row.resource_type || "image");
    const result = await query(
      `DELETE FROM media_assets WHERE asset_id = $1 AND user_id = $2`,
      [assetId, request.user.userId]
    );

    return {
      deleted: (result.rowCount || 0) > 0,
    };
  });
}
