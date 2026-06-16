import assert from "node:assert/strict";
import { once } from "node:events";
import { AddressInfo } from "node:net";
import test, { after, before } from "node:test";

import websocket from "@fastify/websocket";
import Fastify from "fastify";
import jwt from "jsonwebtoken";
import { newDb } from "pg-mem";
import WebSocket from "ws";

type SocketEvent = {
  type: string;
  payload: Record<string, unknown>;
};

function authHeader(token: string): Record<string, string> {
  return {
    authorization: `Bearer ${token}`,
    "content-type": "application/json",
  };
}

function signAccessToken(userId: string): string {
  const secret = process.env.JWT_SECRET || "";
  return jwt.sign(
    {
      sub: userId,
      email: `${userId}@example.com`,
      username: userId.slice(0, 16),
    },
    secret,
    {
      issuer: "prava",
      audience: "prava-clients",
      expiresIn: "30m",
    }
  );
}

function scalarText(value: unknown): string {
  return Array.isArray(value) ? String(value[0] ?? "") : String(value ?? "");
}

async function waitForSocketEvent(
  socket: WebSocket,
  expectedType: string,
  timeoutMs = 4000
): Promise<SocketEvent> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      socket.off("message", onMessage);
      reject(new Error(`Timed out waiting for ${expectedType}`));
    }, timeoutMs);

    const onMessage = (raw: WebSocket.RawData) => {
      try {
        const event = JSON.parse(String(raw)) as SocketEvent;
        if (event?.type === expectedType) {
          clearTimeout(timer);
          socket.off("message", onMessage);
          resolve(event);
        }
      } catch {
        // ignore invalid payload
      }
    };

    socket.on("message", onMessage);
  });
}

async function httpJson<T = unknown>(
  baseUrl: string,
  path: string,
  options: {
    method?: string;
    token?: string;
    body?: unknown;
  } = {}
): Promise<{ status: number; data: T }> {
  const response = await fetch(`${baseUrl}${path}`, {
    method: options.method || "GET",
    headers: options.token
      ? authHeader(options.token)
      : { "content-type": "application/json" },
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  });

  const text = await response.text();
  const data = text ? (JSON.parse(text) as T) : ({} as T);
  return { status: response.status, data };
}

let app: ReturnType<typeof Fastify>;
let baseUrl = "";
let wsBaseUrl = "";
let closePg: (() => Promise<void>) | null = null;
let userAToken = "";
let userBToken = "";
let userCToken = "";
let userAId = "";
let userBId = "";
let userCId = "";

before(async () => {
  userAId = `u_${Date.now()}_a`;
  userBId = `u_${Date.now()}_b`;
  userCId = `u_${Date.now()}_c`;

  process.env.NODE_ENV = "test";
  process.env.JWT_SECRET = process.env.JWT_SECRET || "test_jwt_secret_key";
  process.env.DATABASE_URL = process.env.DATABASE_URL || "postgresql://postgres:postgres@127.0.0.1:5432/prava_test";

  const pgLib = await import("../src/lib/pg.js");
  const memoryDb = newDb({ autoCreateForeignKeyIndices: true });
  const adapter = memoryDb.adapters.createPg();
  const pool = new adapter.Pool();
  pgLib.setPgPoolForTest(pool as any);
  await pgLib.runMigrations(pool as any);
  closePg = pgLib.closePg;

  const now = new Date();
  await pgLib.query(
    `INSERT INTO users (
       user_id, email, email_lower, username, username_lower, display_name,
       display_name_lower, password_hash, is_verified, created_at, updated_at
     )
     VALUES
       ($1, 'usera@example.com', 'usera@example.com', 'usera_test', 'usera_test', 'User A', 'user a', 'scrypt$dummy$dummy', TRUE, $4, $4),
       ($2, 'userb@example.com', 'userb@example.com', 'userb_test', 'userb_test', 'User B', 'user b', 'scrypt$dummy$dummy', TRUE, $4, $4),
       ($3, 'userc@example.com', 'userc@example.com', 'userc_test', 'userc_test', 'User C', 'user c', 'scrypt$dummy$dummy', TRUE, $4, $4)`,
    [userAId, userBId, userCId, now]
  );

  userAToken = signAccessToken(userAId);
  userBToken = signAccessToken(userBId);
  userCToken = signAccessToken(userCId);

  const chatService = (await import("../src/services/chat/index.js")).default;
  const realtimeService = (await import("../src/services/realtime/index.js")).default;
  const userService = (await import("../src/services/user/index.js")).default;
  const authService = (await import("../src/services/auth/index.js")).default;

  app = Fastify({ logger: false });
  await app.register(websocket, {
    options: {
      maxPayload: 1024 * 1024,
    },
  });
  app.register(realtimeService);
  app.register(authService, { prefix: "/api/auth" });
  app.register(chatService, { prefix: "/api/conversations" });
  app.register(userService, { prefix: "/api/users" });

  await app.listen({ host: "127.0.0.1", port: 0 });
  const address = app.server.address() as AddressInfo;
  baseUrl = `http://127.0.0.1:${address.port}`;
  wsBaseUrl = `ws://127.0.0.1:${address.port}`;
});

after(async () => {
  try {
    await app?.close();
  } catch {
    // ignore
  }

  try {
    if (closePg) {
      await closePg();
    }
  } catch {
    // ignore
  }
});

test("chat routes: dm create, send message, read + delivery + sync", async () => {
  const dmCreate = await httpJson<{ conversationId: string; created?: boolean }>(
    baseUrl,
    "/api/conversations/dm",
    {
      method: "POST",
      token: userAToken,
      body: { otherUserId: userBId },
    }
  );
  assert.equal(dmCreate.status, 200);
  assert.ok(dmCreate.data.conversationId);
  const conversationId = dmCreate.data.conversationId;

  const clientMessageId = "00000000-0000-4000-8000-000000000101";
  const sendMessage = await httpJson<{
    created: boolean;
    message: { seq: number; messageId: string; clientMessageId?: string };
  }>(
    baseUrl,
    `/api/conversations/${conversationId}/messages`,
    {
      method: "POST",
      token: userAToken,
      body: {
        body: "hello route integration",
        contentType: "text",
        deviceId: "device-a",
        tempId: "tmp-route-1",
        clientMessageId,
      },
    }
  );
  assert.equal(sendMessage.status, 200);
  assert.equal(sendMessage.data.created, true);
  assert.ok(sendMessage.data.message.messageId);
  assert.equal(sendMessage.data.message.seq, 1);
  assert.equal(sendMessage.data.message.clientMessageId, clientMessageId);

  const duplicateSend = await httpJson<{
    created: boolean;
    message: { seq: number; messageId: string; clientMessageId?: string };
  }>(
    baseUrl,
    `/api/conversations/${conversationId}/messages`,
    {
      method: "POST",
      token: userAToken,
      body: {
        body: "hello route integration",
        contentType: "text",
        deviceId: "device-a",
        tempId: "tmp-route-1-retry",
        clientMessageId,
      },
    }
  );
  assert.equal(duplicateSend.status, 200);
  assert.equal(duplicateSend.data.created, false);
  assert.equal(duplicateSend.data.message.messageId, sendMessage.data.message.messageId);
  assert.equal(duplicateSend.data.message.seq, 1);

  const listForBBeforeAccept = await httpJson<Array<{ id: string; unreadCount: number }>>(
    baseUrl,
    "/api/conversations",
    {
      token: userBToken,
    }
  );
  assert.equal(listForBBeforeAccept.status, 200);
  assert.equal(
    listForBBeforeAccept.data.find((item) => item.id === conversationId),
    undefined
  );

  const requestsForB = await httpJson<Array<{ id: string; unreadCount: number }>>(
    baseUrl,
    "/api/conversations/requests",
    {
      token: userBToken,
    }
  );
  assert.equal(requestsForB.status, 200);
  const requestRow = requestsForB.data.find((item) => item.id === conversationId);
  assert.ok(requestRow);
  assert.equal(requestRow.unreadCount, 1);

  const messagesBeforeAccept = await httpJson<{ message?: string }>(
    baseUrl,
    `/api/conversations/${conversationId}/messages`,
    {
      token: userBToken,
    }
  );
  assert.equal(messagesBeforeAccept.status, 403);

  const acceptRequest = await httpJson<{ success: boolean }>(
    baseUrl,
    `/api/conversations/requests/${conversationId}/accept`,
    {
      method: "POST",
      token: userBToken,
      body: {},
    }
  );
  assert.equal(acceptRequest.status, 200, JSON.stringify(acceptRequest.data));
  assert.equal(acceptRequest.data.success, true);

  const listForB = await httpJson<Array<{ id: string; unreadCount: number }>>(
    baseUrl,
    "/api/conversations",
    {
      token: userBToken,
    }
  );
  assert.equal(listForB.status, 200);
  const rowB = listForB.data.find((item) => item.id === conversationId);
  assert.ok(rowB);
  assert.equal(rowB.unreadCount, 1);

  const read = await httpJson<{ success: boolean; lastReadSeq: number }>(
    baseUrl,
    `/api/conversations/${conversationId}/read`,
    {
      method: "POST",
      token: userBToken,
      body: { lastReadSeq: 1 },
    }
  );
  assert.equal(read.status, 200);
  assert.equal(read.data.lastReadSeq, 1);

  const delivery = await httpJson<{ success: boolean; lastDeliveredSeq: number }>(
    baseUrl,
    `/api/conversations/${conversationId}/delivery`,
    {
      method: "POST",
      token: userBToken,
      body: { lastDeliveredSeq: 1 },
    }
  );
  assert.equal(delivery.status, 200);
  assert.equal(delivery.data.lastDeliveredSeq, 1);

  const reads = await httpJson<Array<{ userId: string; lastReadSeq: number; lastDeliveredSeq: number }>>(
    baseUrl,
    `/api/conversations/${conversationId}/reads`,
    {
      token: userAToken,
    }
  );
  assert.equal(reads.status, 200);
  const readB = reads.data.find((row) => row.userId === userBId);
  assert.ok(readB);
  assert.equal(readB.lastReadSeq, 1);
  assert.equal(readB.lastDeliveredSeq, 1);

  const sync = await httpJson<{ conversations: Array<{ conversationId: string; messages: unknown[] }> }>(
    baseUrl,
    "/api/conversations/sync",
    {
      method: "POST",
      token: userBToken,
      body: {
        conversations: [
          {
            conversationId,
            lastKnownSeq: 0,
          },
        ],
      },
    }
  );
  assert.equal(sync.status, 200);
  assert.equal(sync.data.conversations.length, 1);
  assert.equal(sync.data.conversations[0].conversationId, conversationId);
  assert.equal(sync.data.conversations[0].messages.length, 1);

  const settingsBefore = await httpJson<{ readReceipts: boolean; archivedBehavior: string }>(
    baseUrl,
    "/api/conversations/settings",
    { token: userBToken }
  );
  assert.equal(settingsBefore.status, 200);
  assert.equal(settingsBefore.data.readReceipts, true);
  assert.equal(settingsBefore.data.archivedBehavior, "keep_archived");

  const settingsPatch = await httpJson<{ success: boolean; settings: { chatReadReceipts: boolean; chatArchivedBehavior: string } }>(
    baseUrl,
    "/api/conversations/settings",
    {
      method: "PATCH",
      token: userBToken,
      body: {
        readReceipts: false,
        archivedBehavior: "unarchive_on_message",
      },
    }
  );
  assert.equal(settingsPatch.status, 200);
  assert.equal(settingsPatch.data.success, true);
  assert.equal(settingsPatch.data.settings.chatReadReceipts, false);
  assert.equal(settingsPatch.data.settings.chatArchivedBehavior, "unarchive_on_message");

  const preferences = await httpJson<{ success: boolean; preferences: { isArchived: boolean; draftText: string } }>(
    baseUrl,
    `/api/conversations/${conversationId}/preferences`,
    {
      method: "PUT",
      token: userBToken,
      body: {
        isArchived: true,
        draftText: "draft note",
      },
    }
  );
  assert.equal(preferences.status, 200);
  assert.equal(preferences.data.success, true);
  assert.equal(preferences.data.preferences.isArchived, true);
  assert.equal(preferences.data.preferences.draftText, "draft note");

  const activeAfterArchive = await httpJson<Array<{ id: string }>>(
    baseUrl,
    "/api/conversations",
    { token: userBToken }
  );
  assert.equal(activeAfterArchive.status, 200);
  assert.equal(activeAfterArchive.data.find((item) => item.id === conversationId), undefined);

  const archived = await httpJson<Array<{ id: string; draftText: string; isArchived: boolean }>>(
    baseUrl,
    "/api/conversations?archived=true",
    { token: userBToken }
  );
  assert.equal(archived.status, 200);
  const archivedRow = archived.data.find((item) => item.id === conversationId);
  assert.ok(archivedRow);
  assert.equal(archivedRow.isArchived, true);
  assert.equal(archivedRow.draftText, "draft note");

  const markUnread = await httpJson<{ success: boolean; unreadCount: number }>(
    baseUrl,
    `/api/conversations/${conversationId}/mark-unread`,
    {
      method: "POST",
      token: userBToken,
      body: {},
    }
  );
  assert.equal(markUnread.status, 200);
  assert.equal(markUnread.data.unreadCount, 1);

  const includeArchivedAfterMarkUnread = await httpJson<Array<{ id: string; unreadCount: number; markedUnread: boolean }>>(
    baseUrl,
    "/api/conversations?includeArchived=true",
    { token: userBToken }
  );
  assert.equal(includeArchivedAfterMarkUnread.status, 200);
  const markedUnreadRow = includeArchivedAfterMarkUnread.data.find((item) => item.id === conversationId);
  assert.ok(markedUnreadRow);
  assert.equal(markedUnreadRow.markedUnread, true);
  assert.equal(markedUnreadRow.unreadCount, 1);

  const search = await httpJson<{ results: Array<{ messageId: string }> }>(
    baseUrl,
    `/api/conversations/${conversationId}/search?q=route`,
    { token: userBToken }
  );
  assert.equal(search.status, 200);
  assert.equal(search.data.results.length, 1);

  const pin = await httpJson<{ success: boolean; messageId: string }>(
    baseUrl,
    `/api/conversations/${conversationId}/messages/${sendMessage.data.message.messageId}/pin`,
    {
      method: "POST",
      token: userBToken,
      body: {},
    }
  );
  assert.equal(pin.status, 200);
  assert.equal(pin.data.success, true);

  const pinned = await httpJson<Array<{ messageId: string; pinnedByUserId: string }>>(
    baseUrl,
    `/api/conversations/${conversationId}/pinned-messages`,
    { token: userBToken }
  );
  assert.equal(pinned.status, 200);
  assert.equal(pinned.data[0]?.messageId, sendMessage.data.message.messageId);
  assert.equal(pinned.data[0]?.pinnedByUserId, userBId);

  const details = await httpJson<{ message: { messageId: string }; receipts: Array<{ userId: string; seen: boolean }> }>(
    baseUrl,
    `/api/conversations/${conversationId}/messages/${sendMessage.data.message.messageId}/details`,
    { token: userAToken }
  );
  assert.equal(details.status, 200);
  assert.equal(details.data.message.messageId, sendMessage.data.message.messageId);
  assert.equal(details.data.receipts.find((item) => item.userId === userBId)?.seen, true);

  const report = await httpJson<{ success: boolean; reportId: string; status: string }>(
    baseUrl,
    "/api/conversations/report",
    {
      method: "POST",
      token: userBToken,
      body: {
        conversationId,
        messageId: sendMessage.data.message.messageId,
        reportedUserId: userAId,
        reason: "spam",
        details: "test report",
      },
    }
  );
  assert.equal(report.status, 200);
  assert.equal(report.data.success, true);
  assert.ok(report.data.reportId);
  assert.equal(report.data.status, "open");

  const save = await httpJson<{ success: boolean; note: string }>(
    baseUrl,
    `/api/conversations/${conversationId}/messages/${sendMessage.data.message.messageId}/save`,
    {
      method: "POST",
      token: userBToken,
      body: { note: "important" },
    }
  );
  assert.equal(save.status, 200, JSON.stringify(save.data));
  assert.equal(save.data.success, true);
  assert.equal(save.data.note, "important");

  const saved = await httpJson<Array<{ messageId: string; note: string }>>(
    baseUrl,
    `/api/conversations/${conversationId}/saved-messages`,
    { token: userBToken }
  );
  assert.equal(saved.status, 200);
  assert.equal(saved.data[0]?.messageId, sendMessage.data.message.messageId);
  assert.equal(saved.data[0]?.note, "important");

  const clearLocal = await httpJson<{ success: boolean; clearedBeforeSeq: number }>(
    baseUrl,
    `/api/conversations/${conversationId}/clear-local`,
    {
      method: "POST",
      token: userBToken,
      body: {},
    }
  );
  assert.equal(clearLocal.status, 200, JSON.stringify(clearLocal.data));
  assert.equal(clearLocal.data.success, true);
  assert.equal(clearLocal.data.clearedBeforeSeq, 1);

  const messagesAfterClear = await httpJson<Array<{ messageId: string }>>(
    baseUrl,
    `/api/conversations/${conversationId}/messages`,
    { token: userBToken }
  );
  assert.equal(messagesAfterClear.status, 200);
  assert.equal(messagesAfterClear.data.length, 0);

  const hiddenSaved = await httpJson<Array<{ messageId: string }>>(
    baseUrl,
    `/api/conversations/${conversationId}/saved-messages`,
    { token: userBToken }
  );
  assert.equal(hiddenSaved.status, 200);
  assert.equal(hiddenSaved.data.length, 0);

  const deleteLocal = await httpJson<{ success: boolean; localDeletedAt: string }>(
    baseUrl,
    `/api/conversations/${conversationId}`,
    {
      method: "DELETE",
      token: userBToken,
      body: {},
    }
  );
  assert.equal(deleteLocal.status, 200, JSON.stringify(deleteLocal.data));
  assert.equal(deleteLocal.data.success, true);
  assert.ok(deleteLocal.data.localDeletedAt);

  const listAfterLocalDelete = await httpJson<Array<{ id: string }>>(
    baseUrl,
    "/api/conversations?includeArchived=true",
    { token: userBToken }
  );
  assert.equal(listAfterLocalDelete.status, 200);
  assert.equal(listAfterLocalDelete.data.some((item) => item.id === conversationId), false);

  const blockA = await httpJson<{ blocked: boolean }>(
    baseUrl,
    `/api/users/${userAId}/block`,
    {
      method: "POST",
      token: userBToken,
      body: {},
    }
  );
  assert.equal(blockA.status, 200, JSON.stringify(blockA.data));
  assert.equal(blockA.data.blocked, true);

  const blockedSend = await httpJson<{ message?: string }>(
    baseUrl,
    `/api/conversations/${conversationId}/messages`,
    {
      method: "POST",
      token: userAToken,
      body: {
        body: "blocked message",
        contentType: "text",
        deviceId: "device-a",
        clientMessageId: "00000000-0000-4000-8000-000000000111",
      },
    }
  );
  assert.equal(blockedSend.status, 403);

  const unblockA = await httpJson<{ blocked: boolean }>(
    baseUrl,
    `/api/users/${userAId}/block`,
    {
      method: "DELETE",
      token: userBToken,
      body: {},
    }
  );
  assert.equal(unblockA.status, 200, JSON.stringify(unblockA.data));
  assert.equal(unblockA.data.blocked, false);
});

test("profile routes enforce private visibility and support profile actions", async () => {
  const settings = await httpJson<any>(baseUrl, "/api/users/me/settings", {
    method: "PUT",
    token: userBToken,
    body: {
      privateAccount: true,
      profileVisibility: {
        posts: "followers",
        media: "followers",
        highlights: "followers",
        followers: "public",
        following: "public",
      },
    },
  });
  assert.equal(settings.status, 200);
  assert.equal(settings.data.settings.privateAccount, true);

  const ownerPreview = await httpJson<any>(
    baseUrl,
    "/api/users/me/profile/preview?as=public",
    { token: userBToken }
  );
  assert.equal(ownerPreview.status, 200, JSON.stringify(ownerPreview.data));
  assert.equal(ownerPreview.data.profileState, "private");
  assert.equal(ownerPreview.data.viewerRelation, "nonFollower");
  assert.equal(Array.isArray(ownerPreview.data.tabs), true);
  assert.equal(ownerPreview.data.tabs.length, 0);

  const privateProfile = await httpJson<any>(
    baseUrl,
    `/api/users/${userBId}/profile`,
    { token: userAToken }
  );
  assert.equal(privateProfile.status, 200, JSON.stringify(privateProfile.data));
  assert.equal(privateProfile.data.profileState, "private");
  assert.equal(privateProfile.data.stats.posts, 0);

  const requestFollow = await httpJson<any>(
    baseUrl,
    `/api/users/${userBId}/follow`,
    {
      method: "PUT",
      token: userAToken,
      body: { follow: true },
    }
  );
  assert.equal(requestFollow.status, 200);
  assert.equal(requestFollow.data.following, false);
  assert.equal(requestFollow.data.requested, true);

  const requestedProfile = await httpJson<any>(
    baseUrl,
    `/api/users/${userBId}/profile`,
    { token: userAToken }
  );
  assert.equal(requestedProfile.status, 200);
  assert.equal(requestedProfile.data.viewerRelation, "requestPending");
  assert.equal(requestedProfile.data.relationship.requestPending, true);

  const acceptFollow = await httpJson<any>(
    baseUrl,
    `/api/users/${userAId}/follow-request/accept`,
    { method: "POST", token: userBToken, body: {} }
  );
  assert.equal(acceptFollow.status, 200, JSON.stringify(acceptFollow.data));
  assert.equal(acceptFollow.data.accepted, true);

  const followerProfile = await httpJson<any>(
    baseUrl,
    `/api/users/${userBId}/profile`,
    { token: userAToken }
  );
  assert.equal(followerProfile.status, 200);
  assert.equal(followerProfile.data.profileState, "public");
  assert.equal(followerProfile.data.viewerRelation, "follower");
  assert.ok(followerProfile.data.tabs.some((tab: any) => tab.key === "posts"));

  const link = await httpJson<any>(baseUrl, "/api/users/me/profile-links", {
    method: "POST",
    token: userBToken,
    body: { title: "Portfolio", url: "pravachat.me", visibility: "followers" },
  });
  assert.equal(link.status, 200);
  assert.equal(link.data.item.url, "https://pravachat.me/");

  const report = await httpJson<any>(
    baseUrl,
    `/api/users/${userBId}/report`,
    {
      method: "POST",
      token: userAToken,
      body: { reason: "other", details: "profile action test" },
    }
  );
  assert.equal(report.status, 200);
  assert.equal(report.data.reported, true);

  const block = await httpJson<any>(baseUrl, `/api/users/${userBId}/block`, {
    method: "POST",
    token: userAToken,
    body: {},
  });
  assert.equal(block.status, 200);
  assert.equal(block.data.blocked, true);

  const blockedProfile = await httpJson<any>(
    baseUrl,
    `/api/users/${userBId}/profile`,
    { token: userAToken }
  );
  assert.equal(blockedProfile.status, 200);
  assert.equal(blockedProfile.data.profileState, "blockedByViewer");

  const unblock = await httpJson<any>(baseUrl, `/api/users/${userBId}/block`, {
    method: "DELETE",
    token: userAToken,
    body: {},
  });
  assert.equal(unblock.status, 200);
  assert.equal(unblock.data.blocked, false);
});

test("username availability: taken and available", async () => {
  const taken = await httpJson<{ available: boolean }>(
    baseUrl,
    "/api/users/username-available?username=usera_test"
  );
  assert.equal(taken.status, 200);
  assert.equal(taken.data.available, false);

  const available = await httpJson<{ available: boolean }>(
    baseUrl,
    "/api/users/username-available?username=new_user_123"
  );
  assert.equal(available.status, 200);
  assert.equal(available.data.available, true);

  const invalid = await httpJson<{ message?: string }>(
    baseUrl,
    "/api/users/username-available?username=ab"
  );
  assert.equal(invalid.status, 400);
});

test("chat groups: invite approvals, role updates, and attachment lifecycle", async () => {
  const groupCreate = await httpJson<{ conversationId: string }>(
    baseUrl,
    "/api/conversations/group",
    {
      method: "POST",
      token: userAToken,
      body: { title: "Invite test group", memberIds: [userBId] },
    }
  );
  assert.equal(groupCreate.status, 200, JSON.stringify(groupCreate.data));
  const conversationId = groupCreate.data.conversationId;
  assert.ok(conversationId);

  const promote = await httpJson<{ success: boolean; role: string }>(
    baseUrl,
    `/api/conversations/groups/${conversationId}/members/${userBId}/role`,
    {
      method: "PATCH",
      token: userAToken,
      body: { role: "admin" },
    }
  );
  assert.equal(promote.status, 200, JSON.stringify(promote.data));
  assert.equal(promote.data.success, true);
  assert.equal(promote.data.role, "admin");

  const invite = await httpJson<{ invite: { inviteId: string; inviteToken: string; requiresApproval: boolean } }>(
    baseUrl,
    `/api/conversations/groups/${conversationId}/invites`,
    {
      method: "POST",
      token: userBToken,
      body: { requiresApproval: true, maxUses: 5, expiresInHours: 24 },
    }
  );
  assert.equal(invite.status, 200, JSON.stringify(invite.data));
  assert.ok(invite.data.invite.inviteId);
  assert.ok(invite.data.invite.inviteToken);
  assert.equal(invite.data.invite.requiresApproval, true);

  const join = await httpJson<{ status: string; request: { requestId: string; requesterUserId: string } }>(
    baseUrl,
    `/api/conversations/groups/join/${invite.data.invite.inviteToken}`,
    {
      method: "POST",
      token: userCToken,
      body: {},
    }
  );
  assert.equal(join.status, 200, JSON.stringify(join.data));
  assert.equal(join.data.status, "pending");
  assert.equal(join.data.request.requesterUserId, userCId);

  const requests = await httpJson<{ items: Array<{ requestId: string; requesterUserId: string }> }>(
    baseUrl,
    `/api/conversations/groups/${conversationId}/join-requests`,
    { token: userAToken }
  );
  assert.equal(requests.status, 200);
  assert.equal(requests.data.items[0]?.requestId, join.data.request.requestId);

  const approve = await httpJson<{ success: boolean; status: string; userId: string }>(
    baseUrl,
    `/api/conversations/groups/${conversationId}/join-requests/${join.data.request.requestId}/approve`,
    {
      method: "POST",
      token: userAToken,
      body: {},
    }
  );
  assert.equal(approve.status, 200, JSON.stringify(approve.data));
  assert.equal(approve.data.success, true);
  assert.equal(approve.data.status, "approved");
  assert.equal(approve.data.userId, userCId);

  const listForC = await httpJson<Array<{ id: string }>>(
    baseUrl,
    "/api/conversations",
    { token: userCToken }
  );
  assert.equal(listForC.status, 200);
  assert.ok(listForC.data.some((item) => item.id === conversationId));

  const attachmentInit = await httpJson<{
    attachmentId: string;
    uploadSessionId: string;
    uploadUrl: string;
  }>(
    baseUrl,
    "/api/conversations/attachments/upload-init",
    {
      method: "POST",
      token: userAToken,
      body: {
        conversationId,
        fileName: "photo.png",
        mimeType: "image/png",
        byteSize: 2048,
      },
    }
  );
  assert.equal(attachmentInit.status, 200, JSON.stringify(attachmentInit.data));
  assert.equal(attachmentInit.data.uploadUrl, "/api/media/upload");

  const pgLib = await import("../src/lib/pg.js");
  const mediaAssetId = `asset_${Date.now()}_chat`;
  await pgLib.query(
    `INSERT INTO media_assets (
       asset_id, user_id, public_id, url, secure_url, resource_type,
       format, width, height, bytes, folder, context, created_at
     )
     VALUES ($1, $2, $3, $4, $5, 'image', 'png', 32, 32, 2048, 'chat', 'chat_attachment', NOW())`,
    [
      mediaAssetId,
      userAId,
      `public_${mediaAssetId}`,
      `https://cdn.example.com/${mediaAssetId}.png`,
      `https://cdn.example.com/${mediaAssetId}.png`,
    ]
  );

  const attachmentComplete = await httpJson<{ success: boolean; attachment: { status: string; mediaAssetId: string } }>(
    baseUrl,
    "/api/conversations/attachments/upload-complete",
    {
      method: "POST",
      token: userAToken,
      body: {
        attachmentId: attachmentInit.data.attachmentId,
        uploadSessionId: attachmentInit.data.uploadSessionId,
        mediaAssetId,
      },
    }
  );
  assert.equal(attachmentComplete.status, 200, JSON.stringify(attachmentComplete.data));
  assert.equal(attachmentComplete.data.success, true);
  assert.equal(attachmentComplete.data.attachment.status, "ready");
  assert.equal(attachmentComplete.data.attachment.mediaAssetId, mediaAssetId);

  const mediaMessage = await httpJson<{ message: { contentType: string; mediaAssetId: string } }>(
    baseUrl,
    `/api/conversations/${conversationId}/messages`,
    {
      method: "POST",
      token: userAToken,
      body: {
        body: "",
        contentType: "image",
        deviceId: "device-a",
        mediaAssetId,
        clientMessageId: "00000000-0000-4000-8000-000000000202",
      },
    }
  );
  assert.equal(mediaMessage.status, 200, JSON.stringify(mediaMessage.data));
  assert.equal(mediaMessage.data.message.contentType, "image");
  assert.equal(mediaMessage.data.message.mediaAssetId, mediaAssetId);

  const attachments = await httpJson<{ items: Array<{ mediaAssetId: string; status: string }> }>(
    baseUrl,
    `/api/conversations/${conversationId}/attachments?type=image`,
    { token: userBToken }
  );
  assert.equal(attachments.status, 200);
  assert.equal(attachments.data.items[0]?.mediaAssetId, mediaAssetId);
  assert.equal(attachments.data.items[0]?.status, "attached");
});

test("realtime plugin does not handle plain root requests", async () => {
  const response = await fetch(baseUrl, { method: "HEAD" });
  assert.notEqual(response.status, 500);
});

test("username reservation: holds for signup flow and blocks others", async () => {
  const email = "reserve_case@example.com";
  const username = "reserved_case_1";

  const before = await httpJson<{ available: boolean }>(
    baseUrl,
    `/api/users/username-available?username=${username}`
  );
  assert.equal(before.status, 200);
  assert.equal(before.data.available, true);

  const otpRequest = await httpJson<{ success: boolean; devCode?: string }>(
    baseUrl,
    "/api/auth/email-otp/request",
    {
      method: "POST",
      body: { email, username },
    }
  );
  assert.equal(otpRequest.status, 200);
  assert.equal(otpRequest.data.success, true);
  const otpCode = String(otpRequest.data.devCode || "");
  assert.equal(otpCode.length, 6);

  const afterReserve = await httpJson<{ available: boolean }>(
    baseUrl,
    `/api/users/username-available?username=${username}`
  );
  assert.equal(afterReserve.status, 200);
  assert.equal(afterReserve.data.available, false);

  const secondUserTry = await httpJson<{ message?: string }>(
    baseUrl,
    "/api/auth/email-otp/request",
    {
      method: "POST",
      body: { email: "other_person@example.com", username },
    }
  );
  assert.equal(secondUserTry.status, 409);

  const otpVerify = await httpJson<{ verified: boolean }>(
    baseUrl,
    "/api/auth/email-otp/verify",
    {
      method: "POST",
      body: { email, code: otpCode },
    }
  );
  assert.equal(otpVerify.status, 200);
  assert.equal(otpVerify.data.verified, true);

  const register = await httpJson<{ user: { username: string }; accessToken: string }>(
    baseUrl,
    "/api/auth/register",
    {
      method: "POST",
      body: {
        email,
        username,
        password: "SecurePass123!",
        deviceId: "reserve-device",
        deviceName: "reserve-test",
        platform: "test",
      },
    }
  );
  assert.equal(register.status, 200);
  assert.equal(register.data.user.username, username);
  assert.ok(register.data.accessToken);

  const pgLib = await import("../src/lib/pg.js");
  const normalizedRows = await pgLib.queryOne<{
    credentials: string;
    profile: string;
    stats: string;
    privacy: string;
    email: string;
  }>(
    `SELECT
       (SELECT COUNT(*)::text FROM user_credentials WHERE user_id = (SELECT id FROM users WHERE username_lower = $1)) AS credentials,
       (SELECT COUNT(*)::text FROM user_profiles WHERE user_id = (SELECT id FROM users WHERE username_lower = $1)) AS profile,
       (SELECT COUNT(*)::text FROM user_stats WHERE user_id = (SELECT id FROM users WHERE username_lower = $1)) AS stats,
       (SELECT COUNT(*)::text FROM user_privacy_settings WHERE user_id = (SELECT id FROM users WHERE username_lower = $1)) AS privacy,
       (SELECT COUNT(*)::text FROM user_emails WHERE user_id = (SELECT id FROM users WHERE username_lower = $1) AND email_normalized = $2) AS email`,
    [username, email]
  );
  assert.equal(scalarText(normalizedRows?.credentials), "1");
  assert.equal(scalarText(normalizedRows?.profile), "1");
  assert.equal(scalarText(normalizedRows?.stats), "1");
  assert.equal(scalarText(normalizedRows?.privacy), "1");
  assert.equal(scalarText(normalizedRows?.email), "1");

  const details = await httpJson<{ success: boolean }>(
    baseUrl,
    "/api/users/me/details",
    {
      method: "PUT",
      token: register.data.accessToken,
      body: {
        firstName: "Reserve",
        lastName: "Case",
        phoneCountryCode: "+91",
        phoneNumber: "9876543210",
      },
    }
  );
  assert.equal(details.status, 200);
  assert.equal(details.data.success, true);
});

test("register allows signup after reservation expiry when username is still free", async () => {
  const email = "reserve_expire_case@example.com";
  const username = "reserved_expire_1";

  const otpRequest = await httpJson<{ success: boolean; devCode?: string }>(
    baseUrl,
    "/api/auth/email-otp/request",
    {
      method: "POST",
      body: { email, username },
    }
  );
  assert.equal(otpRequest.status, 200);
  const otpCode = String(otpRequest.data.devCode || "");
  assert.equal(otpCode.length, 6);

  const otpVerify = await httpJson<{ verified: boolean }>(
    baseUrl,
    "/api/auth/email-otp/verify",
    {
      method: "POST",
      body: { email, code: otpCode },
    }
  );
  assert.equal(otpVerify.status, 200);
  assert.equal(otpVerify.data.verified, true);

  const pgLib = await import("../src/lib/pg.js");
  await pgLib.query(
    `UPDATE username_reservations SET expires_at = $2 WHERE username_lower = $1`,
    [username, new Date(Date.now() - 60_000)]
  );

  const register = await httpJson<{ user: { username: string } }>(
    baseUrl,
    "/api/auth/register",
    {
      method: "POST",
      body: {
        email,
        username,
        password: "SecurePass123!",
        deviceId: "reserve-expire-device",
        deviceName: "reserve-expire-test",
        platform: "test",
      },
    }
  );
  assert.equal(register.status, 200);
  assert.equal(register.data.user.username, username);
});

test("realtime websocket: push, ack, read-update", async () => {
  const dmCreate = await httpJson<{ conversationId: string }>(
    baseUrl,
    "/api/conversations/dm",
    {
      method: "POST",
      token: userAToken,
      body: { otherUserId: userBId },
    }
  );
  const conversationId = dmCreate.data.conversationId;
  assert.ok(conversationId);

  const socketA = new WebSocket(
    `${wsBaseUrl}/ws?token=${encodeURIComponent(userAToken)}&deviceId=device-a-ws`
  );
  const socketB = new WebSocket(
    `${wsBaseUrl}/ws?token=${encodeURIComponent(userBToken)}&deviceId=device-b-ws`
  );

  await Promise.all([once(socketA, "open"), once(socketB, "open")]);

  socketA.send(JSON.stringify({
    type: "conversation.join",
    payload: { conversationId },
  }));
  socketB.send(JSON.stringify({
    type: "conversation.subscribe",
    payload: { conversationId },
  }));

  const waitAck = waitForSocketEvent(socketA, "MESSAGE_ACK");
  const waitPush = waitForSocketEvent(socketB, "MESSAGE_PUSH");

  socketA.send(JSON.stringify({
    type: "chat.message.send",
    payload: {
      conversationId,
      body: "hello websocket integration",
      contentType: "text",
      tempId: "tmp-ws-1",
      deviceId: "device-a-ws",
    },
  }));

  const [ack, push] = await Promise.all([waitAck, waitPush]);

  assert.equal(ack.type, "MESSAGE_ACK");
  assert.equal(String(ack.payload.conversationId), conversationId);
  assert.equal(String(ack.payload.tempId), "tmp-ws-1");
  assert.ok(ack.payload.messageId);
  assert.ok(Number(ack.payload.seq) >= 1);

  assert.equal(push.type, "MESSAGE_PUSH");
  assert.equal(String(push.payload.conversationId), conversationId);
  assert.equal(String(push.payload.body), "hello websocket integration");
  assert.ok(push.payload.messageId);
  assert.equal(Number(push.payload.seq), Number(ack.payload.seq));

  const waitReadUpdate = waitForSocketEvent(socketA, "READ_UPDATE");
  socketB.send(JSON.stringify({
    type: "message.read",
    payload: {
      conversationId,
      lastReadSeq: Number(ack.payload.seq),
    },
  }));
  const readUpdate = await waitReadUpdate;
  assert.equal(readUpdate.type, "READ_UPDATE");
  assert.equal(String(readUpdate.payload.conversationId), conversationId);
  assert.equal(String(readUpdate.payload.userId), userBId);
  assert.equal(Number(readUpdate.payload.lastReadSeq), Number(ack.payload.seq));

  socketA.close();
  socketB.close();
});
