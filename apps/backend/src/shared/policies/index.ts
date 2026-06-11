import { queryOne } from "../../lib/pg.js";

type PolicyResult = {
  allowed: boolean;
  reason?: string;
};

function allow(): PolicyResult {
  return { allowed: true };
}

function deny(reason: string): PolicyResult {
  return { allowed: false, reason };
}

export async function hasBlockBetween(a: string, b: string): Promise<boolean> {
  const row = await queryOne(
    `SELECT 1
     FROM user_blocks
     WHERE (blocker_id = $1 AND blocked_id = $2)
        OR (blocker_id = $2 AND blocked_id = $1)
     LIMIT 1`,
    [a, b]
  );
  return !!row;
}

export async function canViewProfile(viewerId: string, targetUserId: string): Promise<PolicyResult> {
  if (viewerId === targetUserId) return allow();
  if (await hasBlockBetween(viewerId, targetUserId)) return deny("blocked");
  return allow();
}

export async function canFollow(viewerId: string, targetUserId: string): Promise<PolicyResult> {
  if (viewerId === targetUserId) return deny("self_follow");
  if (await hasBlockBetween(viewerId, targetUserId)) return deny("blocked");
  return allow();
}

export async function canSendDirectMessage(senderId: string, recipientId: string): Promise<PolicyResult> {
  if (senderId === recipientId) return deny("self_message");
  if (await hasBlockBetween(senderId, recipientId)) return deny("blocked");
  return allow();
}

export async function canViewPost(viewerId: string, postId: string): Promise<PolicyResult> {
  const row = await queryOne(
    `SELECT author_id, deleted_at, moderation_state
     FROM posts
     WHERE post_id = $1`,
    [postId]
  );
  if (!row || row.deleted_at) return deny("not_found");
  if (row.moderation_state && row.moderation_state !== "active") return deny("moderated");
  if (row.author_id !== viewerId && await hasBlockBetween(viewerId, row.author_id)) return deny("blocked");
  return allow();
}

export async function canViewConversation(userId: string, conversationId: string): Promise<PolicyResult> {
  const row = await queryOne(
    `SELECT 1
     FROM conversation_members
     WHERE conversation_id = $1
       AND user_id = $2
       AND left_at IS NULL`,
    [conversationId, userId]
  );
  return row ? allow() : deny("not_member");
}

export async function canModerate(actorId: string): Promise<PolicyResult> {
  const row = await queryOne(
    `SELECT role
     FROM users
     WHERE user_id = $1
       AND deleted_at IS NULL`,
    [actorId]
  );
  return ["admin", "moderator", "super_admin", "support"].includes(String(row?.role || ""))
    ? allow()
    : deny("missing_permission");
}
