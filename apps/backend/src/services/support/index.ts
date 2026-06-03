import { query } from "../../lib/pg.js";
import { requireAuth } from "../../lib/auth.js";
import { ensure, now } from "../../lib/security.js";

function generateSupportId() {
  return `${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
}

export default async function supportService(app) {
  app.post("/", { preHandler: requireAuth }, async (request) => {
    const body = request.body || {};
    const type = String(body.type || "").trim().toLowerCase();
    const message = String(body.message || "").trim();

    ensure(["report", "feedback", "help"].includes(type), 400, "Invalid support type");
    ensure(message.length >= 2 && message.length <= 5000, 400, "Invalid message");

    const supportId = generateSupportId();
    const ts = now();

    await query(
      `INSERT INTO support_requests (support_id, user_id, type, category, score, include_logs, allow_contact, message, status, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
      [
        supportId,
        request.user.userId,
        type,
        body.category ? String(body.category).trim().slice(0, 120) : null,
        Number.isFinite(body.score) ? Number(body.score) : null,
        body.includeLogs === true,
        body.allowContact !== false,
        message,
        "open",
        ts,
        ts,
      ]
    );

    return {
      success: true,
      id: supportId,
    };
  });
}
