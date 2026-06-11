import crypto from "node:crypto";
import { hashSync as argon2HashSync, type Options as Argon2Options, verifySync as argon2VerifySync } from "@node-rs/argon2";
import jwt, { type JwtPayload } from "jsonwebtoken";

import { env } from "../config/env.js";

const ARGON2ID_ALGORITHM = 2 as Argon2Options["algorithm"];

export interface JwtUserPayload extends JwtPayload {
  sub: string;
  email?: string;
  username?: string;
}

export interface UserIdentity {
  userId: string;
  email?: string;
  username?: string;
  displayName?: string;
  isVerified?: boolean;
  sessionId?: string;
  role?: string;
  tokenVersion?: number;
}

function normalizeJwtKey(value: string | undefined): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed.replace(/\\n/g, "\n") : undefined;
}

function getJwtSigningKey(): { key: string; algorithm: "HS256" | "RS256" } {
  const privateKey = normalizeJwtKey(env.JWT_PRIVATE_KEY);
  if (privateKey) {
    return {
      key: privateKey,
      algorithm: "RS256",
    };
  }

  const secret = env.JWT_SECRET || env.JWT_PRIVATE_KEY;
  if (!secret || !secret.trim()) {
    throw new Error("JWT secret is required");
  }

  return {
    key: secret.trim(),
    algorithm: "HS256",
  };
}

function getJwtVerificationKey(): { key: string; algorithms: Array<"HS256" | "RS256"> } {
  const publicKey = normalizeJwtKey(env.JWT_PUBLIC_KEY);
  if (publicKey) {
    return {
      key: publicKey,
      algorithms: ["RS256"],
    };
  }

  const privateKey = normalizeJwtKey(env.JWT_PRIVATE_KEY);
  if (privateKey) {
    return {
      key: privateKey,
      algorithms: ["RS256"],
    };
  }

  const secret = env.JWT_SECRET;
  if (!secret || !secret.trim()) {
    throw new Error("JWT secret is required");
  }

  return {
    key: secret.trim(),
    algorithms: ["HS256"],
  };
}

export function now(): Date {
  return new Date();
}

export function toIso(value: unknown): string | null {
  if (!value) {
    return null;
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  const parsed = new Date(value as string | number);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }
  return parsed.toISOString();
}

export function normalizeEmail(value: unknown): string {
  return String(value || "").trim().toLowerCase();
}

export function normalizeUsername(value: unknown): string {
  return String(value || "").trim().toLowerCase();
}

export function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

export function isValidUsername(username: string): boolean {
  return /^[a-z0-9_.]{3,32}$/.test(username);
}

export function isValidPassword(password: unknown): boolean {
  const val = String(password || "");
  return val.length >= 8 && val.length <= 128;
}

export function hashPassword(password: string): string {
  return argon2HashSync(password, {
    algorithm: ARGON2ID_ALGORITHM,
    memoryCost: env.PASSWORD_ARGON2_MEMORY_COST,
    timeCost: env.PASSWORD_ARGON2_TIME_COST,
    parallelism: env.PASSWORD_ARGON2_PARALLELISM,
  });
}

export function verifyPassword(password: string, encoded: unknown): boolean {
  if (!encoded || typeof encoded !== "string") {
    return false;
  }

  if (encoded.startsWith("$argon2id$")) {
    try {
      return argon2VerifySync(encoded, password);
    } catch {
      return false;
    }
  }

  const parts = encoded.split("$");
  if (parts.length !== 3 || parts[0] !== "scrypt") {
    return false;
  }

  const salt = parts[1];
  const expected = Buffer.from(parts[2], "hex");
  const actual = Buffer.from(crypto.scryptSync(password, salt, 64));
  if (expected.length !== actual.length) {
    return false;
  }
  return crypto.timingSafeEqual(expected, actual);
}

export function sha256(value: unknown): string {
  return crypto
    .createHash("sha256")
    .update(String(value || ""))
    .digest("hex");
}

export function generateId(): string {
  return crypto.randomUUID();
}

export function generateOtpCode(): string {
  return String(Math.floor(100000 + Math.random() * 900000));
}

export function generateRefreshToken(): { raw: string; hash: string } {
  const raw = crypto.randomBytes(48).toString("hex");
  return {
    raw,
    hash: sha256(raw),
  };
}

export function issueAccessToken(user: UserIdentity): string {
  const signing = getJwtSigningKey();
  return jwt.sign(
    {
      sub: user.userId,
      email: user.email,
      username: user.username,
      sid: user.sessionId,
      role: user.role,
      tokenVersion: user.tokenVersion ?? 1,
    },
    signing.key,
    {
      algorithm: signing.algorithm,
      expiresIn: env.ACCESS_TOKEN_TTL_SECONDS,
      issuer: "prava",
      audience: "prava-clients",
    }
  );
}

export function verifyAccessToken(token: string): JwtUserPayload {
  const verification = getJwtVerificationKey();
  const decoded = jwt.verify(token, verification.key, {
    algorithms: verification.algorithms,
    issuer: "prava",
    audience: "prava-clients",
  });

  if (!decoded || typeof decoded !== "object" || typeof decoded.sub !== "string") {
    throw new Error("Invalid access token payload");
  }

  return decoded as JwtUserPayload;
}

export function getRefreshTtlSeconds(): number {
  return env.REFRESH_TOKEN_TTL_SECONDS;
}

export class HttpError extends Error {
  readonly statusCode: number;

  constructor(statusCode: number, message: string) {
    super(message);
    this.name = "HttpError";
    this.statusCode = statusCode;
  }
}

export function ensure(condition: unknown, statusCode: number, message: string): asserts condition {
  if (!condition) {
    throw new HttpError(statusCode, message);
  }
}

export function buildUserView(user: UserIdentity): {
  id: string;
  email: string;
  username: string;
  displayName: string;
  isVerified: boolean;
} {
  return {
    id: user.userId,
    email: user.email || "",
    username: user.username || "",
    displayName: user.displayName || user.username || "",
    isVerified: user.isVerified === true,
  };
}
