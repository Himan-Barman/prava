import type { FastifyRequest } from "fastify";

import { query } from "./pg.js";
import { HttpError, verifyAccessToken } from "./security.js";

export async function requireAuth(request: FastifyRequest): Promise<void> {
  const header = request.headers.authorization || "";
  const [type, token] = header.split(" ");
  if (type !== "Bearer" || !token) {
    throw new HttpError(401, "Unauthorized");
  }

  try {
    const payload = verifyAccessToken(token);
    request.user = {
      userId: payload.sub,
      email: payload.email,
      username: payload.username,
      sessionId: typeof payload.sid === "string" ? payload.sid : undefined,
      role: typeof payload.role === "string" ? payload.role : undefined,
    };
    void query(
      `UPDATE users SET last_seen_at = NOW() WHERE user_id = $1`,
      [payload.sub]
    ).catch(() => undefined);
  } catch {
    throw new HttpError(401, "Unauthorized");
  }
}
