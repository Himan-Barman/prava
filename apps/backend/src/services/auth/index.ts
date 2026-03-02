import { getDb } from "../../lib/mongo.js";
import { env } from "../../config/env.js";
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
import { requireAuth } from "../../lib/auth.js";
import { sendOtpEmail } from "../../lib/email.js";

function addSeconds(date, seconds) {
  return new Date(date.getTime() + seconds * 1000);
}

function addMinutes(date, minutes) {
  return new Date(date.getTime() + minutes * 60 * 1000);
}

function sanitizeDevice(value) {
  return String(value || "").trim().slice(0, 128);
}

async function ensureRecentEmailOtp(db, emailLower) {
  const token = await db.collection("email_otp_tokens").findOne(
    {
      emailLower,
      usedAt: { $ne: null },
    },
    {
      sort: { usedAt: -1 },
      projection: { usedAt: 1 },
    }
  );

  if (!token || !token.usedAt) {
    throw new HttpError(401, "Email verification required");
  }

  const minAccepted = addMinutes(now(), -15);
  if (new Date(token.usedAt).getTime() < minAccepted.getTime()) {
    throw new HttpError(401, "Email verification required");
  }
}

async function createSession(db, user, context) {
  const issuedAt = now();
  const refreshToken = generateRefreshToken();
  const expiresAt = addSeconds(issuedAt, getRefreshTtlSeconds());

  await db.collection("refresh_tokens").insertOne({
    refreshTokenId: generateId(),
    userId: user.userId,
    deviceId: sanitizeDevice(context.deviceId),
    deviceName: sanitizeDevice(context.deviceName),
    platform: sanitizeDevice(context.platform),
    tokenHash: refreshToken.hash,
    createdAt: issuedAt,
    lastSeenAt: issuedAt,
    expiresAt,
    revokedAt: null,
  });

  return {
    accessToken: issueAccessToken(user),
    refreshToken: refreshToken.raw,
  };
}

async function loadUserForLogin(db, identifierLower) {
  if (identifierLower.includes("@")) {
    return db.collection("users").findOne({ emailLower: identifierLower });
  }
  return db.collection("users").findOne({ usernameLower: identifierLower });
}

function isDuplicateKeyError(error: unknown): boolean {
  return (
    typeof error === "object"
    && error !== null
    && "code" in error
    && (error as { code?: number }).code === 11000
  );
}

async function reserveSignupUsername(db, emailLower, usernameLower, ts) {
  const existingUser = await db.collection("users").findOne(
    { usernameLower },
    { projection: { userId: 1 } }
  );
  if (existingUser) {
    throw new HttpError(409, "Username already exists");
  }

  const expiresAt = addMinutes(ts, env.USERNAME_RESERVATION_MINUTES);

  try {
    await db.collection("username_reservations").updateOne(
      {
        usernameLower,
        $or: [
          { emailLower },
          { expiresAt: { $lte: ts } },
        ],
      },
      {
        $set: {
          usernameLower,
          emailLower,
          purpose: "signup",
          updatedAt: ts,
          expiresAt,
        },
        $setOnInsert: {
          createdAt: ts,
        },
      },
      { upsert: true }
    );
  } catch (error) {
    if (isDuplicateKeyError(error)) {
      throw new HttpError(409, "Username is temporarily reserved");
    }
    throw error;
  }

  return expiresAt;
}

async function ensureUsernameReservedForSignup(db, emailLower, usernameLower, ts) {
  const existingUser = await db.collection("users").findOne(
    { usernameLower },
    { projection: { userId: 1 } }
  );
  if (existingUser) {
    throw new HttpError(409, "Username already exists");
  }

  const reservation = await db.collection("username_reservations").findOne(
    { usernameLower },
    {
      projection: {
        emailLower: 1,
        expiresAt: 1,
      },
    }
  );

  if (!reservation || !reservation.expiresAt) {
    throw new HttpError(409, "Username reservation expired. Request a new verification code.");
  }

  const expiresAt = new Date(reservation.expiresAt);
  if (Number.isNaN(expiresAt.getTime()) || expiresAt.getTime() <= ts.getTime()) {
    throw new HttpError(409, "Username reservation expired. Request a new verification code.");
  }

  if (reservation.emailLower !== emailLower) {
    throw new HttpError(409, "Username is temporarily reserved");
  }
}

export default async function authService(app) {
  const db = getDb();

  app.post("/register", async (request) => {
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

    await ensureRecentEmailOtp(db, emailLower);

    const ts = now();
    if (hasExplicitUsername) {
      await ensureUsernameReservedForSignup(db, emailLower, usernameLower, ts);
    }

    const existing = await db.collection("users").findOne({
      $or: [{ emailLower }, { usernameLower }],
    });
    if (existing) {
      if (existing.emailLower === emailLower) {
        throw new HttpError(409, "Email already exists");
      }
      throw new HttpError(409, "Username already exists");
    }

    const user = {
      userId: generateId(),
      email: emailLower,
      emailLower,
      username: usernameLower,
      usernameLower,
      displayName: usernameLower,
      displayNameLower: usernameLower,
      passwordHash: hashPassword(body.password),
      isVerified: true,
      emailVerifiedAt: ts,
      details: null,
      createdAt: ts,
      updatedAt: ts,
    };

    await db.collection("users").insertOne(user);
    if (hasExplicitUsername) {
      await db.collection("username_reservations").deleteOne({
        usernameLower,
        emailLower,
      });
    }

    const session = await createSession(db, user, {
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

  app.post("/login", async (request) => {
    const body = request.body || {};
    const identifier = normalizeEmail(body.email || body.username);
    ensure(identifier.length >= 3 && identifier.length <= 255, 400, "Invalid request");
    ensure(isValidPassword(body.password), 400, "Invalid request");

    const user = await loadUserForLogin(db, identifier);
    if (!user || !verifyPassword(body.password, user.passwordHash)) {
      throw new HttpError(401, "Invalid credentials");
    }

    const session = await createSession(db, user, {
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

  app.post("/refresh", async (request) => {
    const body = request.body || {};
    const rawToken = String(body.refreshToken || "").trim();
    const deviceId = sanitizeDevice(body.deviceId);
    ensure(rawToken.length >= 16, 400, "Invalid request");
    ensure(deviceId.length >= 3, 400, "Invalid request");

    const tokenHash = sha256(rawToken);
    const ts = now();
    const tokenDoc = await db.collection("refresh_tokens").findOne({
      tokenHash,
      deviceId,
      revokedAt: null,
      expiresAt: { $gt: ts },
    });

    if (!tokenDoc) {
      throw new HttpError(401, "Invalid refresh token");
    }

    await db.collection("refresh_tokens").updateOne(
      { _id: tokenDoc._id },
      { $set: { revokedAt: ts } }
    );

    const user = await db.collection("users").findOne({ userId: tokenDoc.userId });
    if (!user) {
      throw new HttpError(401, "Invalid refresh token");
    }

    const session = await createSession(db, user, {
      deviceId,
      deviceName: tokenDoc.deviceName,
      platform: tokenDoc.platform,
    });

    return {
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    };
  });

  app.post("/logout", { preHandler: requireAuth }, async (request) => {
    const body = request.body || {};
    const deviceId = sanitizeDevice(body.deviceId);
    const filter: { userId: string; revokedAt: null; deviceId?: string } = {
      userId: request.user.userId,
      revokedAt: null,
    };
    if (deviceId) {
      filter.deviceId = deviceId;
    }

    await db.collection("refresh_tokens").updateMany(filter, {
      $set: { revokedAt: now() },
    });

    return { success: true };
  });

  app.post("/logout-all", { preHandler: requireAuth }, async (request) => {
    await db.collection("refresh_tokens").updateMany(
      {
        userId: request.user.userId,
        revokedAt: null,
      },
      {
        $set: { revokedAt: now() },
      }
    );

    return { success: true };
  });

  app.post("/sessions", { preHandler: requireAuth }, async (request) => {
    const sessions = await db.collection("refresh_tokens").find(
      {
        userId: request.user.userId,
        revokedAt: null,
        expiresAt: { $gt: now() },
      },
      {
        sort: { createdAt: 1 },
      }
    ).toArray();

    return sessions.map((session) => ({
      id: session.refreshTokenId,
      deviceId: session.deviceId,
      deviceName: session.deviceName || "",
      platform: session.platform || "",
      createdAt: session.createdAt?.toISOString?.() || null,
      lastSeenAt: session.lastSeenAt?.toISOString?.() || null,
      expiresAt: session.expiresAt?.toISOString?.() || null,
    }));
  });

  app.post("/sessions/revoke", { preHandler: requireAuth }, async (request) => {
    const deviceId = sanitizeDevice(request.body?.deviceId);
    ensure(deviceId.length >= 3, 400, "Invalid request");

    await db.collection("refresh_tokens").updateMany(
      {
        userId: request.user.userId,
        deviceId,
        revokedAt: null,
      },
      {
        $set: { revokedAt: now() },
      }
    );

    return { success: true };
  });

  app.post("/sessions/revoke-others", { preHandler: requireAuth }, async (request) => {
    const currentDeviceId = sanitizeDevice(request.body?.currentDeviceId);
    ensure(currentDeviceId.length >= 3, 400, "Invalid request");

    await db.collection("refresh_tokens").updateMany(
      {
        userId: request.user.userId,
        revokedAt: null,
        deviceId: { $ne: currentDeviceId },
      },
      {
        $set: { revokedAt: now() },
      }
    );

    return { success: true };
  });

  app.post("/email-otp/request", async (request) => {
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
      await reserveSignupUsername(db, emailLower, usernameLower, ts);
    }

    await db.collection("email_otp_tokens").updateMany(
      {
        emailLower,
        usedAt: null,
        expiresAt: { $gt: ts },
      },
      {
        $set: { usedAt: ts },
      }
    );

    const code = generateOtpCode();
    await db.collection("email_otp_tokens").insertOne({
      emailLower,
      tokenHash: sha256(code),
      attempts: 0,
      createdAt: ts,
      expiresAt: addMinutes(ts, env.OTP_EXPIRES_MINUTES),
      usedAt: null,
    });

    try {
      await sendOtpEmail({
        to: emailLower,
        code,
        type: "verification",
      });
    } catch (error) {
      if (hasUsername) {
        await db.collection("username_reservations").deleteOne({
          usernameLower,
          emailLower,
        });
      }
      request.log.error({ err: error, emailLower }, "failed to deliver email verification otp");
      throw new HttpError(503, "Unable to send verification code");
    }

    const payload: {
      success: boolean;
      expiresIn: number;
      reservationExpiresIn?: number;
      devCode?: string;
    } = {
      success: true,
      expiresIn: env.OTP_EXPIRES_MINUTES * 60,
      ...(hasUsername ? { reservationExpiresIn: env.USERNAME_RESERVATION_MINUTES * 60 } : {}),
    };
    if ((process.env.NODE_ENV || "development") !== "production") {
      payload.devCode = code;
    }
    return payload;
  });

  app.post("/email-otp/verify", async (request) => {
    const body = request.body || {};
    const emailLower = normalizeEmail(body.email);
    const code = String(body.code || "").trim();

    ensure(isValidEmail(emailLower), 400, "Invalid request");
    ensure(/^\d{6}$/.test(code), 400, "Invalid request");

    const ts = now();
    const otp = await db.collection("email_otp_tokens").findOne(
      {
        emailLower,
        usedAt: null,
        expiresAt: { $gt: ts },
      },
      {
        sort: { createdAt: -1 },
      }
    );

    if (!otp) {
      throw new HttpError(401, "Invalid or expired code");
    }

    const currentAttempts = Number(otp.attempts || 0);
    if (currentAttempts >= 5) {
      await db.collection("email_otp_tokens").updateOne(
        { _id: otp._id },
        { $set: { usedAt: ts } }
      );
      throw new HttpError(401, "Invalid or expired code");
    }

    if (sha256(code) !== otp.tokenHash) {
      const nextAttempts = currentAttempts + 1;
      await db.collection("email_otp_tokens").updateOne(
        { _id: otp._id },
        {
          $set: {
            attempts: nextAttempts,
            usedAt: nextAttempts >= 5 ? ts : null,
          },
        }
      );
      throw new HttpError(401, "Invalid or expired code");
    }

    await db.collection("email_otp_tokens").updateOne(
      { _id: otp._id },
      { $set: { usedAt: ts } }
    );

    await db.collection("users").updateOne(
      {
        emailLower,
        isVerified: false,
      },
      {
        $set: {
          isVerified: true,
          emailVerifiedAt: ts,
          updatedAt: ts,
        },
      }
    );

    return { verified: true };
  });

  app.post("/password-reset/request", async (request) => {
    const body = request.body || {};
    const emailLower = normalizeEmail(body.email);
    ensure(isValidEmail(emailLower), 400, "Invalid email");

    const user = await db.collection("users").findOne({ emailLower });
    if (!user) {
      return { success: true };
    }

    const ts = now();
    await db.collection("password_reset_tokens").updateMany(
      {
        userId: user.userId,
        usedAt: null,
        expiresAt: { $gt: ts },
      },
      { $set: { usedAt: ts } }
    );

    const code = generateOtpCode();
    await db.collection("password_reset_tokens").insertOne({
      resetTokenId: generateId(),
      userId: user.userId,
      emailLower,
      tokenHash: sha256(code),
      createdAt: ts,
      expiresAt: addMinutes(ts, env.OTP_EXPIRES_MINUTES),
      usedAt: null,
    });

    try {
      await sendOtpEmail({
        to: emailLower,
        code,
        type: "password-reset",
      });
    } catch (error) {
      request.log.error({ err: error, userId: user.userId }, "failed to deliver password reset otp");
      throw new HttpError(503, "Unable to send reset code");
    }

    const payload: { success: boolean; devToken?: string } = { success: true };
    if ((process.env.NODE_ENV || "development") !== "production") {
      payload.devToken = code;
    }
    return payload;
  });

  app.post("/password-reset/confirm", async (request) => {
    const body = request.body || {};
    const token = String(body.token || "").trim();
    const newPassword = String(body.newPassword || "");
    ensure(/^\d{6}$/.test(token), 400, "Invalid request");
    ensure(isValidPassword(newPassword), 400, "Invalid request");

    const tokenHash = sha256(token);
    const ts = now();
    const resetToken = await db.collection("password_reset_tokens").findOne({
      tokenHash,
      usedAt: null,
      expiresAt: { $gt: ts },
    });

    if (!resetToken) {
      throw new HttpError(401, "Invalid or expired code");
    }

    await db.collection("password_reset_tokens").updateOne(
      { _id: resetToken._id },
      { $set: { usedAt: ts } }
    );

    await db.collection("users").updateOne(
      { userId: resetToken.userId },
      {
        $set: {
          passwordHash: hashPassword(newPassword),
          updatedAt: ts,
        },
      }
    );

    await db.collection("refresh_tokens").updateMany(
      {
        userId: resetToken.userId,
        revokedAt: null,
      },
      {
        $set: { revokedAt: ts },
      }
    );

    return { success: true };
  });
}
