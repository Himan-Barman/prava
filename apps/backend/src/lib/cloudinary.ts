import { v2 as cloudinary } from "cloudinary";

import { env } from "../config/env.js";

let configured = false;

export function configureCloudinary(): void {
  if (configured) return;

  if (!env.CLOUDINARY_CLOUD_NAME || !env.CLOUDINARY_API_KEY || !env.CLOUDINARY_API_SECRET) {
    return;
  }

  cloudinary.config({
    cloud_name: env.CLOUDINARY_CLOUD_NAME,
    api_key: env.CLOUDINARY_API_KEY,
    api_secret: env.CLOUDINARY_API_SECRET,
    secure: true,
  });

  configured = true;
}

export function isCloudinaryConfigured(): boolean {
  return configured;
}

export interface UploadResult {
  assetId: string;
  publicId: string;
  url: string;
  secureUrl: string;
  resourceType: string;
  format: string;
  width: number | null;
  height: number | null;
  bytes: number | null;
}

export async function uploadMedia(
  file: string | Buffer,
  options: {
    folder?: string;
    resourceType?: "image" | "video" | "raw" | "auto";
    transformation?: object[];
    publicId?: string;
  } = {}
): Promise<UploadResult> {
  if (!configured) {
    throw new Error("Cloudinary is not configured");
  }

  const uploadOptions: Record<string, unknown> = {
    folder: options.folder || "prava",
    resource_type: options.resourceType || "auto",
    unique_filename: true,
    overwrite: false,
  };

  if (options.transformation) {
    uploadOptions.transformation = options.transformation;
  }

  if (options.publicId) {
    uploadOptions.public_id = options.publicId;
  }

  const result = await cloudinary.uploader.upload(
    typeof file === "string" ? file : `data:application/octet-stream;base64,${file.toString("base64")}`,
    uploadOptions
  );

  return {
    assetId: result.asset_id || result.public_id,
    publicId: result.public_id,
    url: result.url,
    secureUrl: result.secure_url,
    resourceType: result.resource_type || "image",
    format: result.format || "",
    width: result.width ?? null,
    height: result.height ?? null,
    bytes: result.bytes ?? null,
  };
}

export async function deleteMedia(publicId: string, resourceType = "image"): Promise<boolean> {
  if (!configured) {
    return false;
  }

  try {
    const result = await cloudinary.uploader.destroy(publicId, {
      resource_type: resourceType,
    });
    return result.result === "ok";
  } catch {
    return false;
  }
}

export function getCloudinary() {
  return cloudinary;
}
