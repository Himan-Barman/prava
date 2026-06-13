export type NotificationPriority = "low" | "normal" | "high" | "critical";

export type NotificationType =
  | "FOLLOW_RECEIVED"
  | "FRIEND_REQUEST_RECEIVED"
  | "FRIEND_REQUEST_ACCEPTED"
  | "PEOPLE_YOU_MAY_KNOW"
  | "POST_LIKED"
  | "POST_REPLIED"
  | "POST_REPOSTED"
  | "POST_QUOTED"
  | "COMMENT_REPLIED"
  | "POST_MENTIONED"
  | "COMMENT_MENTIONED"
  | "DM_MESSAGE_RECEIVED"
  | "GROUP_MESSAGE_RECEIVED"
  | "GROUP_MENTION_RECEIVED"
  | "CHAT_REPLY_RECEIVED"
  | "MISSED_CALL"
  | "GROUP_INVITATION"
  | "GROUP_MEMBERSHIP_APPROVED"
  | "GROUP_ROLE_CHANGED"
  | "GROUP_ANNOUNCEMENT"
  | "NEW_LOGIN"
  | "PASSWORD_CHANGED"
  | "SUSPICIOUS_LOGIN"
  | "SESSION_REVOKED"
  | "CONTENT_REMOVED"
  | "REPORT_STATUS_UPDATED"
  | "ACCOUNT_WARNING"
  | "APPEAL_STATUS_UPDATED"
  | "SYSTEM_ANNOUNCEMENT"
  | "FEATURE_UPDATE"
  | "MAINTENANCE_NOTICE";

export type PreferenceCategory =
  | "social"
  | "posts"
  | "mentions"
  | "chat"
  | "community"
  | "security"
  | "moderation"
  | "system";

export type NotificationRenderContext = {
  actorName?: string;
  count?: number;
  title?: string;
  body?: string;
  postId?: string;
  commentId?: string;
  conversationId?: string;
  userId?: string;
  groupId?: string;
  reportId?: string;
  featureKey?: string;
};

export type NotificationDefinition = {
  type: NotificationType;
  defaultTitle: string;
  defaultBody: string;
  entityType: string | null;
  aggregationEligible: boolean;
  pushEligible: boolean;
  priority: NotificationPriority;
  preferenceCategory: PreferenceCategory;
  retentionDays: number;
  deepLink: (context: NotificationRenderContext) => string;
  render?: (context: NotificationRenderContext) => { title: string; body: string };
};

function actor(context: NotificationRenderContext): string {
  return context.actorName?.trim() || "Someone";
}

function plural(count: number, singular: string, pluralText = `${singular}s`): string {
  return count === 1 ? singular : pluralText;
}

function postLink(context: NotificationRenderContext): string {
  return context.postId ? `/posts/${context.postId}` : "/feed";
}

function commentLink(context: NotificationRenderContext): string {
  return context.postId
    ? `/posts/${context.postId}${context.commentId ? `?comment=${context.commentId}` : ""}`
    : "/feed";
}

function chatLink(context: NotificationRenderContext): string {
  return context.conversationId ? `/chats/${context.conversationId}` : "/chats";
}

function profileLink(context: NotificationRenderContext): string {
  return context.userId ? `/profile/${context.userId}` : "/friends";
}

function aggregationBody(context: NotificationRenderContext, action: string, object: string): string {
  const count = Math.max(1, Number(context.count || 1));
  if (count === 1) {
    return `${actor(context)} ${action} ${object}.`;
  }
  if (count === 2) {
    return `${actor(context)} and 1 other ${action} ${object}.`;
  }
  return `${actor(context)} and ${count - 1} others ${action} ${object}.`;
}

export const NOTIFICATION_REGISTRY: Record<NotificationType, NotificationDefinition> = {
  FOLLOW_RECEIVED: {
    type: "FOLLOW_RECEIVED",
    defaultTitle: "New follower",
    defaultBody: "Someone followed you.",
    entityType: "user",
    aggregationEligible: true,
    pushEligible: true,
    priority: "normal",
    preferenceCategory: "social",
    retentionDays: 90,
    deepLink: profileLink,
    render: (context) => ({
      title: "New follower",
      body: context.count && context.count > 1
        ? `You received ${context.count} new ${plural(context.count, "follower")}.`
        : `${actor(context)} followed you.`,
    }),
  },
  FRIEND_REQUEST_RECEIVED: {
    type: "FRIEND_REQUEST_RECEIVED",
    defaultTitle: "Friend request",
    defaultBody: "Someone sent you a friend request.",
    entityType: "user",
    aggregationEligible: true,
    pushEligible: true,
    priority: "normal",
    preferenceCategory: "social",
    retentionDays: 90,
    deepLink: () => "/friends/requests",
    render: (context) => ({ title: "Friend request", body: `${actor(context)} sent you a friend request.` }),
  },
  FRIEND_REQUEST_ACCEPTED: {
    type: "FRIEND_REQUEST_ACCEPTED",
    defaultTitle: "Friend request accepted",
    defaultBody: "Your friend request was accepted.",
    entityType: "user",
    aggregationEligible: false,
    pushEligible: true,
    priority: "normal",
    preferenceCategory: "social",
    retentionDays: 90,
    deepLink: profileLink,
    render: (context) => ({ title: "Friend request accepted", body: `${actor(context)} accepted your friend request.` }),
  },
  PEOPLE_YOU_MAY_KNOW: {
    type: "PEOPLE_YOU_MAY_KNOW",
    defaultTitle: "People you may know",
    defaultBody: "Discover people connected to your network.",
    entityType: "user",
    aggregationEligible: true,
    pushEligible: false,
    priority: "low",
    preferenceCategory: "social",
    retentionDays: 30,
    deepLink: () => "/friends/discover",
  },
  POST_LIKED: {
    type: "POST_LIKED",
    defaultTitle: "New like",
    defaultBody: "Someone liked your post.",
    entityType: "post",
    aggregationEligible: true,
    pushEligible: true,
    priority: "normal",
    preferenceCategory: "posts",
    retentionDays: 90,
    deepLink: postLink,
    render: (context) => ({ title: "New like", body: aggregationBody(context, "liked", "your post") }),
  },
  POST_REPLIED: {
    type: "POST_REPLIED",
    defaultTitle: "New reply",
    defaultBody: "Someone replied to your post.",
    entityType: "post",
    aggregationEligible: true,
    pushEligible: true,
    priority: "normal",
    preferenceCategory: "posts",
    retentionDays: 90,
    deepLink: commentLink,
    render: (context) => ({ title: "New reply", body: `${actor(context)} replied to your post.` }),
  },
  POST_REPOSTED: {
    type: "POST_REPOSTED",
    defaultTitle: "New repost",
    defaultBody: "Someone reposted your post.",
    entityType: "post",
    aggregationEligible: true,
    pushEligible: true,
    priority: "normal",
    preferenceCategory: "posts",
    retentionDays: 90,
    deepLink: postLink,
    render: (context) => ({ title: "New repost", body: aggregationBody(context, "reposted", "your post") }),
  },
  POST_QUOTED: {
    type: "POST_QUOTED",
    defaultTitle: "New quote",
    defaultBody: "Someone quoted your post.",
    entityType: "post",
    aggregationEligible: true,
    pushEligible: true,
    priority: "normal",
    preferenceCategory: "posts",
    retentionDays: 90,
    deepLink: postLink,
    render: (context) => ({ title: "New quote", body: `${actor(context)} quoted your post.` }),
  },
  COMMENT_REPLIED: {
    type: "COMMENT_REPLIED",
    defaultTitle: "Comment reply",
    defaultBody: "Someone replied to your comment.",
    entityType: "comment",
    aggregationEligible: true,
    pushEligible: true,
    priority: "normal",
    preferenceCategory: "posts",
    retentionDays: 90,
    deepLink: commentLink,
    render: (context) => ({ title: "Comment reply", body: `${actor(context)} replied to your comment.` }),
  },
  POST_MENTIONED: {
    type: "POST_MENTIONED",
    defaultTitle: "You were mentioned",
    defaultBody: "Someone mentioned you in a post.",
    entityType: "post",
    aggregationEligible: false,
    pushEligible: true,
    priority: "high",
    preferenceCategory: "mentions",
    retentionDays: 90,
    deepLink: postLink,
    render: (context) => ({ title: "You were mentioned", body: `${actor(context)} mentioned you in a post.` }),
  },
  COMMENT_MENTIONED: {
    type: "COMMENT_MENTIONED",
    defaultTitle: "You were mentioned",
    defaultBody: "Someone mentioned you in a comment.",
    entityType: "comment",
    aggregationEligible: false,
    pushEligible: true,
    priority: "high",
    preferenceCategory: "mentions",
    retentionDays: 90,
    deepLink: commentLink,
    render: (context) => ({ title: "You were mentioned", body: `${actor(context)} mentioned you in a comment.` }),
  },
  DM_MESSAGE_RECEIVED: {
    type: "DM_MESSAGE_RECEIVED",
    defaultTitle: "New message",
    defaultBody: "You have a new message.",
    entityType: "conversation",
    aggregationEligible: true,
    pushEligible: true,
    priority: "high",
    preferenceCategory: "chat",
    retentionDays: 30,
    deepLink: chatLink,
    render: (context) => ({
      title: actor(context),
      body: context.count && context.count > 1
        ? `${actor(context)} sent you ${context.count} messages.`
        : (context.body || "Sent you a message."),
    }),
  },
  GROUP_MESSAGE_RECEIVED: {
    type: "GROUP_MESSAGE_RECEIVED",
    defaultTitle: "New group message",
    defaultBody: "There are new messages in a group.",
    entityType: "conversation",
    aggregationEligible: true,
    pushEligible: true,
    priority: "normal",
    preferenceCategory: "chat",
    retentionDays: 30,
    deepLink: chatLink,
    render: (context) => ({
      title: context.title || "Group message",
      body: context.count && context.count > 1
        ? `${context.count} new messages in ${context.title || "a group"}.`
        : `${actor(context)}: ${context.body || "New message"}`,
    }),
  },
  GROUP_MENTION_RECEIVED: {
    type: "GROUP_MENTION_RECEIVED",
    defaultTitle: "Group mention",
    defaultBody: "Someone mentioned you in a group.",
    entityType: "conversation",
    aggregationEligible: false,
    pushEligible: true,
    priority: "high",
    preferenceCategory: "chat",
    retentionDays: 45,
    deepLink: chatLink,
    render: (context) => ({ title: context.title || "Group mention", body: `${actor(context)} mentioned you.` }),
  },
  CHAT_REPLY_RECEIVED: {
    type: "CHAT_REPLY_RECEIVED",
    defaultTitle: "Chat reply",
    defaultBody: "Someone replied to your message.",
    entityType: "conversation",
    aggregationEligible: false,
    pushEligible: true,
    priority: "high",
    preferenceCategory: "chat",
    retentionDays: 45,
    deepLink: chatLink,
    render: (context) => ({ title: "Chat reply", body: `${actor(context)} replied to your message.` }),
  },
  MISSED_CALL: {
    type: "MISSED_CALL",
    defaultTitle: "Missed call",
    defaultBody: "You missed a call.",
    entityType: "conversation",
    aggregationEligible: true,
    pushEligible: true,
    priority: "high",
    preferenceCategory: "chat",
    retentionDays: 30,
    deepLink: chatLink,
  },
  GROUP_INVITATION: {
    type: "GROUP_INVITATION",
    defaultTitle: "Group invitation",
    defaultBody: "You were invited to a group.",
    entityType: "group",
    aggregationEligible: false,
    pushEligible: true,
    priority: "normal",
    preferenceCategory: "community",
    retentionDays: 90,
    deepLink: (context) => context.groupId ? `/groups/${context.groupId}` : "/groups",
  },
  GROUP_MEMBERSHIP_APPROVED: {
    type: "GROUP_MEMBERSHIP_APPROVED",
    defaultTitle: "Group request approved",
    defaultBody: "Your group join request was approved.",
    entityType: "group",
    aggregationEligible: false,
    pushEligible: true,
    priority: "normal",
    preferenceCategory: "community",
    retentionDays: 90,
    deepLink: (context) => context.groupId ? `/groups/${context.groupId}` : "/groups",
  },
  GROUP_ROLE_CHANGED: {
    type: "GROUP_ROLE_CHANGED",
    defaultTitle: "Group role updated",
    defaultBody: "Your group role changed.",
    entityType: "group",
    aggregationEligible: false,
    pushEligible: true,
    priority: "normal",
    preferenceCategory: "community",
    retentionDays: 90,
    deepLink: (context) => context.groupId ? `/groups/${context.groupId}` : "/groups",
  },
  GROUP_ANNOUNCEMENT: {
    type: "GROUP_ANNOUNCEMENT",
    defaultTitle: "Group announcement",
    defaultBody: "There is a new group announcement.",
    entityType: "group",
    aggregationEligible: true,
    pushEligible: true,
    priority: "normal",
    preferenceCategory: "community",
    retentionDays: 60,
    deepLink: (context) => context.groupId ? `/groups/${context.groupId}` : "/groups",
  },
  NEW_LOGIN: {
    type: "NEW_LOGIN",
    defaultTitle: "New login",
    defaultBody: "Your account was accessed from a new session.",
    entityType: "security",
    aggregationEligible: false,
    pushEligible: true,
    priority: "critical",
    preferenceCategory: "security",
    retentionDays: 365,
    deepLink: () => "/settings/security",
  },
  PASSWORD_CHANGED: {
    type: "PASSWORD_CHANGED",
    defaultTitle: "Password changed",
    defaultBody: "Your password was changed.",
    entityType: "security",
    aggregationEligible: false,
    pushEligible: true,
    priority: "critical",
    preferenceCategory: "security",
    retentionDays: 365,
    deepLink: () => "/settings/security",
  },
  SUSPICIOUS_LOGIN: {
    type: "SUSPICIOUS_LOGIN",
    defaultTitle: "Suspicious login",
    defaultBody: "We detected unusual login activity.",
    entityType: "security",
    aggregationEligible: false,
    pushEligible: true,
    priority: "critical",
    preferenceCategory: "security",
    retentionDays: 365,
    deepLink: () => "/settings/security",
  },
  SESSION_REVOKED: {
    type: "SESSION_REVOKED",
    defaultTitle: "Session revoked",
    defaultBody: "A session was revoked from your account.",
    entityType: "security",
    aggregationEligible: false,
    pushEligible: true,
    priority: "critical",
    preferenceCategory: "security",
    retentionDays: 365,
    deepLink: () => "/settings/security",
  },
  CONTENT_REMOVED: {
    type: "CONTENT_REMOVED",
    defaultTitle: "Content removed",
    defaultBody: "One of your items was removed.",
    entityType: "moderation",
    aggregationEligible: false,
    pushEligible: true,
    priority: "high",
    preferenceCategory: "moderation",
    retentionDays: 365,
    deepLink: () => "/settings/account-status",
  },
  REPORT_STATUS_UPDATED: {
    type: "REPORT_STATUS_UPDATED",
    defaultTitle: "Report updated",
    defaultBody: "A report status changed.",
    entityType: "report",
    aggregationEligible: false,
    pushEligible: true,
    priority: "normal",
    preferenceCategory: "moderation",
    retentionDays: 180,
    deepLink: (context) => context.reportId ? `/support/reports/${context.reportId}` : "/support",
  },
  ACCOUNT_WARNING: {
    type: "ACCOUNT_WARNING",
    defaultTitle: "Account warning",
    defaultBody: "Your account received a warning.",
    entityType: "moderation",
    aggregationEligible: false,
    pushEligible: true,
    priority: "critical",
    preferenceCategory: "moderation",
    retentionDays: 365,
    deepLink: () => "/settings/account-status",
  },
  APPEAL_STATUS_UPDATED: {
    type: "APPEAL_STATUS_UPDATED",
    defaultTitle: "Appeal updated",
    defaultBody: "Your appeal status changed.",
    entityType: "moderation",
    aggregationEligible: false,
    pushEligible: true,
    priority: "normal",
    preferenceCategory: "moderation",
    retentionDays: 365,
    deepLink: () => "/support/appeals",
  },
  SYSTEM_ANNOUNCEMENT: {
    type: "SYSTEM_ANNOUNCEMENT",
    defaultTitle: "Prava update",
    defaultBody: "There is a new announcement.",
    entityType: "system",
    aggregationEligible: false,
    pushEligible: true,
    priority: "normal",
    preferenceCategory: "system",
    retentionDays: 120,
    deepLink: () => "/notifications",
    render: (context) => ({
      title: context.title || "Prava update",
      body: context.body || "There is a new announcement.",
    }),
  },
  FEATURE_UPDATE: {
    type: "FEATURE_UPDATE",
    defaultTitle: "New feature",
    defaultBody: "A new Prava feature is available.",
    entityType: "system",
    aggregationEligible: false,
    pushEligible: true,
    priority: "low",
    preferenceCategory: "system",
    retentionDays: 90,
    deepLink: (context) => context.featureKey ? `/features/${context.featureKey}` : "/notifications",
  },
  MAINTENANCE_NOTICE: {
    type: "MAINTENANCE_NOTICE",
    defaultTitle: "Maintenance notice",
    defaultBody: "Prava maintenance is scheduled.",
    entityType: "system",
    aggregationEligible: false,
    pushEligible: true,
    priority: "normal",
    preferenceCategory: "system",
    retentionDays: 45,
    deepLink: () => "/notifications",
  },
};

export const PREFERENCE_CATEGORIES: PreferenceCategory[] = [
  "social",
  "posts",
  "mentions",
  "chat",
  "community",
  "security",
  "moderation",
  "system",
];

export const LEGACY_NOTIFICATION_TYPE_MAP: Record<string, NotificationType> = {
  follow: "FOLLOW_RECEIVED",
  "relationship.follow": "FOLLOW_RECEIVED",
  like: "POST_LIKED",
  "post.like": "POST_LIKED",
  comment: "POST_REPLIED",
  reply: "COMMENT_REPLIED",
  share: "POST_REPOSTED",
  mention: "POST_MENTIONED",
  chat: "DM_MESSAGE_RECEIVED",
  system: "SYSTEM_ANNOUNCEMENT",
};

export function normalizeNotificationType(value: unknown): NotificationType {
  const raw = String(value || "").trim();
  const upper = raw.toUpperCase();
  if (upper in NOTIFICATION_REGISTRY) {
    return upper as NotificationType;
  }
  return LEGACY_NOTIFICATION_TYPE_MAP[raw] || "SYSTEM_ANNOUNCEMENT";
}

export function getNotificationDefinition(type: unknown): NotificationDefinition {
  return NOTIFICATION_REGISTRY[normalizeNotificationType(type)];
}

export function renderNotification(
  type: unknown,
  context: NotificationRenderContext
): { title: string; body: string; deepLink: string } {
  const definition = getNotificationDefinition(type);
  const rendered = definition.render?.(context) || {
    title: context.title || definition.defaultTitle,
    body: context.body || definition.defaultBody,
  };
  return {
    title: rendered.title.slice(0, 160),
    body: rendered.body.slice(0, 500),
    deepLink: definition.deepLink(context),
  };
}
