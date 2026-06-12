import assert from "node:assert/strict";
import test, { after, before } from "node:test";

import Fastify from "fastify";
import { newDb } from "pg-mem";

let app: ReturnType<typeof Fastify>;
let closePg: (() => Promise<void>) | null = null;

async function injectPost<T = any>(
  path: string,
  body: unknown,
  token?: string
): Promise<{ status: number; data: T }> {
  const response = await app.inject({
    method: "POST",
    url: path,
    headers: {
      "content-type": "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    payload: JSON.stringify(body),
  });
  return {
    status: response.statusCode,
    data: response.json() as T,
  };
}

before(async () => {
  process.env.NODE_ENV = "test";
  process.env.JWT_SECRET = process.env.JWT_SECRET || "test_jwt_secret_key";
  process.env.DATABASE_URL =
    process.env.DATABASE_URL || "postgresql://postgres:postgres@127.0.0.1:5432/prava_test";

  const pgLib = await import("../src/lib/pg.js");
  const memoryDb = newDb({ autoCreateForeignKeyIndices: true });
  const adapter = memoryDb.adapters.createPg();
  const pool = new adapter.Pool();
  pgLib.setPgPoolForTest(pool as any);
  await pgLib.runMigrations(pool as any);
  closePg = pgLib.closePg;

  const authService = (await import("../src/services/auth/index.js")).default;
  app = Fastify({ logger: false });
  app.setErrorHandler((error: any, _request, reply) => {
    reply.code(error.statusCode || 500).send({ message: error.message });
  });
  app.register(authService, { prefix: "/api/auth" });
  await app.ready();
});

after(async () => {
  await app?.close().catch(() => undefined);
  if (closePg) {
    await closePg();
  }
});

test("legacy mobile auth completes otp signup, login, and password reset", async () => {
  const stamp = String(Date.now());
  const username = `legacy${stamp.padEnd(26, "x")}`.slice(0, 32);
  const email = `${username}@example.com`;
  const password = "StrongPassword123!";
  const nextPassword = "NewStrongPassword123!";

  const otp = await injectPost<{ devCode: string }>("/api/auth/email-otp/request", {
    email,
    username,
  });
  assert.equal(otp.status, 200, JSON.stringify(otp.data));
  assert.match(otp.data.devCode, /^\d{6}$/);

  const verify = await injectPost("/api/auth/email-otp/verify", {
    email,
    code: otp.data.devCode,
  });
  assert.equal(verify.status, 200, JSON.stringify(verify.data));

  const register = await injectPost<{ accessToken: string; refreshToken: string }>("/api/auth/register", {
    email,
    username,
    password,
    deviceId: "legacy-mobile-test",
    deviceName: "Legacy Mobile Test",
    platform: "android",
  });
  assert.equal(register.status, 200, JSON.stringify(register.data));
  assert.ok(register.data.accessToken);
  assert.ok(register.data.refreshToken);

  const login = await injectPost<{ accessToken: string; refreshToken: string }>("/api/auth/login", {
    email,
    password,
    deviceId: "legacy-mobile-test",
    deviceName: "Legacy Mobile Test",
    platform: "android",
  });
  assert.equal(login.status, 200, JSON.stringify(login.data));
  assert.ok(login.data.accessToken);
  assert.ok(login.data.refreshToken);

  const resetRequest = await injectPost<{ devToken: string }>("/api/auth/password-reset/request", {
    email,
  });
  assert.equal(resetRequest.status, 200, JSON.stringify(resetRequest.data));
  assert.match(resetRequest.data.devToken, /^\d{6}$/);

  const reset = await injectPost("/api/auth/password-reset/confirm", {
    token: resetRequest.data.devToken,
    newPassword: nextPassword,
  });
  assert.equal(reset.status, 200, JSON.stringify(reset.data));

  const oldPasswordLogin = await injectPost("/api/auth/login", {
    email,
    password,
    deviceId: "legacy-mobile-test",
  });
  assert.equal(oldPasswordLogin.status, 401, JSON.stringify(oldPasswordLogin.data));

  const newPasswordLogin = await injectPost<{ accessToken: string }>("/api/auth/login", {
    email,
    password: nextPassword,
    deviceId: "legacy-mobile-test",
  });
  assert.equal(newPasswordLogin.status, 200, JSON.stringify(newPasswordLogin.data));
  assert.ok(newPasswordLogin.data.accessToken);

  const pgLib = await import("../src/lib/pg.js");
  const repaired = await pgLib.queryOne<{ handle: string; handle_normalized: string }>(
    `SELECT handle, handle_normalized FROM users WHERE email_lower = $1`,
    [email]
  );
  assert.equal(repaired?.handle.length, 30);
  assert.equal(repaired?.handle_normalized.length, 30);
});
