import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";

import { HttpError } from "../../lib/security.js";

type BridgeOptions = {
  method: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  path: string;
  payload?: unknown;
  query?: Record<string, unknown>;
};

function pickForwardHeaders(request: FastifyRequest): Record<string, string> {
  const headers: Record<string, string> = {
    "content-type": "application/json",
  };

  const authorization = request.headers.authorization;
  if (typeof authorization === "string") {
    headers.authorization = authorization;
  }

  const deviceId = request.headers["x-device-id"];
  if (typeof deviceId === "string") {
    headers["x-device-id"] = deviceId;
  }

  return headers;
}

function parsePayload(text: string): unknown {
  if (!text) {
    return null;
  }
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

export async function bridgeToLegacy(
  app: FastifyInstance,
  request: FastifyRequest,
  reply: FastifyReply,
  options: BridgeOptions
): Promise<unknown> {
  const response = await app.inject({
    method: options.method,
    url: options.path,
    headers: pickForwardHeaders(request),
    payload: options.payload === undefined ? undefined : JSON.stringify(options.payload),
    query: options.query as Record<string, string> | undefined,
  });

  const payload = parsePayload(response.body);
  if (response.statusCode >= 400) {
    const message = payload && typeof payload === "object" && "message" in payload
      ? String((payload as { message?: unknown }).message || "Request failed")
      : "Request failed";
    throw new HttpError(response.statusCode, message);
  }

  reply.code(response.statusCode);
  return payload;
}
