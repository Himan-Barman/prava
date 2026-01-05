import {
  BadRequestException,
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import * as argon2 from 'argon2';
import { and, desc, eq, gt, isNull, not } from 'drizzle-orm';
import crypto from 'node:crypto';

import { db } from '@/db';
import { users } from '@/db/schema/users.schema';
import { refreshTokens } from '@/db/schema/refresh_tokens.schema';
import { emailVerificationTokens } from '@/db/schema/email_verification_tokens.schema';
import { passwordResetTokens } from '@/db/schema/password_reset_tokens.schema';
import { emailOtpTokens } from '@/db/schema/email_otp_tokens.schema';

import { TokenService } from './token.service';
import { emailQueue } from '@/queue/bullmq.config';

@Injectable()
export class AuthService {
  constructor(private readonly tokens: TokenService) {}

  /* ================= REGISTER ================= */

  async register(input: {
    email: string;
    password: string;
    username?: string;
    deviceId: string;
    deviceName?: string;
    platform?: 'android' | 'ios' | 'web' | 'desktop';
  }) {
    const email = input.email.trim().toLowerCase();
    const username = this.normalizeUsername(
      input.username ?? email.split('@')[0],
    );
    if (!username) {
      throw new BadRequestException('Invalid username');
    }

    await this.ensureEmailOtpVerified(email);

    const passwordHash = await this.hashPassword(input.password);

    let user;
    try {
      [user] = await db
        .insert(users)
        .values({
          email,
          username,
          displayName: username,
          passwordHash,
          isVerified: true,
          emailVerifiedAt: new Date(),
        })
        .returning({
          id: users.id,
          email: users.email,
          username: users.username,
          displayName: users.displayName,
          isVerified: users.isVerified,
        });
    } catch (err: any) {
      if (err.code === '23505') {
        if (
          String(err?.constraint || '').includes(
            'users_username_unique',
          )
        ) {
          throw new ConflictException('Username already exists');
        }
        throw new ConflictException('Email already exists');
      }
      throw err;
    }

    const refreshToken = await this.issueRefreshToken(
      user.id,
      input.deviceId,
      {
        deviceName: input.deviceName,
        platform: input.platform,
      },
    );

    return {
      user,
      accessToken: this.tokens.signAccessToken({ sub: user.id }),
      refreshToken,
    };
  }

  /* ================= LOGIN ================= */

  async login(input: {
    email: string;
    password: string;
    deviceId: string;
    deviceName?: string;
    platform?: 'android' | 'ios' | 'web' | 'desktop';
  }) {
    const identifier = input.email.trim().toLowerCase();
    const isEmail = identifier.includes('@');

    const user = await db.query.users.findFirst({
      where: isEmail
        ? eq(users.email, identifier)
        : eq(users.username, identifier),
    });

    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const valid = await argon2.verify(
      user.passwordHash,
      input.password,
    );

    if (!valid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const refreshToken = await this.issueRefreshToken(
      user.id,
      input.deviceId,
      {
        deviceName: input.deviceName,
        platform: input.platform,
      },
    );

    return {
      user: {
        id: user.id,
        email: user.email,
        username: user.username,
        displayName: user.displayName,
        isVerified: user.isVerified,
      },
      accessToken: this.tokens.signAccessToken({ sub: user.id }),
      refreshToken,
    };
  }

  /* ================= REFRESH ================= */

  async refresh(input: {
    refreshToken: string;
    deviceId: string;
  }) {
    const record = await this.findValidRefreshToken(
      input.refreshToken,
      input.deviceId,
    );

    await this.revokeRefreshToken(record.id);

    const refreshToken = await this.issueRefreshToken(
      record.userId,
      input.deviceId,
      {
        deviceName: record.deviceName ?? undefined,
        platform: record.platform ?? undefined,
      },
    );

    return {
      accessToken: this.tokens.signAccessToken({
        sub: record.userId,
      }),
      refreshToken,
    };
  }

  /* ================= LOGOUT ================= */

  async logout(userId: string, deviceId: string) {
    await db
      .update(refreshTokens)
      .set({ revokedAt: new Date() })
      .where(
        and(
          eq(refreshTokens.userId, userId),
          eq(refreshTokens.deviceId, deviceId),
        ),
      );
  }

  async logoutAll(userId: string) {
    await db
      .update(refreshTokens)
      .set({ revokedAt: new Date() })
      .where(eq(refreshTokens.userId, userId));
  }

  /* ================= EMAIL VERIFICATION ================= */

  async requestEmailVerification(email: string) {
    const normalized = email.trim().toLowerCase();
    const user = await db.query.users.findFirst({
      where: eq(users.email, normalized),
    });

    // Anti-enumeration: do not reveal if email exists or is verified
    if (!user || user.isVerified) {
      return { success: true };
    }

    const now = new Date();

    await db
      .update(emailVerificationTokens)
      .set({ usedAt: now })
      .where(
        and(
          eq(emailVerificationTokens.userId, user.id),
          isNull(emailVerificationTokens.usedAt),
          gt(emailVerificationTokens.expiresAt, now),
        ),
      );

    await this.createEmailVerification(user.id, user.email);

    return { success: true };
  }

  async verifyEmail(token: string) {
    const hash = this.hash(token);

    const record =
      await db.query.emailVerificationTokens.findFirst({
        where: and(
          eq(emailVerificationTokens.tokenHash, hash),
          isNull(emailVerificationTokens.usedAt),
          gt(emailVerificationTokens.expiresAt, new Date()),
        ),
      });

    if (!record) {
      throw new UnauthorizedException('Invalid or expired code');
    }

    await db.transaction(async (tx) => {
      await tx
        .update(users)
        .set({
          isVerified: true,
          emailVerifiedAt: new Date(),
        })
        .where(eq(users.id, record.userId));

      await tx
        .update(emailVerificationTokens)
        .set({ usedAt: new Date() })
        .where(eq(emailVerificationTokens.id, record.id));
    });

    return { verified: true };
  }

  /* ================= PASSWORD RESET ================= */

  async requestPasswordReset(email: string) {
    const normalized = email.trim().toLowerCase();
    const user = await db.query.users.findFirst({
      where: eq(users.email, normalized),
    });

    // Anti-enumeration
    if (!user) return { success: true };

    await this.createPasswordReset(user.id, user.email);
    return { success: true };
  }

  async resetPassword(input: {
    token: string;
    newPassword: string;
  }) {
    const hash = this.hash(input.token.trim());

    const record =
      await db.query.passwordResetTokens.findFirst({
        where: and(
          eq(passwordResetTokens.tokenHash, hash),
          isNull(passwordResetTokens.usedAt),
          gt(passwordResetTokens.expiresAt, new Date()),
        ),
      });

    if (!record) {
      throw new UnauthorizedException('Invalid or expired code');
    }

    const newHash = await this.hashPassword(input.newPassword);

    await db.transaction(async (tx) => {
      await tx
        .update(users)
        .set({ passwordHash: newHash })
        .where(eq(users.id, record.userId));

      await tx
        .update(passwordResetTokens)
        .set({ usedAt: new Date() })
        .where(eq(passwordResetTokens.id, record.id));

      // Revoke all sessions
      await tx
        .update(refreshTokens)
        .set({ revokedAt: new Date() })
        .where(eq(refreshTokens.userId, record.userId));
    });

    return { success: true };
  }

  /* ================= EMAIL OTP (SIGNUP) ================= */

  async requestEmailOtp(email: string) {
    const normalized = email.trim().toLowerCase();
    const now = new Date();

    const [existingUser] = await db
      .select({ id: users.id, isVerified: users.isVerified })
      .from(users)
      .where(eq(users.email, normalized))
      .limit(1);

    // Anti-enumeration: do not reveal if email exists
    if (existingUser?.isVerified) {
      return { success: true };
    }

    await db
      .update(emailOtpTokens)
      .set({ usedAt: now })
      .where(
        and(
          eq(emailOtpTokens.email, normalized),
          isNull(emailOtpTokens.usedAt),
          gt(emailOtpTokens.expiresAt, now),
        ),
      );

    const expiresInMinutes = 10;
    const code = this.generateOtpCode();
    const hash = this.hash(code);
    const expiresAt = new Date(
      Date.now() + 1000 * 60 * expiresInMinutes,
    );

    await db.insert(emailOtpTokens).values({
      email: normalized,
      tokenHash: hash,
      expiresAt,
    });

    await emailQueue.add(
      'email-otp',
      {
        type: 'email-otp',
        email: normalized,
        code,
        expiresInMinutes,
      },
      { attempts: 5, backoff: { type: 'exponential', delay: 3000 } },
    );

    return { success: true, expiresIn: expiresInMinutes * 60 };
  }

  async verifyEmailOtp(input: { email: string; code: string }) {
    const normalized = input.email.trim().toLowerCase();
    const now = new Date();

    const [record] = await db
      .select({
        id: emailOtpTokens.id,
        tokenHash: emailOtpTokens.tokenHash,
        attempts: emailOtpTokens.attempts,
      })
      .from(emailOtpTokens)
      .where(
        and(
          eq(emailOtpTokens.email, normalized),
          isNull(emailOtpTokens.usedAt),
          gt(emailOtpTokens.expiresAt, now),
        ),
      )
      .orderBy(desc(emailOtpTokens.createdAt))
      .limit(1);

    if (!record) {
      throw new UnauthorizedException('Invalid or expired code');
    }

    if (record.attempts >= 5) {
      await db
        .update(emailOtpTokens)
        .set({ usedAt: now })
        .where(eq(emailOtpTokens.id, record.id));
      throw new UnauthorizedException('Invalid or expired code');
    }

    const hash = this.hash(input.code.trim());
    if (record.tokenHash !== hash) {
      const attempts = record.attempts + 1;
      await db
        .update(emailOtpTokens)
        .set({
          attempts,
          usedAt: attempts >= 5 ? now : null,
        })
        .where(eq(emailOtpTokens.id, record.id));
      throw new UnauthorizedException('Invalid or expired code');
    }

    await db
      .update(emailOtpTokens)
      .set({ usedAt: now })
      .where(eq(emailOtpTokens.id, record.id));

    await db
      .update(users)
      .set({
        isVerified: true,
        emailVerifiedAt: now,
      })
      .where(
        and(
          eq(users.email, normalized),
          eq(users.isVerified, false),
        ),
      );

    return { verified: true };
  }

  /* ================= SESSIONS ================= */

  async listSessions(userId: string) {
    return db
      .select({
        id: refreshTokens.id,
        deviceId: refreshTokens.deviceId,
        deviceName: refreshTokens.deviceName,
        platform: refreshTokens.platform,
        createdAt: refreshTokens.createdAt,
        lastSeenAt: refreshTokens.lastSeenAt,
        expiresAt: refreshTokens.expiresAt,
      })
      .from(refreshTokens)
      .where(
        and(
          eq(refreshTokens.userId, userId),
          isNull(refreshTokens.revokedAt),
          gt(refreshTokens.expiresAt, new Date()),
        ),
      )
      .orderBy(refreshTokens.createdAt);
  }

  async revokeSession(input: {
    userId: string;
    deviceId: string;
  }) {
    await db
      .update(refreshTokens)
      .set({ revokedAt: new Date() })
      .where(
        and(
          eq(refreshTokens.userId, input.userId),
          eq(refreshTokens.deviceId, input.deviceId),
          isNull(refreshTokens.revokedAt),
        ),
      );

    return { success: true };
  }

  async revokeOtherSessions(input: {
    userId: string;
    currentDeviceId: string;
  }) {
    await db
      .update(refreshTokens)
      .set({ revokedAt: new Date() })
      .where(
        and(
          eq(refreshTokens.userId, input.userId),
          isNull(refreshTokens.revokedAt),
          not(eq(refreshTokens.deviceId, input.currentDeviceId)),
        ),
      );

    return { success: true };
  }

  /* ================= INTERNAL HELPERS ================= */

  private async issueRefreshToken(
    userId: string,
    deviceId: string,
    input?: {
      deviceName?: string;
      platform?: 'android' | 'ios' | 'web' | 'desktop';
    },
  ) {
    const { raw, hash } = this.tokens.generateRefreshToken();
    const now = new Date();

    await db.insert(refreshTokens).values({
      userId,
      deviceId,
      deviceName: input?.deviceName ?? null,
      platform: input?.platform ?? null,
      tokenHash: hash,
      expiresAt: this.tokens.refreshExpiryDate(),
      lastSeenAt: now,
    });

    return raw;
  }

  private async findValidRefreshToken(
    rawToken: string,
    deviceId: string,
  ) {
    const hash = this.hash(rawToken);

    const record = await db.query.refreshTokens.findFirst({
      where: and(
        eq(refreshTokens.tokenHash, hash),
        eq(refreshTokens.deviceId, deviceId),
        isNull(refreshTokens.revokedAt),
        gt(refreshTokens.expiresAt, new Date()),
      ),
    });

    if (!record) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    return record;
  }

  private async revokeRefreshToken(id: string) {
    await db
      .update(refreshTokens)
      .set({ revokedAt: new Date() })
      .where(eq(refreshTokens.id, id));
  }

  private async createEmailVerification(
    userId: string,
    email: string,
  ) {
    const raw = crypto.randomBytes(32).toString('hex');
    const hash = this.hash(raw);

    await db.insert(emailVerificationTokens).values({
      userId,
      tokenHash: hash,
      expiresAt: new Date(Date.now() + 1000 * 60 * 60),
    });

    await emailQueue.add(
      'verify-email',
      { type: 'verify-email', email, token: raw },
      { attempts: 5, backoff: { type: 'exponential', delay: 3000 } },
    );
  }

  private async createPasswordReset(
    userId: string,
    email: string,
  ) {
    const now = new Date();
    const expiresInMinutes = 10;
    const code = this.generateOtpCode();
    const hash = this.hash(code);

    await db
      .update(passwordResetTokens)
      .set({ usedAt: now })
      .where(
        and(
          eq(passwordResetTokens.userId, userId),
          isNull(passwordResetTokens.usedAt),
          gt(passwordResetTokens.expiresAt, now),
        ),
      );

    await db.insert(passwordResetTokens).values({
      userId,
      tokenHash: hash,
      expiresAt: new Date(
        Date.now() + 1000 * 60 * expiresInMinutes,
      ),
    });

    await emailQueue.add(
      'password-reset',
      {
        type: 'password-reset',
        email,
        code,
        expiresInMinutes,
      },
      { attempts: 5, backoff: { type: 'exponential', delay: 3000 } },
    );

    return code;
  }

  private async ensureEmailOtpVerified(email: string) {
    const cutoff = new Date(Date.now() - 1000 * 60 * 15);

    const [record] = await db
      .select({ id: emailOtpTokens.id })
      .from(emailOtpTokens)
      .where(
        and(
          eq(emailOtpTokens.email, email),
          not(isNull(emailOtpTokens.usedAt)),
          gt(emailOtpTokens.usedAt, cutoff),
        ),
      )
      .orderBy(desc(emailOtpTokens.usedAt))
      .limit(1);

    if (!record) {
      throw new UnauthorizedException('Email verification required');
    }
  }

  private generateOtpCode() {
    const value = crypto.randomInt(0, 1000000);
    return value.toString().padStart(6, '0');
  }

  private async hashPassword(password: string) {
    return argon2.hash(password, { type: argon2.argon2id });
  }

  private hash(token: string) {
    return crypto
      .createHash('sha256')
      .update(token)
      .digest('hex');
  }

  private normalizeUsername(value?: string) {
    if (!value) return null;
    const cleaned = value.trim().toLowerCase();
    if (cleaned.length < 3 || cleaned.length > 32) return null;
    if (!/^[a-z0-9_]+$/.test(cleaned)) return null;
    return cleaned;
  }
}
