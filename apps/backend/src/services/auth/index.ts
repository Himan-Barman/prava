import { env } from "../../config/env.js";
import { requireAuth } from "../../lib/auth.js";
import { sendOtpEmail } from "../../lib/email.js";
import { query, queryMany, queryOne, withTransaction } from "../../lib/pg.js";
import {
  HttpError,
  buildUserView,
  ensure,
  generateId,
  generateOtpCode,
  generateRefreshToken,
  getRefreshTtlSeconds,
  hashPassword,
  isValidEmail,
  isValidPassword,
  isValidUsername,
  issueAccessToken,
  normalizeEmail,
  normalizeUsername,
  now,
  sha256,
  verifyPassword,
} from "../../lib/security.js";

function addSeconds(date: Date, seconds: number): Date {
  return new Date(date.getTime() + seconds * 1000);
}

function addMinutes(date: Date, minutes: number): Date {
  return new Date(date.getTime() + minutes * 60 * 1000);
}

function sanitizeDevice(value: unknown): string {
  return String(value || "").trim().slice(0, 128);
}

async function ensureRecentEmailOtp(emailLower: string): Promise<void> {
  const token = await queryOne(
    `SELECT used_at FROM email_otp_tokens
     WHERE email_lower = $1 AND used_at IS NOT NULL
     ORDER BY used_at DESC LIMIT 1`,
    [emailLower]
  );

  if (!token || !token.used_at) {
    throw new HttpError(401, "Email verification required");
  }

  const minAccepted = addMinutes(now(), -15);
  if (new Date(token.used_at).getTime() < minAccepted.getTime()) {
    throw new HttpError(401, "Email verification required");
  }
}

async function ensureMobileUserDatabaseRows(userId: string, passwordHash?: string): Promise<string | null> {
  const existing = await queryOne(`SELECT * FROM users WHERE user_id = $1`, [userId]);
  if (!existing) {
    return null;
  }

  let userUuid = existing.id ? String(existing.id) : generateId();
  const settings = {
    pushNotifications: true,
    emailNotifications: true,
    sound: true,
    haptics: true,
    languageCode: existing.language_code || "en",
  };

  await withTransaction(async (client) => {
    if (!existing.id) {
      const updated = await client.query(
        `UPDATE users
         SET id = $2
         WHERE user_id = $1 AND id IS NULL
         RETURNING id::text AS id`,
        [userId, userUuid]
      );
      userUuid = String(updated.rows[0]?.id || userUuid);
    }

    await client.query(
      `UPDATE users
       SET handle = COALESCE(handle, username),
           handle_normalized = COALESCE(handle_normalized, username_lower),
           account_status = COALESCE(account_status, 'active'),
           language_code = COALESCE(language_code, 'en')
       WHERE user_id = $1`,
      [userId]
    );

    await client.query(
      `INSERT INTO user_settings (user_id, settings, updated_at)
       VALUES ($1, $2, NOW())
       ON CONFLICT (user_id)
       DO UPDATE SET settings = COALESCE(user_settings.settings, '{}'::jsonb) || EXCLUDED.settings,
                     updated_at = EXCLUDED.updated_at`,
      [userId, JSON.stringify(settings)]
    );

    await client.query(
      `INSERT INTO user_profiles (user_id, profile_metadata, created_at, updated_at)
       VALUES ($1, '{}'::jsonb, NOW(), NOW())
       ON CONFLICT (user_id) DO NOTHING`,
      [userUuid]
    );

    await client.query(
      `INSERT INTO user_stats (user_id, updated_at)
       VALUES ($1, NOW())
       ON CONFLICT (user_id) DO NOTHING`,
      [userUuid]
    );

    await client.query(
      `INSERT INTO user_privacy_settings (user_id, updated_at)
       VALUES ($1, NOW())
       ON CONFLICT (user_id) DO NOTHING`,
      [userUuid]
    );

    if (existing.email_lower) {
      const emailRow = await client.query(
        `SELECT id
         FROM user_emails
         WHERE email_normalized = $1 AND deleted_at IS NULL
         LIMIT 1`,
        [existing.email_lower]
      );
      if ((emailRow.rowCount || 0) > 0) {
        await client.query(
          `UPDATE user_emails
           SET user_id = $2,
               is_primary = TRUE,
               is_verified = is_verified OR $3,
               verified_at = CASE WHEN $3 THEN COALESCE(verified_at, NOW()) ELSE verified_at END,
               updated_at = NOW()
           WHERE id = $1`,
          [emailRow.rows[0]?.id, userUuid, existing.is_verified === true]
        );
      } else {
        await client.query(
          `INSERT INTO user_emails (
             id, user_id, email, email_normalized, is_primary, is_verified, verified_at, created_at, updated_at
           )
           VALUES ($1, $2, $3, $3, TRUE, $4, CASE WHEN $4 THEN NOW() ELSE NULL END, NOW(), NOW())`,
          [generateId(), userUuid, existing.email_lower, existing.is_verified === true]
        );
      }
    }

    const effectiveHash = passwordHash || existing.password_hash;
    if (effectiveHash) {
      await client.query(
        `INSERT INTO user_credentials (
           user_id, password_hash, password_algo, password_algorithm,
           password_updated_at, password_changed_at, created_at, updated_at
         )
         VALUES ($1, $2, 'argon2id', 'argon2id', NOW(), NOW(), NOW(), NOW())
         ON CONFLICT (user_id)
         DO UPDATE SET password_hash = EXCLUDED.password_hash,
                       password_algo = EXCLUDED.password_algo,
                       password_algorithm = EXCLUDED.password_algorithm,
                       password_updated_at = EXCLUDED.password_updated_at,
                       password_changed_at = EXCLUDED.password_changed_at,
                       updated_at = EXCLUDED.updated_at`,
        [userUuid, effectiveHash]
      );
    }
  });

  return userUuid;
}

async function createSession(user: any, context: { deviceId?: string; deviceName?: string; platform?: string }) {
  const issuedAt = now();
  const refreshToken = generateRefreshToken();
  const expiresAt = addSeconds(issuedAt, getRefreshTtlSeconds());
  const accessToken = issueAccessToken(user);
  let nextRefreshToken = "";

  try {
    await query(
      `INSERT INTO refresh_tokens (refresh_token_id, user_id, device_id, device_name, platform, token_hash, created_at, last_seen_at, expires_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
      [
        generateId(),
        user.userId || user.user_id,
        sanitizeDevice(context.deviceId),
        sanitizeDevice(context.deviceName),
        sanitizeDevice(context.platform),
        refreshToken.hash,
        issuedAt,
        issuedAt,
        expiresAt,
      ]
    );
    nextRefreshToken = refreshToken.raw;
  } catch {
    // Best-effort session creation
  }

  return {
    accessToken,
    refreshToken: nextRefreshToken,
  };
}

function mapUser(row: any) {
  return {
    userId: row.user_id,
    email: row.email,
    username: row.username,
    displayName: row.display_name || row.username,
    isVerified: row.is_verified,
    passwordHash: row.password_hash,
  };
}

export default async function authService(app: any) {
  app.post("/register", async (request: any) => {
    const body = request.body || {};
    const emailLower = normalizeEmail(body.email);
    ensure(isValidEmail(emailLower), 400, "Invalid email");
    ensure(isValidPassword(body.password), 400, "Invalid password");

    const requestedUsername = normalizeUsername(body.username);
    const hasExplicitUsername = requestedUsername.length > 0;

    let usernameLower = requestedUsername;
    if (!usernameLower) {
      usernameLower = normalizeUsername(emailLower.split("@")[0]);
    }
    ensure(isValidUsername(usernameLower), 400, "Invalid username");

    await ensureRecentEmailOtp(emailLower);

    const ts = now();

    if (hasExplicitUsername) {
      // Check if username is taken
      const existing = await queryOne(
        `SELECT user_id FROM users WHERE username_lower = $1`,
        [usernameLower]
      );
      if (existing) {
        throw new HttpError(409, "Username already exists");
      }

      // Check reservations
      const reservation = await queryOne(
        `SELECT email_lower FROM username_reservations WHERE username_lower = $1 AND expires_at > $2`,
        [usernameLower, ts]
      );
      if (reservation && reservation.email_lower !== emailLower) {
        throw new HttpError(409, "Username is temporarily reserved");
      }
    }

    // Check existing user
    const existingUser = await queryOne(
      `SELECT user_id, email_lower, username_lower FROM users WHERE email_lower = $1 OR username_lower = $2 LIMIT 1`,
      [emailLower, usernameLower]
    );
    if (existingUser) {
      if (existingUser.email_lower === emailLower) {
        throw new HttpError(409, "Email already exists");
      }
      throw new HttpError(409, "Username already exists");
    }

    const userId = generateId();
    const passwordHash = hashPassword(body.password);
    try {
      await query(
        `INSERT INTO users (user_id, email, email_lower, username, username_lower, display_name, display_name_lower, password_hash, is_verified, email_verified_at, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
        [userId, emailLower, emailLower, usernameLower, usernameLower, usernameLower, usernameLower, passwordHash, true, ts, ts, ts]
      );
    } catch (error: any) {
      if (error.code === "23505") {
        if (error.constraint?.includes("email")) {
          throw new HttpError(409, "Email already exists");
        }
        if (error.constraint?.includes("username")) {
          throw new HttpError(409, "Username already exists");
        }
        throw new HttpError(409, "Account already exists");
      }
      throw error;
    }

    if (hasExplicitUsername) {
      await query(
        `DELETE FROM username_reservations WHERE username_lower = $1 AND email_lower = $2`,
        [usernameLower, emailLower]
      );
    }

    await ensureMobileUserDatabaseRows(userId, passwordHash);

    const user = { userId, email: emailLower, username: usernameLower, displayName: usernameLower, isVerified: true };

    let session;
    try {
      session = await createSession(user, {
        deviceId: body.deviceId,
        deviceName: body.deviceName,
        platform: body.platform,
      });
    } catch (error) {
      request.log.error({ err: error, emailLower }, "failed to create signup session");
      throw new HttpError(503, "Account created. Please sign in.");
    }

    return {
      user: buildUserView(user),
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    };
  });

  app.post("/login", async (request: any) => {
    const body = request.body || {};
    const identifier = normalizeEmail(body.email || body.username);
    ensure(identifier.length >= 3 && identifier.length <= 255, 400, "Invalid request");
    ensure(isValidPassword(body.password), 400, "Invalid request");

    let row;
    if (identifier.includes("@")) {
      row = await queryOne(`SELECT * FROM users WHERE email_lower = $1`, [identifier]);
    } else {
      row = await queryOne(`SELECT * FROM users WHERE username_lower = $1`, [identifier]);
    }

    if (!row || !verifyPassword(body.password, row.password_hash)) {
      throw new HttpError(401, "Invalid credentials");
    }

    await ensureMobileUserDatabaseRows(row.user_id, row.password_hash);

    const user = mapUser(row);
    const session = await createSession(user, {
      deviceId: body.deviceId,
      deviceName: body.deviceName,
      platform: body.platform,
    });

    return {
      user: buildUserView(user),
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    };
  });

  app.post("/refresh", async (request: any) => {
    const body = request.body || {};
    const rawToken = String(body.refreshToken || "").trim();
    const deviceId = sanitizeDevice(body.deviceId);
    ensure(rawToken.length >= 16, 400, "Invalid request");
    ensure(deviceId.length >= 3, 400, "Invalid request");

    const tokenHash = sha256(rawToken);
    const ts = now();

    const tokenDoc = await queryOne(
      `SELECT * FROM refresh_tokens WHERE token_hash = $1 AND device_id = $2 AND revoked_at IS NULL AND expires_at > $3`,
      [tokenHash, deviceId, ts]
    );

    if (!tokenDoc) {
      throw new HttpError(401, "Invalid refresh token");
    }

    await query(
      `UPDATE refresh_tokens SET revoked_at = $1 WHERE id = $2`,
      [ts, tokenDoc.id]
    );

    const userRow = await queryOne(`SELECT * FROM users WHERE user_id = $1`, [tokenDoc.user_id]);
    if (!userRow) {
      throw new HttpError(401, "Invalid refresh token");
    }

    const user = mapUser(userRow);
    const session = await createSession(user, {
      deviceId,
      deviceName: tokenDoc.device_name,
      platform: tokenDoc.platform,
    });

    return {
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    };
  });

  app.post("/logout", { preHandler: requireAuth }, async (request: any) => {
    const body = request.body || {};
    const deviceId = sanitizeDevice(body.deviceId);

    if (deviceId) {
      await query(
        `UPDATE refresh_tokens SET revoked_at = $1 WHERE user_id = $2 AND revoked_at IS NULL AND device_id = $3`,
        [now(), request.user.userId, deviceId]
      );
    } else {
      await query(
        `UPDATE refresh_tokens SET revoked_at = $1 WHERE user_id = $2 AND revoked_at IS NULL`,
        [now(), request.user.userId]
      );
    }

    return { success: true };
  });

  app.post("/logout-all", { preHandler: requireAuth }, async (request: any) => {
    await query(
      `UPDATE refresh_tokens SET revoked_at = $1 WHERE user_id = $2 AND revoked_at IS NULL`,
      [now(), request.user.userId]
    );
    return { success: true };
  });

  app.post("/sessions", { preHandler: requireAuth }, async (request: any) => {
    const sessions = await queryMany(
      `SELECT refresh_token_id, device_id, device_name, platform, created_at, last_seen_at, expires_at
       FROM refresh_tokens
       WHERE user_id = $1 AND revoked_at IS NULL AND expires_at > $2
       ORDER BY created_at ASC`,
      [request.user.userId, now()]
    );

    return sessions.map((s: any) => ({
      id: s.refresh_token_id,
      deviceId: s.device_id,
      deviceName: s.device_name || "",
      platform: s.platform || "",
      createdAt: s.created_at?.toISOString() || null,
      lastSeenAt: s.last_seen_at?.toISOString() || null,
      expiresAt: s.expires_at?.toISOString() || null,
    }));
  });

  app.post("/sessions/revoke", { preHandler: requireAuth }, async (request: any) => {
    const deviceId = sanitizeDevice(request.body?.deviceId);
    ensure(deviceId.length >= 3, 400, "Invalid request");

    await query(
      `UPDATE refresh_tokens SET revoked_at = $1 WHERE user_id = $2 AND device_id = $3 AND revoked_at IS NULL`,
      [now(), request.user.userId, deviceId]
    );

    return { success: true };
  });

  app.post("/sessions/revoke-others", { preHandler: requireAuth }, async (request: any) => {
    const currentDeviceId = sanitizeDevice(request.body?.currentDeviceId);
    ensure(currentDeviceId.length >= 3, 400, "Invalid request");

    await query(
      `UPDATE refresh_tokens SET revoked_at = $1 WHERE user_id = $2 AND revoked_at IS NULL AND device_id != $3`,
      [now(), request.user.userId, currentDeviceId]
    );

    return { success: true };
  });

  app.post("/email-otp/request", async (request: any) => {
    const body = request.body || {};
    const emailLower = normalizeEmail(body.email);
    ensure(isValidEmail(emailLower), 400, "Invalid email");

    const ts = now();
    const usernameLower = normalizeUsername(body.username);
    const hasUsername = usernameLower.length > 0;
    if (body.username !== undefined) {
      ensure(isValidUsername(usernameLower), 400, "Invalid username");
    }

    if (hasUsername) {
      // Reserve username
      const existingUser = await queryOne(
        `SELECT user_id FROM users WHERE username_lower = $1`,
        [usernameLower]
      );
      if (existingUser) {
        throw new HttpError(409, "Username already exists");
      }

      const activeReservation = await queryOne(
        `SELECT email_lower
         FROM username_reservations
         WHERE username_lower = $1 AND expires_at > $2`,
        [usernameLower, ts]
      );
      if (activeReservation && activeReservation.email_lower !== emailLower) {
        throw new HttpError(409, "Username is temporarily reserved");
      }

      const expiresAt = addMinutes(ts, env.USERNAME_RESERVATION_MINUTES);
      try {
        const reservationResult = await query(
          `INSERT INTO username_reservations (username_lower, email_lower, purpose, created_at, updated_at, expires_at)
           VALUES ($1, $2, 'signup', $3, $4, $5)
           ON CONFLICT (username_lower)
           DO UPDATE SET email_lower = $2, updated_at = $4, expires_at = $5
           WHERE username_reservations.email_lower = $2 OR username_reservations.expires_at <= $3`,
          [usernameLower, emailLower, ts, ts, expiresAt]
        );
        if ((reservationResult.rowCount || 0) === 0) {
          throw new HttpError(409, "Username is temporarily reserved");
        }
      } catch (error: any) {
        if (error instanceof HttpError) {
          throw error;
        }
        if (error.code === "23505") {
          throw new HttpError(409, "Username is temporarily reserved");
        }
        throw error;
      }
    }

    // Invalidate previous OTPs
    await query(
      `UPDATE email_otp_tokens SET used_at = $1 WHERE email_lower = $2 AND used_at IS NULL AND expires_at > $3`,
      [ts, emailLower, ts]
    );

    const code = generateOtpCode();
    await query(
      `INSERT INTO email_otp_tokens (email_lower, token_hash, attempts, created_at, expires_at)
       VALUES ($1, $2, 0, $3, $4)`,
      [emailLower, sha256(code), ts, addMinutes(ts, env.OTP_EXPIRES_MINUTES)]
    );

    try {
      await sendOtpEmail({ to: emailLower, code, type: "verification" });
    } catch (error) {
      if (hasUsername) {
        await query(
          `DELETE FROM username_reservations WHERE username_lower = $1 AND email_lower = $2`,
          [usernameLower, emailLower]
        );
      }
      request.log.error({ err: error, emailLower }, "failed to deliver email verification otp");
      throw new HttpError(503, "Unable to send verification code");
    }

    const payload: any = {
      success: true,
      expiresIn: env.OTP_EXPIRES_MINUTES * 60,
      ...(hasUsername ? { reservationExpiresIn: env.USERNAME_RESERVATION_MINUTES * 60 } : {}),
    };
    if ((process.env.NODE_ENV || "development") !== "production") {
      payload.devCode = code;
    }
    return payload;
  });

  app.post("/email-otp/verify", async (request: any) => {
    const body = request.body || {};
    const emailLower = normalizeEmail(body.email);
    const code = String(body.code || "").trim();

    ensure(isValidEmail(emailLower), 400, "Invalid request");
    ensure(/^\d{6}$/.test(code), 400, "Invalid request");

    const ts = now();
    const otp = await queryOne(
      `SELECT id, token_hash, attempts FROM email_otp_tokens
       WHERE email_lower = $1 AND used_at IS NULL AND expires_at > $2
       ORDER BY created_at DESC LIMIT 1`,
      [emailLower, ts]
    );

    if (!otp) {
      throw new HttpError(401, "Invalid or expired code");
    }

    const currentAttempts = Number(otp.attempts || 0);
    if (currentAttempts >= 5) {
      await query(`UPDATE email_otp_tokens SET used_at = $1 WHERE id = $2`, [ts, otp.id]);
      throw new HttpError(401, "Invalid or expired code");
    }

    if (sha256(code) !== otp.token_hash) {
      const nextAttempts = currentAttempts + 1;
      await query(
        `UPDATE email_otp_tokens SET attempts = $1, used_at = $2 WHERE id = $3`,
        [nextAttempts, nextAttempts >= 5 ? ts : null, otp.id]
      );
      throw new HttpError(401, "Invalid or expired code");
    }

    await query(`UPDATE email_otp_tokens SET used_at = $1 WHERE id = $2`, [ts, otp.id]);

    await query(
      `UPDATE users SET is_verified = TRUE, email_verified_at = $1, updated_at = $2
       WHERE email_lower = $3 AND is_verified = FALSE`,
      [ts, ts, emailLower]
    );
    const verifiedUser = await queryOne(`SELECT user_id, password_hash FROM users WHERE email_lower = $1`, [emailLower]);
    if (verifiedUser) {
      await ensureMobileUserDatabaseRows(verifiedUser.user_id, verifiedUser.password_hash);
    }

    return { verified: true };
  });

  app.post("/password-reset/request", async (request: any) => {
    const body = request.body || {};
    const emailLower = normalizeEmail(body.email);
    ensure(isValidEmail(emailLower), 400, "Invalid email");

    const user = await queryOne(`SELECT user_id FROM users WHERE email_lower = $1`, [emailLower]);
    if (!user) {
      return { success: true };
    }

    const ts = now();
    await query(
      `UPDATE password_reset_tokens SET used_at = $1 WHERE user_id = $2 AND used_at IS NULL AND expires_at > $3`,
      [ts, user.user_id, ts]
    );

    const code = generateOtpCode();
    await query(
      `INSERT INTO password_reset_tokens (reset_token_id, user_id, email_lower, token_hash, created_at, expires_at)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [generateId(), user.user_id, emailLower, sha256(code), ts, addMinutes(ts, env.OTP_EXPIRES_MINUTES)]
    );

    try {
      await sendOtpEmail({ to: emailLower, code, type: "password-reset" });
    } catch (error) {
      request.log.error({ err: error, userId: user.user_id }, "failed to deliver password reset otp");
      throw new HttpError(503, "Unable to send reset code");
    }

    const payload: any = { success: true };
    if ((process.env.NODE_ENV || "development") !== "production") {
      payload.devToken = code;
    }
    return payload;
  });

  app.post("/password-reset/confirm", async (request: any) => {
    const body = request.body || {};
    const token = String(body.token || "").trim();
    const newPassword = String(body.newPassword || "");
    ensure(/^\d{6}$/.test(token), 400, "Invalid request");
    ensure(isValidPassword(newPassword), 400, "Invalid request");

    const tokenHash = sha256(token);
    const ts = now();

    const resetToken = await queryOne(
      `SELECT id, user_id FROM password_reset_tokens WHERE token_hash = $1 AND used_at IS NULL AND expires_at > $2`,
      [tokenHash, ts]
    );

    if (!resetToken) {
      throw new HttpError(401, "Invalid or expired code");
    }

    await query(`UPDATE password_reset_tokens SET used_at = $1 WHERE id = $2`, [ts, resetToken.id]);
    const nextPasswordHash = hashPassword(newPassword);
    await query(
      `UPDATE users SET password_hash = $1, updated_at = $2 WHERE user_id = $3`,
      [nextPasswordHash, ts, resetToken.user_id]
    );
    await ensureMobileUserDatabaseRows(resetToken.user_id, nextPasswordHash);
    await query(
      `UPDATE refresh_tokens SET revoked_at = $1 WHERE user_id = $2 AND revoked_at IS NULL`,
      [ts, resetToken.user_id]
    );

    return { success: true };
  });
}
