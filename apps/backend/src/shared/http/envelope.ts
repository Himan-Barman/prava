import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";

type EnvelopeMeta = {
  requestId: string;
  nextCursor?: string | null;
};

function isApiV1(request: FastifyRequest): boolean {
  return String(request.raw.url || "").startsWith("/api/v1");
}

function tryParseJson(payload: unknown): unknown {
  if (payload == null) {
    return null;
  }
  if (Buffer.isBuffer(payload)) {
    const text = payload.toString("utf8");
    return text ? JSON.parse(text) : null;
  }
  if (typeof payload === "string") {
    return payload ? JSON.parse(payload) : null;
  }
  return payload;
}

function isEnvelope(value: unknown): boolean {
  return !!value && typeof value === "object" && "success" in value && "meta" in value;
}

export function buildSuccessEnvelope(data: unknown, request: FastifyRequest): {
  success: true;
  data: unknown;
  meta: EnvelopeMeta;
} {
  const meta: EnvelopeMeta = {
    requestId: request.id,
  };

  if (
    data &&
    typeof data === "object" &&
    "nextCursor" in data &&
    typeof (data as { nextCursor?: unknown }).nextCursor !== "undefined"
  ) {
    meta.nextCursor = (data as { nextCursor?: string | null }).nextCursor ?? null;
  }

  return {
    success: true,
    data,
    meta,
  };
}

export function buildErrorEnvelope(
  request: FastifyRequest,
  code: string,
  message: string,
  details: Record<string, unknown> = {}
): {
  success: false;
  error: {
    code: string;
    message: string;
    details: Record<string, unknown>;
  };
  meta: EnvelopeMeta;
} {
  return {
    success: false,
    error: {
      code,
      message,
      details,
    },
    meta: {
      requestId: request.id,
    },
  };
}

export function registerApiV1Envelope(app: FastifyInstance): void {
  app.addHook("onSend", async (request, reply: FastifyReply, payload) => {
    if (!isApiV1(request) || reply.statusCode >= 400) {
      return payload;
    }

    const contentType = String(reply.getHeader("content-type") || "");
    if (contentType && !contentType.includes("application/json")) {
      return payload;
    }

    try {
      const parsed = tryParseJson(payload);
      if (isEnvelope(parsed)) {
        return payload;
      }
      reply.header("content-type", "application/json; charset=utf-8");
      return JSON.stringify(buildSuccessEnvelope(parsed, request));
    } catch {
      return payload;
    }
  });
}

export function isApiV1Request(request: FastifyRequest): boolean {
  return isApiV1(request);
}
