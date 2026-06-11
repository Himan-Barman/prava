import crypto from "node:crypto";

import { env } from "../../config/env.js";
import { HttpError } from "../../lib/security.js";

const CURSOR_VERSION = 1;

function signingSecret(): string {
  return env.JWT_SECRET || env.JWT_PRIVATE_KEY || "prava-development-cursor-secret";
}

function sign(value: string): string {
  return crypto.createHmac("sha256", signingSecret()).update(value).digest("base64url");
}

export function encodeCursor(payload: Record<string, unknown>): string {
  const body = Buffer.from(JSON.stringify({
    v: CURSOR_VERSION,
    payload,
  })).toString("base64url");
  return `${body}.${sign(body)}`;
}

export function decodeCursor<T extends Record<string, unknown>>(raw: unknown): T | null {
  const value = String(raw || "").trim();
  if (!value) {
    return null;
  }

  const [body, signature] = value.split(".");
  if (!body || !signature || sign(body) !== signature) {
    throw new HttpError(400, "Invalid cursor");
  }

  const decoded = JSON.parse(Buffer.from(body, "base64url").toString("utf8"));
  if (!decoded || decoded.v !== CURSOR_VERSION || !decoded.payload) {
    throw new HttpError(400, "Invalid cursor");
  }
  return decoded.payload as T;
}

export function pageLimit(raw: unknown, fallback = 30, max = 100): number {
  const parsed = Number.parseInt(String(raw || ""), 10);
  if (Number.isNaN(parsed)) {
    return fallback;
  }
  return Math.max(1, Math.min(max, parsed));
}
