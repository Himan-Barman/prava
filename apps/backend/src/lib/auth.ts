import type { FastifyRequest } from "fastify";

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
    };
  } catch {
    throw new HttpError(401, "Unauthorized");
  }
}
