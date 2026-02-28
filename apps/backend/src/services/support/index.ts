import { getDb } from "../../lib/mongo.js";
import { requireAuth } from "../../lib/auth.js";
import { ensure, now } from "../../lib/security.js";

function generateSupportId() {
  return `${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
}

export default async function supportService(app) {
  const db = getDb();

  app.post("/", { preHandler: requireAuth }, async (request) => {
    const body = request.body || {};
    const type = String(body.type || "").trim().toLowerCase();
    const message = String(body.message || "").trim();

    ensure(["report", "feedback", "help"].includes(type), 400, "Invalid support type");
    ensure(message.length >= 2 && message.length <= 5000, 400, "Invalid message");

    const item = {
      supportId: generateSupportId(),
      userId: request.user.userId,
      type,
      category: body.category ? String(body.category).trim().slice(0, 120) : null,
      score: Number.isFinite(body.score) ? Number(body.score) : null,
      includeLogs: body.includeLogs === true,
      allowContact: body.allowContact !== false,
      message,
      status: "open",
      createdAt: now(),
      updatedAt: now(),
    };

    await db.collection("support_requests").insertOne(item);

    return {
      success: true,
      id: item.supportId,
    };
  });
}
