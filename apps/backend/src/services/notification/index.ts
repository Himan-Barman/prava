import type { FastifyInstance } from "fastify";

import { requireAuth } from "../../lib/auth.js";
import {
  deleteNotificationDevice,
  dismissNotification,
  getNotificationPreferences,
  getUnreadNotificationCount,
  listNotifications,
  markAllNotificationsRead,
  markNotificationClicked,
  markNotificationRead,
  registerNotificationDevice,
  updateNotificationPreferences,
} from "./repository.js";

const actorSchema = {
  type: ["object", "null"],
  additionalProperties: false,
  properties: {
    id: { type: "string" },
    username: { type: "string" },
    displayName: { type: "string" },
    avatarUrl: { type: "string" },
    isVerified: { type: "boolean" },
  },
};

const notificationSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    id: { type: "string" },
    type: { type: "string" },
    legacyType: { type: ["string", "null"] },
    title: { type: "string" },
    body: { type: "string" },
    entityType: { type: ["string", "null"] },
    entityId: { type: ["string", "null"] },
    priority: { type: "string" },
    createdAt: { type: ["string", "null"] },
    updatedAt: { type: ["string", "null"] },
    readAt: { type: ["string", "null"] },
    clickedAt: { type: ["string", "null"] },
    dismissedAt: { type: ["string", "null"] },
    expiresAt: { type: ["string", "null"] },
    data: { type: "object", additionalProperties: true },
    actor: actorSchema,
  },
};

const preferenceSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    category: { type: "string" },
    inAppEnabled: { type: "boolean" },
    pushEnabled: { type: "boolean" },
    emailEnabled: { type: "boolean" },
    quietHoursEnabled: { type: "boolean" },
    quietHoursStart: { type: ["string", "null"] },
    quietHoursEnd: { type: ["string", "null"] },
    timezone: { type: "string" },
    updatedAt: { type: ["string", "null"] },
  },
};

export default async function notificationService(app: FastifyInstance): Promise<void> {
  app.get("/", {
    preHandler: requireAuth,
    schema: {
      querystring: {
        type: "object",
        additionalProperties: false,
        properties: {
          limit: { type: "string", pattern: "^[0-9]{1,3}$" },
          cursor: { type: "string" },
          type: { type: "string" },
        },
      },
      response: {
        200: {
          type: "object",
          additionalProperties: false,
          properties: {
            items: { type: "array", items: notificationSchema },
            nextCursor: { type: ["string", "null"] },
            unreadCount: { type: "number" },
          },
        },
      },
    },
  }, async (request) => {
    return listNotifications({
      userId: request.user!.userId,
      limit: (request.query as any)?.limit,
      cursor: (request.query as any)?.cursor,
      type: (request.query as any)?.type,
    });
  });

  app.get("/unread-count", {
    preHandler: requireAuth,
    schema: {
      response: {
        200: {
          type: "object",
          additionalProperties: false,
          properties: {
            count: { type: "number" },
          },
        },
      },
    },
  }, async (request) => {
    return { count: await getUnreadNotificationCount(request.user!.userId) };
  });

  app.get("/preferences", {
    preHandler: requireAuth,
    schema: {
      response: {
        200: {
          type: "object",
          additionalProperties: false,
          properties: {
            items: { type: "array", items: preferenceSchema },
          },
        },
      },
    },
  }, async (request) => {
    return getNotificationPreferences(request.user!.userId);
  });

  app.patch("/preferences", {
    preHandler: requireAuth,
    schema: {
      body: {
        anyOf: [
          {
            type: "object",
            additionalProperties: true,
          },
          {
            type: "array",
            items: {
              type: "object",
              additionalProperties: true,
            },
          },
        ],
      },
      response: {
        200: {
          type: "object",
          additionalProperties: false,
          properties: {
            items: { type: "array", items: preferenceSchema },
          },
        },
      },
    },
  }, async (request) => {
    return updateNotificationPreferences(request.user!.userId, request.body);
  });

  app.post("/devices", {
    preHandler: requireAuth,
    schema: {
      body: {
        type: "object",
        required: ["deviceId", "pushToken"],
        additionalProperties: true,
        properties: {
          deviceId: { type: "string", minLength: 1, maxLength: 160 },
          platform: { type: "string", maxLength: 32 },
          pushProvider: { type: "string", maxLength: 32 },
          pushToken: { type: "string", minLength: 1, maxLength: 4096 },
          appVersion: { type: "string", maxLength: 32 },
          deviceName: { type: "string", maxLength: 180 },
        },
      },
      response: {
        200: {
          type: "object",
          additionalProperties: true,
          properties: {
            success: { type: "boolean" },
            device: { type: "object", additionalProperties: true },
          },
        },
      },
    },
  }, async (request) => {
    return registerNotificationDevice(request.user!.userId, request.body);
  });

  app.delete("/devices/:deviceId", {
    preHandler: requireAuth,
    schema: {
      params: {
        type: "object",
        required: ["deviceId"],
        additionalProperties: false,
        properties: {
          deviceId: { type: "string", minLength: 1, maxLength: 160 },
        },
      },
      response: {
        200: {
          type: "object",
          additionalProperties: false,
          properties: { success: { type: "boolean" } },
        },
      },
    },
  }, async (request) => {
    return deleteNotificationDevice(request.user!.userId, (request.params as any).deviceId);
  });

  app.post("/read-all", {
    preHandler: requireAuth,
    schema: {
      response: {
        200: {
          type: "object",
          additionalProperties: false,
          properties: {
            success: { type: "boolean" },
            unreadCount: { type: "number" },
          },
        },
      },
    },
  }, async (request) => {
    return markAllNotificationsRead(request.user!.userId);
  });

  app.post("/:notificationId/read", {
    preHandler: requireAuth,
    schema: {
      params: {
        type: "object",
        required: ["notificationId"],
        additionalProperties: false,
        properties: {
          notificationId: { type: "string", format: "uuid" },
        },
      },
      response: {
        200: {
          type: "object",
          additionalProperties: false,
          properties: {
            success: { type: "boolean" },
            readAt: { type: ["string", "null"] },
            unreadCount: { type: "number" },
          },
        },
      },
    },
  }, async (request) => {
    return markNotificationRead(request.user!.userId, (request.params as any).notificationId);
  });

  app.post("/:notificationId/click", {
    preHandler: requireAuth,
    schema: {
      params: {
        type: "object",
        required: ["notificationId"],
        additionalProperties: false,
        properties: {
          notificationId: { type: "string", format: "uuid" },
        },
      },
      response: {
        200: {
          type: "object",
          additionalProperties: false,
          properties: {
            success: { type: "boolean" },
            clickedAt: { type: ["string", "null"] },
          },
        },
      },
    },
  }, async (request) => {
    return markNotificationClicked(request.user!.userId, (request.params as any).notificationId);
  });

  app.delete("/:notificationId", {
    preHandler: requireAuth,
    schema: {
      params: {
        type: "object",
        required: ["notificationId"],
        additionalProperties: false,
        properties: {
          notificationId: { type: "string", format: "uuid" },
        },
      },
      response: {
        200: {
          type: "object",
          additionalProperties: false,
          properties: {
            success: { type: "boolean" },
            unreadCount: { type: "number" },
          },
        },
      },
    },
  }, async (request) => {
    return dismissNotification(request.user!.userId, (request.params as any).notificationId);
  });
}
