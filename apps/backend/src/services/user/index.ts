import { requireAuth } from "../../lib/auth.js";
import { query, queryMany, queryOne, withTransaction } from "../../lib/pg.js";
import {
  HttpError,
  ensure,
  generateId,
  isValidEmail,
  isValidUsername,
  normalizeEmail,
  normalizeUsername,
  now,
  toIso,
  verifyPassword,
} from "../../lib/security.js";
import { enqueueNotificationEvent } from "../notification/repository.js";

const PROFILE_VISIBILITY_VALUES = [
  "public",
  "everyone",
  "followers",
  "friends",
  "closeFriends",
  "onlyMe",
  "hidden",
] as const;
type ProfileVisibility = (typeof PROFILE_VISIBILITY_VALUES)[number];
type ProfileVisibilityMap = Record<string, ProfileVisibility>;

const DEFAULT_PROFILE_VISIBILITY: ProfileVisibilityMap = {
  displayName: "public",
  username: "public",
  avatar: "public",
  cover: "public",
  bio: "public",
  location: "friends",
  website: "public",
  joined: "public",
  posts: "public",
  replies: "public",
  media: "public",
  highlights: "public",
  about: "public",
  friends: "friends",
  followers: "public",
  following: "public",
  onlineStatus: "friends",
  lastActive: "friends",
  likes: "onlyMe",
  saved: "onlyMe",
  drafts: "onlyMe",
  archive: "onlyMe",
  hiddenPosts: "onlyMe",
  analytics: "onlyMe",
};

const DEFAULT_SETTINGS = {
  privateAccount: false,
  profileVisibility: DEFAULT_PROFILE_VISIBILITY,
  activityStatus: true,
  readReceipts: true,
  messagePreview: true,
  sensitiveContent: false,
  locationSharing: false,
  twoFactor: false,
  loginAlerts: true,
  appLock: false,
  biometrics: true,
  pushNotifications: true,
  emailNotifications: false,
  inAppSounds: true,
  inAppHaptics: true,
  notifyPosts: true,
  notifyChats: true,
  notifyMentions: true,
  notifyFollows: true,
  dataSaver: false,
  autoDownload: true,
  autoPlayVideos: true,
  reduceMotion: false,
  themeIndex: 0,
  textScale: 1,
  languageLabel: "English",
};

const USERNAME_CHANGE_COOLDOWN_MONTHS = 3;

const FALLBACK_LOCATIONS = [
  { city: "Kolkata", state: "West Bengal", country: "India" },
  { city: "Dinhata", state: "West Bengal", country: "India" },
  { city: "Siliguri", state: "West Bengal", country: "India" },
  { city: "Guwahati", state: "Assam", country: "India" },
  { city: "Bengaluru", state: "Karnataka", country: "India" },
  { city: "Mumbai", state: "Maharashtra", country: "India" },
  { city: "Delhi", state: "Delhi", country: "India" },
  { city: "Hyderabad", state: "Telangana", country: "India" },
  { city: "Chennai", state: "Tamil Nadu", country: "India" },
  { city: "Pune", state: "Maharashtra", country: "India" },
  { city: "London", state: "England", country: "United Kingdom" },
  { city: "New York", state: "New York", country: "United States" },
];

function mapLocationSuggestion(city: string, state: string, country: string) {
  const parts = [city, state, country].filter(Boolean);
  return {
    city,
    state,
    country,
    label: parts.join(", "),
  };
}

function fallbackLocationSuggestions(query: string, limit: number) {
  const q = query.trim().toLowerCase();
  const items = q.length < 2
    ? FALLBACK_LOCATIONS
    : FALLBACK_LOCATIONS.filter((item) =>
        [item.city, item.state, item.country]
          .join(" ")
          .toLowerCase()
          .includes(q)
      );
  return items
    .slice(0, limit)
    .map((item) => mapLocationSuggestion(item.city, item.state, item.country));
}

async function externalLocationSuggestions(query: string, limit: number) {
  if (query.trim().length < 2) return [];

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 2500);
  try {
    const url = new URL("https://nominatim.openstreetmap.org/search");
    url.searchParams.set("format", "jsonv2");
    url.searchParams.set("addressdetails", "1");
    url.searchParams.set("limit", String(limit));
    url.searchParams.set("q", query);

    const response = await fetch(url, {
      signal: controller.signal,
      headers: {
        "User-Agent": "Prava/1.0 location suggestions",
      },
    });
    if (!response.ok) return [];
    const data = await response.json();
    if (!Array.isArray(data)) return [];

    return data
      .map((item: any) => {
        const address = item?.address || {};
        const city = String(
          address.city ||
            address.town ||
            address.village ||
            address.hamlet ||
            address.municipality ||
            ""
        ).trim();
        const state = String(address.state || address.region || "").trim();
        const country = String(address.country || "").trim();
        if (!city && !state && !country) return null;
        return mapLocationSuggestion(city || String(item.name || "").trim(), state, country);
      })
      .filter(Boolean)
      .slice(0, limit);
  } catch {
    return [];
  } finally {
    clearTimeout(timeout);
  }
}

function normalizeVisibilityValue(
  value: unknown,
  fallback: ProfileVisibility
): ProfileVisibility {
  if (
    typeof value === "string" &&
    PROFILE_VISIBILITY_VALUES.includes(value as ProfileVisibility)
  ) {
    return value as ProfileVisibility;
  }
  return fallback;
}

function canonicalVisibility(value: ProfileVisibility): ProfileVisibility {
  return value === "everyone" ? "public" : value;
}

function normalizeProfileVisibility(value: unknown): ProfileVisibilityMap {
  const incoming =
    value && typeof value === "object" ? (value as Record<string, unknown>) : {};
  return Object.fromEntries(
    Object.entries(DEFAULT_PROFILE_VISIBILITY).map(([key, fallback]) => [
      key,
      normalizeVisibilityValue(incoming[key], fallback),
    ])
  ) as ProfileVisibilityMap;
}

function mergeSettings(value: any = {}) {
  const profileVisibility = normalizeProfileVisibility(value?.profileVisibility);
  return {
    ...DEFAULT_SETTINGS,
    ...(value || {}),
    profileVisibility,
  };
}

async function shouldCreateNotification(userId: string, categoryKey: string) {
  const row = await queryOne(
    `SELECT settings FROM user_settings WHERE user_id = $1`,
    [userId]
  );
  const settings = mergeSettings(row?.settings || {});
  return settings.pushNotifications !== false && settings[categoryKey] !== false;
}

type ProfileRelationship = {
  state: string;
  isSelf: boolean;
  isFollowing: boolean;
  isFollowedBy: boolean;
  isFriend: boolean;
  isCloseFriend: boolean;
  requestPending: boolean;
  incomingRequestPending: boolean;
  isBlockedByViewer: boolean;
  hasBlockedViewer: boolean;
  isMuted: boolean;
  isRestricted: boolean;
};

type ProfileAction = {
  key: string;
  label: string;
  style: string;
  enabled: boolean;
};

type ProfileTab = {
  key: string;
  label: string;
  visible: boolean;
  ownerOnly: boolean;
};

function minVisibility(
  current: ProfileVisibility,
  minimum: ProfileVisibility
): ProfileVisibility {
  const rank: Record<ProfileVisibility, number> = {
    public: 0,
    everyone: 0,
    followers: 1,
    friends: 2,
    closeFriends: 3,
    onlyMe: 4,
    hidden: 5,
  };
  return rank[current] < rank[minimum] ? minimum : current;
}

function canViewByVisibility(
  visibility: ProfileVisibility,
  relationship: ProfileRelationship
): boolean {
  if (relationship.isSelf) return true;
  const level = canonicalVisibility(visibility);
  if (level === "public") return true;
  if (visibility === "followers") return relationship.isFollowing;
  if (visibility === "friends") return relationship.isFriend;
  if (visibility === "closeFriends") return relationship.isCloseFriend;
  return false;
}

function buildProfileVisibility(
  settings: any,
  relationship: ProfileRelationship
) {
  const profileVisibility = normalizeProfileVisibility(settings?.profileVisibility);
  const restrictedAccount =
    settings?.privateAccount &&
    !relationship.isSelf &&
    !relationship.isFollowing &&
    !relationship.isFriend &&
    !relationship.isCloseFriend;
  const effectiveVisibility = restrictedAccount
    ? {
        ...profileVisibility,
        posts: minVisibility(profileVisibility.posts, "followers"),
        replies: minVisibility(profileVisibility.replies, "followers"),
        media: minVisibility(profileVisibility.media, "followers"),
        highlights: minVisibility(profileVisibility.highlights, "followers"),
        followers: minVisibility(profileVisibility.followers, "followers"),
        following: minVisibility(profileVisibility.following, "followers"),
      }
    : profileVisibility;

  const visible = Object.fromEntries(
    Object.entries(effectiveVisibility).map(([key, value]) => [
      key,
      canViewByVisibility(value, relationship),
    ])
  );

  return {
    fields: effectiveVisibility,
    visible,
    privateAccount: settings?.privateAccount === true,
    restricted: restrictedAccount,
  };
}

function parseLimit(raw: unknown, fallback: number, min: number, max: number): number {
  const parsed = Number.parseInt(String(raw || ""), 10);
  if (Number.isNaN(parsed)) {
    return fallback;
  }
  return Math.max(min, Math.min(max, parsed));
}

function escapeLike(value: string): string {
  return value.replace(/[\\%_]/g, (char) => `\\${char}`);
}

function escapeRegex(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function normalizeProfileResourceVisibility(value: unknown): ProfileVisibility {
  return normalizeVisibilityValue(value, "public");
}

function normalizeUrl(value: unknown): string {
  const raw = String(value || "").trim();
  if (!raw) return "";
  try {
    const url = new URL(raw.startsWith("http://") || raw.startsWith("https://") ? raw : `https://${raw}`);
    ensure(["http:", "https:"].includes(url.protocol), 400, "Invalid URL");
    return url.toString();
  } catch {
    throw new HttpError(400, "Invalid URL");
  }
}

function stringList(value: unknown, limit = 20): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => String(item || "").trim())
    .filter(Boolean)
    .slice(0, limit);
}

function nextUsernameChangeDate(value: unknown): Date | null {
  if (!value) {
    return null;
  }
  const changedAt = value instanceof Date ? value : new Date(value as string | number);
  if (Number.isNaN(changedAt.getTime())) {
    return null;
  }
  const next = new Date(changedAt);
  next.setMonth(next.getMonth() + USERNAME_CHANGE_COOLDOWN_MONTHS);
  return next;
}

function mentionReplacePattern(username: string): string {
  return `(^|[^a-zA-Z0-9_.])@${escapeRegex(username)}([^a-zA-Z0-9_.]|$)`;
}

async function ensureUserExists(userId: string): Promise<void> {
  const user = await queryOne(
    `SELECT user_id FROM users WHERE user_id = $1 AND deleted_at IS NULL`,
    [userId]
  );
  if (!user) {
    throw new HttpError(404, "User not found");
  }
}

async function ensureNotBlocked(a: string, b: string): Promise<void> {
  const block = await queryOne(
    `SELECT 1
     FROM user_blocks
     WHERE (blocker_id = $1 AND blocked_id = $2)
        OR (blocker_id = $2 AND blocked_id = $1)
     LIMIT 1`,
    [a, b]
  );
  if (block) {
    throw new HttpError(403, "User interaction is blocked");
  }
}

function mapProfilePost(post: any) {
  return {
    id: post.post_id,
    body: post.body,
    createdAt: toIso(post.created_at),
    likeCount: Number(post.like_count || 0),
    commentCount: Number(post.comment_count || 0),
    shareCount: Number(post.share_count || 0),
    readCount: Number(post.read_count || post.impression_count || 0),
    mediaUrls: Array.isArray(post.media_urls) ? post.media_urls : [],
    postType: post.post_type || "post",
    parentPostId: post.parent_post_id || null,
    mentions: Array.isArray(post.mentions) ? post.mentions : [],
    hashtags: Array.isArray(post.hashtags) ? post.hashtags : [],
  };
}

function mapProfileTag(row: any) {
  return {
    tag: row.tag,
    postCount: Number(row.post_count || 0),
    rankScore: Number(row.rank_score || 0),
    lastPostAt: toIso(row.last_post_at),
  };
}

function mapProfileMention(row: any) {
  return {
    username: row.username,
    postCount: Number(row.post_count || 0),
    rankScore: Number(row.rank_score || 0),
    lastPostAt: toIso(row.last_post_at),
  };
}

async function buildProfileTags(userId: string, limit: number) {
  return queryMany(
    `SELECT pt.tag,
            COUNT(*)::int AS post_count,
            MAX(pt.created_at) AS last_post_at,
            (COUNT(*)::int * 10 + COALESCE(MAX(ts.post_count), 0)) AS rank_score
     FROM post_tags pt
     LEFT JOIN tag_stats ts ON ts.tag = pt.tag
     WHERE pt.author_id = $1
     GROUP BY pt.tag
     ORDER BY rank_score DESC, last_post_at DESC
     LIMIT $2`,
    [userId, limit]
  );
}

async function buildProfileMentions(userId: string, limit: number) {
  const rows = await queryMany(
    `SELECT mentions, created_at
     FROM posts
     WHERE author_id = $1
     ORDER BY created_at DESC`,
    [userId]
  );
  const aggregate = new Map<string, { username: string; post_count: number; last_post_at: Date; rank_score: number }>();

  for (const row of rows) {
    const mentions = Array.isArray(row.mentions) ? row.mentions : [];
    const createdAt = new Date(row.created_at);
    for (const raw of mentions) {
      const username = String(raw || "")
        .trim()
        .replace(/^@/, "")
        .toLowerCase();
      if (!username) continue;

      const existing = aggregate.get(username);
      if (!existing) {
        aggregate.set(username, {
          username,
          post_count: 1,
          last_post_at: createdAt,
          rank_score: 10,
        });
        continue;
      }

      existing.post_count += 1;
      existing.rank_score += 10;
      if (createdAt > existing.last_post_at) {
        existing.last_post_at = createdAt;
      }
    }
  }

  return [...aggregate.values()]
    .sort((a, b) => b.rank_score - a.rank_score || b.last_post_at.getTime() - a.last_post_at.getTime())
    .slice(0, limit);
}

async function buildMentionedPosts(username: string, limit: number) {
  const normalized = normalizeUsername(username);
  if (!normalized) return [];
  const mentionPattern = `(^|\\s)@${escapeRegex(normalized)}([^a-zA-Z0-9_.]|$)`;

  return queryMany(
    `SELECT *
     FROM posts
     WHERE mentions ? $1
        OR mentions ? $2
        OR body ~* $3
     ORDER BY created_at DESC
     LIMIT $4`,
    [normalized, `@${normalized}`, mentionPattern, limit]
  );
}

function mapConnectionItem(user: any, rel: any) {
  return {
    id: user.user_id,
    username: user.username,
    displayName: user.display_name || user.username,
    bio: user.bio || "",
    location: user.location || "",
    avatarUrl: user.avatar_url || "",
    isVerified: user.is_verified === true,
    isOnline: false,
    lastSeenAt: toIso(user.last_seen_at),
    createdAt: toIso(user.created_at),
    since: rel?.since ? toIso(rel.since) : null,
    isFollowing: rel?.isFollowing === true,
    isFollowedBy: rel?.isFollowedBy === true,
  };
}

async function loadUsersByIds(ids: string[]): Promise<any[]> {
  if (!ids || ids.length === 0) {
    return [];
  }

  return queryMany(
    `SELECT user_id, username, display_name, bio, location, avatar_url, is_verified, last_seen_at, created_at
     FROM users
     WHERE user_id = ANY($1::text[]) AND deleted_at IS NULL`,
    [ids]
  );
}

async function buildStats(userId: string) {
  const stats = await queryOne(
    `SELECT
       (SELECT COUNT(*)::int FROM posts WHERE author_id = $1 AND deleted_at IS NULL AND COALESCE(visibility, 'public') <> 'draft') AS posts,
       (SELECT COUNT(*)::int FROM posts WHERE author_id = $1 AND deleted_at IS NULL AND post_type = 'reply') AS replies,
       (SELECT COUNT(*)::int FROM posts WHERE author_id = $1 AND deleted_at IS NULL AND COALESCE(media_urls, '[]'::jsonb) <> '[]'::jsonb) AS media,
       (SELECT COUNT(*)::int FROM follows WHERE following_id = $1) AS followers,
       (SELECT COUNT(*)::int FROM follows WHERE follower_id = $1) AS following,
       (SELECT COUNT(*)::int
        FROM follows f1
        JOIN follows f2 ON f2.follower_id = f1.following_id AND f2.following_id = f1.follower_id
        WHERE f1.follower_id = $1) AS friends,
       (SELECT COUNT(*)::int FROM close_friends WHERE owner_id = $1) AS close_friends,
       (SELECT COALESCE(SUM(like_count), 0)::int FROM posts WHERE author_id = $1) AS likes`,
    [userId]
  );

  return {
    posts: Number(stats?.posts || 0),
    replies: Number(stats?.replies || 0),
    media: Number(stats?.media || 0),
    followers: Number(stats?.followers || 0),
    following: Number(stats?.following || 0),
    friends: Number(stats?.friends || 0),
    closeFriends: Number(stats?.close_friends || 0),
    likes: Number(stats?.likes || 0),
  };
}

async function buildOwnerCounts(userId: string) {
  const counts = await queryOne(
    `SELECT
       (SELECT COUNT(*)::int FROM post_saves WHERE user_id = $1) AS saved,
       (SELECT COUNT(*)::int FROM posts WHERE author_id = $1 AND COALESCE(visibility, '') = 'draft') AS drafts,
       (SELECT COUNT(*)::int FROM posts WHERE author_id = $1 AND COALESCE(visibility, '') = 'archived') AS archive,
       (SELECT COUNT(*)::int FROM post_hidden WHERE user_id = $1) AS hidden_posts,
       (SELECT COUNT(*)::int FROM profile_views WHERE profile_user_id = $1) AS profile_viewers,
       (SELECT COALESCE(SUM(view_count), 0)::int FROM profile_views WHERE profile_user_id = $1) AS profile_views`,
    [userId]
  );
  return {
    saved: Number(counts?.saved || 0),
    drafts: Number(counts?.drafts || 0),
    archive: Number(counts?.archive || 0),
    hiddenPosts: Number(counts?.hidden_posts || 0),
    profileViewers: Number(counts?.profile_viewers || 0),
    profileViews: Number(counts?.profile_views || 0),
  };
}

async function buildMutualFriends(viewerUserId: string, targetUserId: string, limit = 3) {
  if (viewerUserId === targetUserId) {
    return { count: 0, items: [] };
  }
  const rows = await queryMany(
    `WITH viewer_friends AS (
       SELECT f1.following_id AS user_id
       FROM follows f1
       JOIN follows f2 ON f2.follower_id = f1.following_id AND f2.following_id = f1.follower_id
       WHERE f1.follower_id = $1
     ),
     target_friends AS (
       SELECT f1.following_id AS user_id
       FROM follows f1
       JOIN follows f2 ON f2.follower_id = f1.following_id AND f2.following_id = f1.follower_id
       WHERE f1.follower_id = $2
     ),
     mutual AS (
       SELECT vf.user_id
       FROM viewer_friends vf
       JOIN target_friends tf ON tf.user_id = vf.user_id
     )
     SELECT u.user_id, u.username, u.display_name, u.avatar_url, u.is_verified,
            (SELECT COUNT(*) FROM mutual)::int AS total_count
     FROM mutual m
     JOIN users u ON u.user_id = m.user_id AND u.deleted_at IS NULL
     ORDER BY u.is_verified DESC, u.display_name_lower ASC
     LIMIT $3`,
    [viewerUserId, targetUserId, limit]
  );
  return {
    count: Number(rows[0]?.total_count || 0),
    items: rows.map((row) => ({
      id: row.user_id,
      username: row.username,
      displayName: row.display_name || row.username,
      avatarUrl: row.avatar_url || "",
      isVerified: row.is_verified === true,
    })),
  };
}

function relationshipState(relationship: ProfileRelationship): string {
  if (relationship.isSelf) return "self";
  if (relationship.isBlockedByViewer) return "blockedByViewer";
  if (relationship.hasBlockedViewer) return "blocked";
  if (relationship.isRestricted) return "restricted";
  if (relationship.isCloseFriend) return "closeFriend";
  if (relationship.isFriend) return "friend";
  if (relationship.requestPending) return "requestPending";
  if (relationship.isFollowing) return "follower";
  if (relationship.isFollowedBy) return "following";
  return "nonFollower";
}

function buildProfileActions(
  relationship: ProfileRelationship,
  visibility: any,
  settings: any
) {
  if (relationship.hasBlockedViewer) {
    return [];
  }
  if (relationship.isBlockedByViewer) {
    return [
      { key: "unblock", label: "Unblock", style: "danger", enabled: true },
    ];
  }
  if (relationship.isSelf) {
    return [
      { key: "editProfile", label: "Edit Profile", style: "primary", enabled: true },
      { key: "shareProfile", label: "Share Profile", style: "subtle", enabled: true },
      { key: "settings", label: "Settings", style: "subtle", enabled: true },
      { key: "analytics", label: "View Analytics", style: "subtle", enabled: true },
      { key: "previewAs", label: "Preview As", style: "subtle", enabled: true },
    ];
  }

  const actions: ProfileAction[] = [];
  if (visibility.restricted && relationship.requestPending) {
    actions.push({ key: "cancelRequest", label: "Requested", style: "subtle", enabled: true });
  } else if (visibility.restricted) {
    actions.push({ key: "requestFollow", label: "Request Follow", style: "primary", enabled: true });
  } else if (relationship.isFriend) {
    actions.push({ key: "friends", label: "Friends", style: "subtle", enabled: true });
  } else if (relationship.isFollowing) {
    actions.push({ key: "following", label: "Following", style: "subtle", enabled: true });
  } else if (relationship.requestPending) {
    actions.push({ key: "cancelRequest", label: "Requested", style: "subtle", enabled: true });
  } else {
    actions.push({
      key: relationship.isFollowedBy ? "followBack" : "follow",
      label: relationship.isFollowedBy ? "Follow back" : "Follow",
      style: "primary",
      enabled: true,
    });
  }

  const canMessage =
    settings?.messagePreview !== false &&
    (relationship.isFriend || relationship.isFollowing || settings?.privateAccount !== true);
  if (canMessage) {
    actions.push({ key: "message", label: "Message", style: "subtle", enabled: true });
  }
  actions.push({ key: "shareProfile", label: "Share", style: "icon", enabled: true });
  actions.push({ key: "more", label: "More", style: "icon", enabled: true });
  return actions;
}

function buildProfileTabs(relationship: ProfileRelationship, visibility: any, badges: any[] = []) {
  if (relationship.hasBlockedViewer || relationship.isBlockedByViewer) {
    return [];
  }
  if (visibility.restricted && !relationship.isSelf) {
    return [];
  }
  const can = (key: string) => visibility?.visible?.[key] === true || relationship.isSelf;
  const tabs: ProfileTab[] = [
    { key: "posts", label: "Posts", visible: can("posts"), ownerOnly: false },
    { key: "replies", label: "Replies", visible: can("replies"), ownerOnly: false },
    { key: "media", label: "Media", visible: can("media"), ownerOnly: false },
    { key: "highlights", label: "Highlights", visible: can("highlights"), ownerOnly: false },
    { key: "about", label: "About", visible: can("about"), ownerOnly: false },
    { key: "friends", label: "Friends", visible: can("friends"), ownerOnly: false },
    { key: "badges", label: "Badges", visible: badges.length > 0, ownerOnly: false },
  ].filter((tab) => tab.visible);

  if (relationship.isSelf) {
    tabs.push(
      { key: "saved", label: "Saved", visible: true, ownerOnly: true },
      { key: "drafts", label: "Drafts", visible: true, ownerOnly: true },
      { key: "archive", label: "Archive", visible: true, ownerOnly: true },
      { key: "hidden", label: "Hidden", visible: true, ownerOnly: true },
      { key: "analytics", label: "Analytics", visible: true, ownerOnly: true }
    );
  }

  return tabs;
}

function completionScore(user: any, settings: any): number {
  const checks = [
    Boolean(user.avatar_url),
    Boolean(user.cover_url),
    Boolean(user.bio),
    Boolean(user.website),
    Boolean(user.location),
    Boolean(user.display_name),
    settings?.privateAccount !== undefined,
  ];
  const done = checks.filter(Boolean).length;
  return Math.round((done / checks.length) * 100);
}

async function recordProfileView(viewerUserId: string, targetUserId: string) {
  if (viewerUserId === targetUserId) return;
  await query(
    `INSERT INTO profile_views (viewer_id, profile_user_id, view_count, first_viewed_at, last_viewed_at)
     VALUES ($1, $2, 1, $3, $3)
     ON CONFLICT (viewer_id, profile_user_id)
     DO UPDATE SET view_count = profile_views.view_count + 1,
                   last_viewed_at = EXCLUDED.last_viewed_at`,
    [viewerUserId, targetUserId, now()]
  );
}

async function buildProfileCollections(
  userId: string,
  limit: number,
  relationship: ProfileRelationship
) {
  const [badges, links, highlights, pinnedRows] = await Promise.all([
    queryMany(
      `SELECT badge_id, badge_type, label, icon, awarded_at, expires_at, visibility
       FROM profile_badges
       WHERE user_id = $1
         AND (expires_at IS NULL OR expires_at > NOW())
       ORDER BY awarded_at DESC
       LIMIT $2`,
      [userId, limit]
    ),
    queryMany(
      `SELECT link_id, title, url, position, visibility
       FROM profile_links
       WHERE user_id = $1
       ORDER BY position ASC, created_at DESC
       LIMIT $2`,
      [userId, limit]
    ),
    queryMany(
      `SELECT highlight_id, title, description, cover_url, post_ids, media_urls, position, visibility, created_at
       FROM profile_highlights
       WHERE user_id = $1
       ORDER BY position ASC, created_at DESC
       LIMIT $2`,
      [userId, limit]
    ),
    queryMany(
      `SELECT p.*
       FROM profile_pinned_posts pp
       JOIN posts p ON p.post_id = pp.post_id
       WHERE pp.user_id = $1 AND p.deleted_at IS NULL
       ORDER BY pp.position ASC, pp.pinned_at DESC
       LIMIT $2`,
      [userId, Math.min(limit, 5)]
    ),
  ]);

  return {
    badges: badges
      .filter((row) => canViewByVisibility(normalizeProfileResourceVisibility(row.visibility), relationship))
      .map((row) => ({
        id: row.badge_id,
        type: row.badge_type,
        label: row.label,
        icon: row.icon || "",
        awardedAt: toIso(row.awarded_at),
        expiresAt: toIso(row.expires_at),
      })),
    links: links
      .filter((row) => canViewByVisibility(normalizeProfileResourceVisibility(row.visibility), relationship))
      .map((row) => ({
        id: row.link_id,
        title: row.title || "",
        url: row.url || "",
        position: Number(row.position || 0),
        visibility: row.visibility || "public",
      })),
    highlights: highlights
      .filter((row) => canViewByVisibility(normalizeProfileResourceVisibility(row.visibility), relationship))
      .map((row) => ({
        id: row.highlight_id,
        title: row.title || "",
        description: row.description || "",
        coverUrl: row.cover_url || "",
        postIds: Array.isArray(row.post_ids) ? row.post_ids : [],
        mediaUrls: Array.isArray(row.media_urls) ? row.media_urls : [],
        position: Number(row.position || 0),
        visibility: row.visibility || "public",
        createdAt: toIso(row.created_at),
      })),
    pinnedPosts: pinnedRows.map(mapProfilePost),
  };
}

async function buildProfileSummary(
  viewerUserId: string,
  targetUserId: string,
  limit: number,
  previewAs = ""
) {
  const user = await queryOne(
    `SELECT *
     FROM users
     WHERE user_id = $1 AND deleted_at IS NULL`,
    [targetUserId]
  );
  if (!user) {
    throw new HttpError(404, "User not found");
  }

  const realSelf = viewerUserId === targetUserId;
  const previewMode = realSelf && ["public", "follower", "friend", "closeFriend"].includes(previewAs)
    ? previewAs
    : "";
  const isSelf = realSelf && !previewMode;
  const [
    settingsDoc,
    isFollowing,
    isFollowedBy,
    requestPending,
    incomingRequestPending,
    blockedByViewer,
    hasBlockedViewer,
    closeFriend,
    muted,
    restricted,
  ] = await Promise.all([
    queryOne(
      `SELECT settings FROM user_settings WHERE user_id = $1`,
      [targetUserId]
    ),
    isSelf
      ? Promise.resolve(null)
      : queryOne(
          `SELECT 1 FROM follows WHERE follower_id = $1 AND following_id = $2`,
          [viewerUserId, targetUserId]
        ),
    isSelf
      ? Promise.resolve(null)
      : queryOne(
          `SELECT 1 FROM follows WHERE follower_id = $1 AND following_id = $2`,
          [targetUserId, viewerUserId]
        ),
    isSelf
      ? Promise.resolve(null)
      : queryOne(
          `SELECT 1 FROM follow_requests WHERE requester_id = $1 AND target_id = $2 AND status = 'pending'`,
          [viewerUserId, targetUserId]
        ),
    isSelf
      ? Promise.resolve(null)
      : queryOne(
          `SELECT 1 FROM follow_requests WHERE requester_id = $1 AND target_id = $2 AND status = 'pending'`,
          [targetUserId, viewerUserId]
        ),
    isSelf
      ? Promise.resolve(null)
      : queryOne(
          `SELECT 1 FROM user_blocks WHERE blocker_id = $1 AND blocked_id = $2`,
          [viewerUserId, targetUserId]
        ),
    isSelf
      ? Promise.resolve(null)
      : queryOne(
          `SELECT 1 FROM user_blocks WHERE blocker_id = $1 AND blocked_id = $2`,
          [targetUserId, viewerUserId]
        ),
    isSelf
      ? Promise.resolve(null)
      : queryOne(
          `SELECT 1 FROM close_friends WHERE owner_id = $1 AND user_id = $2`,
          [targetUserId, viewerUserId]
        ),
    isSelf
      ? Promise.resolve(null)
      : queryOne(
          `SELECT 1 FROM user_mutes WHERE muter_id = $1 AND muted_id = $2`,
          [viewerUserId, targetUserId]
        ),
    isSelf
      ? Promise.resolve(null)
      : queryOne(
          `SELECT 1 FROM restricted_users WHERE owner_id = $1 AND restricted_id = $2`,
          [targetUserId, viewerUserId]
        ),
  ]);
  const relationship: ProfileRelationship = {
    state: "",
    isSelf,
    isFollowing: !!isFollowing,
    isFollowedBy: !!isFollowedBy,
    isFriend: !!isFollowing && !!isFollowedBy,
    isCloseFriend: !!closeFriend,
    requestPending: !!requestPending,
    incomingRequestPending: !!incomingRequestPending,
    isBlockedByViewer: !!blockedByViewer,
    hasBlockedViewer: !!hasBlockedViewer,
    isMuted: !!muted,
    isRestricted: !!restricted,
  };
  if (previewMode) {
    relationship.isFollowing = ["follower", "friend", "closeFriend"].includes(previewMode);
    relationship.isFollowedBy = ["friend", "closeFriend"].includes(previewMode);
    relationship.isFriend = ["friend", "closeFriend"].includes(previewMode);
    relationship.isCloseFriend = previewMode === "closeFriend";
    relationship.requestPending = false;
    relationship.incomingRequestPending = false;
    relationship.isBlockedByViewer = false;
    relationship.hasBlockedViewer = false;
    relationship.isMuted = false;
    relationship.isRestricted = false;
  }
  relationship.state = relationshipState(relationship);
  const settings = mergeSettings(settingsDoc?.settings || {});
  const visibility = buildProfileVisibility(settings, relationship);
  const visible = visibility.visible as Record<string, boolean>;
  const details = user.details || {};
  const blocked = relationship.isBlockedByViewer || relationship.hasBlockedViewer;

  const [
    stats,
    ownerCounts,
    collections,
    mutualFriends,
    posts,
    replies,
    mediaPosts,
    tags,
    mentions,
    mentionedPosts,
    analyticsRow,
  ] = await Promise.all([
    buildStats(targetUserId),
    isSelf ? buildOwnerCounts(targetUserId) : Promise.resolve({
      saved: 0,
      drafts: 0,
      archive: 0,
      hiddenPosts: 0,
      profileViewers: 0,
      profileViews: 0,
    }),
    blocked ? Promise.resolve({
      badges: [],
      links: [],
      highlights: [],
      pinnedPosts: [],
    }) : buildProfileCollections(targetUserId, limit, relationship),
    blocked ? Promise.resolve({ count: 0, items: [] }) : buildMutualFriends(viewerUserId, targetUserId, 3),
    visible.posts && !blocked
      ? queryMany(
          `SELECT *
           FROM posts
           WHERE author_id = $1
             AND deleted_at IS NULL
             AND COALESCE(visibility, 'public') NOT IN ('draft', 'archived')
             AND (post_type IS NULL OR post_type = 'post')
           ORDER BY created_at DESC
           LIMIT $2`,
          [targetUserId, limit]
        )
      : Promise.resolve([]),
    visible.replies && !blocked
      ? queryMany(
          `SELECT *
           FROM posts
           WHERE author_id = $1
             AND deleted_at IS NULL
             AND (post_type = 'reply' OR parent_post_id IS NOT NULL)
           ORDER BY created_at DESC
           LIMIT $2`,
          [targetUserId, limit]
        )
      : Promise.resolve([]),
    visible.media && !blocked
      ? queryMany(
          `SELECT *
           FROM posts
           WHERE author_id = $1
             AND deleted_at IS NULL
             AND COALESCE(media_urls, '[]'::jsonb) <> '[]'::jsonb
           ORDER BY created_at DESC
           LIMIT $2`,
          [targetUserId, limit]
        )
      : Promise.resolve([]),
    visible.posts && !blocked ? buildProfileTags(targetUserId, limit) : Promise.resolve([]),
    visible.posts && !blocked ? buildProfileMentions(targetUserId, limit) : Promise.resolve([]),
    isSelf ? buildMentionedPosts(user.username, limit) : Promise.resolve([]),
    isSelf
      ? queryOne(
          `SELECT
             (SELECT COALESCE(SUM(impression_count), 0)::int FROM posts WHERE author_id = $1) AS post_reach,
             (SELECT COUNT(*)::int FROM follows WHERE following_id = $1 AND created_at > NOW() - INTERVAL '30 days') AS new_followers,
             (SELECT COALESCE(SUM(like_count + comment_count + share_count), 0)::int FROM posts WHERE author_id = $1) AS engagement,
             (SELECT post_id FROM posts WHERE author_id = $1 AND deleted_at IS NULL ORDER BY impression_count DESC, created_at DESC LIMIT 1) AS most_viewed_post_id`,
          [targetUserId]
        )
      : Promise.resolve(null),
  ]);
  if (!blocked) {
    await recordProfileView(viewerUserId, targetUserId);
  }

  const badges = collections.badges;
  const actions = buildProfileActions(relationship, visibility, settings);
  const tabs = buildProfileTabs(relationship, visibility, badges);
  const restrictedReasons: string[] = [];
  if (visibility.restricted) {
    restrictedReasons.push("private_account");
  }
  if (blocked) {
    restrictedReasons.push(relationship.isBlockedByViewer ? "blocked_by_viewer" : "blocked");
  }

  const summary = {
    profileState: relationship.hasBlockedViewer
      ? "blocked"
      : relationship.isBlockedByViewer
      ? "blockedByViewer"
      : visibility.restricted
      ? "private"
      : "public",
    user: {
      id: user.user_id,
      username: user.username,
      displayName: user.display_name || user.username,
      bio: !blocked && visible.bio ? (user.bio || "") : "",
      location: !blocked && visible.location ? (user.location || "") : "",
      website: !blocked && visible.website ? (user.website || "") : "",
      avatarUrl: relationship.hasBlockedViewer ? "" : (user.avatar_url || ""),
      avatarBlurhash: details.avatarBlurhash || "",
      coverUrl: !blocked && visible.cover ? (user.cover_url || "") : "",
      coverBlurhash: details.coverBlurhash || "",
      themeAccentColor: details.themeAccentColor || "",
      profileGradient: details.profileGradient || "",
      profileBadgeStyle: details.profileBadgeStyle || "",
      profileLayoutType: details.profileLayoutType || "social",
      pinnedDetails: !blocked ? (details.pinnedDetails || "") : "",
      category: !blocked ? (details.category || "") : "",
      aiCreator: !blocked && details.aiCreator === true,
      hometown: !blocked && visible.location ? (details.hometown || "") : "",
      phoneCountryCode: isSelf ? (details.phoneCountryCode || "") : "",
      phoneNumber: isSelf ? (details.phoneNumber || "") : "",
      isVerified: user.is_verified === true,
      verificationType: details.verificationType || (user.is_verified ? "verified" : ""),
      accountType: details.accountType || "personal",
      accountStatus: details.accountStatus || "active",
      onlineStatus: !blocked && visible.onlineStatus && settings.activityStatus !== false
        ? (new Date().getTime() - new Date(user.last_seen_at).getTime() < 5 * 60 * 1000 ? "online" : "offline")
        : "",
      lastActiveAt: !blocked && visible.lastActive && settings.activityStatus !== false ? toIso(user.last_seen_at) : null,
      createdAt: !blocked && visible.joined ? toIso(user.created_at) : null,
    },
    stats: {
      posts: !blocked && visible.posts ? stats.posts : 0,
      replies: !blocked && visible.replies ? stats.replies : 0,
      media: !blocked && visible.media ? stats.media : 0,
      followers: !blocked && visible.followers ? stats.followers : 0,
      following: !blocked && visible.following ? stats.following : 0,
      friends: !blocked && visible.friends ? stats.friends : 0,
      mutualFriends: !blocked ? mutualFriends.count : 0,
      closeFriends: isSelf ? stats.closeFriends : 0,
      likes: isSelf || visible.likes ? stats.likes : 0,
      saved: isSelf ? ownerCounts.saved : 0,
      drafts: isSelf ? ownerCounts.drafts : 0,
      archive: isSelf ? ownerCounts.archive : 0,
      hiddenPosts: isSelf ? ownerCounts.hiddenPosts : 0,
    },
    posts: posts.map(mapProfilePost),
    replies: replies.map(mapProfilePost),
    mediaPosts: mediaPosts.map(mapProfilePost),
    tags: tags.map(mapProfileTag),
    mentions: mentions.map(mapProfileMention),
    mentionedPosts: mentionedPosts.map(mapProfilePost),
    mutualFriends: mutualFriends.items,
    badges,
    links: blocked ? [] : collections.links,
    highlights: !blocked && visible.highlights ? collections.highlights : [],
    pinnedPosts: !blocked && visible.posts ? collections.pinnedPosts : [],
    viewerRelation: relationship.state,
    viewer_relation: relationship.state,
    visibility,
    relationship,
    actions,
    tabs,
    contentPreview: {
      pinnedPosts: !blocked && visible.posts ? collections.pinnedPosts : [],
      recentPosts: posts.slice(0, Math.min(posts.length, 3)).map(mapProfilePost),
      highlights: !blocked && visible.highlights ? collections.highlights.slice(0, 5) : [],
    },
    privacyRestrictions: restrictedReasons,
    privacy_restrictions: restrictedReasons,
  };

  if (isSelf) {
    const [likedPosts, savedPosts, draftPosts, archivedPosts, hiddenPosts] = await Promise.all([
      queryMany(
        `SELECT p.*
         FROM post_likes pl
         JOIN posts p ON p.post_id = pl.post_id
         WHERE pl.user_id = $1
         ORDER BY pl.created_at DESC
         LIMIT $2`,
        [targetUserId, limit]
      ),
      queryMany(
        `SELECT p.*
         FROM post_saves ps
         JOIN posts p ON p.post_id = ps.post_id
         WHERE ps.user_id = $1
         ORDER BY ps.created_at DESC
         LIMIT $2`,
        [targetUserId, limit]
      ),
      queryMany(
        `SELECT *
         FROM posts
         WHERE author_id = $1 AND COALESCE(visibility, '') = 'draft'
         ORDER BY updated_at DESC
         LIMIT $2`,
        [targetUserId, limit]
      ),
      queryMany(
        `SELECT *
         FROM posts
         WHERE author_id = $1 AND COALESCE(visibility, '') = 'archived'
         ORDER BY updated_at DESC
         LIMIT $2`,
        [targetUserId, limit]
      ),
      queryMany(
        `SELECT p.*
         FROM post_hidden ph
         JOIN posts p ON p.post_id = ph.post_id
         WHERE ph.user_id = $1
         ORDER BY ph.created_at DESC
         LIMIT $2`,
        [targetUserId, limit]
      ),
    ]);

    return {
      ...summary,
      liked: likedPosts.map(mapProfilePost),
      saved: savedPosts.map(mapProfilePost),
      drafts: draftPosts.map(mapProfilePost),
      archive: archivedPosts.map(mapProfilePost),
      hidden: hiddenPosts.map(mapProfilePost),
      ownerTools: {
        completion: {
          score: completionScore(user, settings),
          missing: [
            !user.avatar_url ? "avatar" : "",
            !user.cover_url ? "cover" : "",
            !user.bio ? "bio" : "",
            !user.website ? "website" : "",
            !user.location ? "location" : "",
          ].filter(Boolean),
        },
        accountHealth: {
          status: user.is_verified ? "trusted" : "good",
          label: user.is_verified ? "Verified account" : "Good standing",
          risk: "low",
        },
        verification: {
          verified: user.is_verified === true,
          type: details.verificationType || "",
        },
        privacyCheckup: {
          privateAccount: settings.privateAccount === true,
          activityStatus: settings.activityStatus !== false,
          visibleFields: Object.entries(visibility.visible).filter(([, value]) => value).length,
        },
        analytics: {
          profileViews: ownerCounts.profileViews,
          profileViewers: ownerCounts.profileViewers,
          postReach: Number(analyticsRow?.post_reach || 0),
          newFollowers: Number(analyticsRow?.new_followers || 0),
          engagement: Number(analyticsRow?.engagement || 0),
          mostViewedPostId: analyticsRow?.most_viewed_post_id || "",
          growthTrend: Number(analyticsRow?.new_followers || 0) >= 0 ? "up" : "flat",
        },
        shortcuts: [
          { key: "saved", label: "Saved posts", count: ownerCounts.saved },
          { key: "drafts", label: "Drafts", count: ownerCounts.drafts },
          { key: "archive", label: "Archived posts", count: ownerCounts.archive },
          { key: "hidden", label: "Hidden posts", count: ownerCounts.hiddenPosts },
          { key: "blocked", label: "Blocked users", count: 0 },
          { key: "closeFriends", label: "Close friends", count: stats.closeFriends },
        ],
        previewModes: ["public", "follower", "friend", "closeFriend"],
      },
    };
  }

  return {
    ...summary,
  };
}

function accountPayload(user: any) {
  const details = user.details || {};
  const nextUsernameChange = nextUsernameChangeDate(user.username_changed_at);
  const canChangeUsername = !nextUsernameChange || now() >= nextUsernameChange;
  return {
    id: user.user_id,
    email: user.email,
    username: user.username,
    displayName: user.display_name || user.username,
    firstName: details.firstName || "",
    lastName: details.lastName || "",
    phoneCountryCode: details.phoneCountryCode || "",
    phoneNumber: details.phoneNumber || "",
    bio: user.bio || "",
    location: user.location || "",
    website: user.website || "",
    avatarUrl: user.avatar_url || "",
    coverUrl: user.cover_url || "",
    pinnedDetails: details.pinnedDetails || "",
    category: details.category || "",
    aiCreator: details.aiCreator === true,
    hometown: details.hometown || "",
    isVerified: user.is_verified === true,
    emailVerifiedAt: toIso(user.email_verified_at),
    usernameChangedAt: toIso(user.username_changed_at),
    nextUsernameChangeAt: toIso(nextUsernameChange),
    canChangeUsername,
    createdAt: toIso(user.created_at),
    updatedAt: toIso(user.updated_at),
  };
}

export default async function userService(app: any) {
  app.get("/me", { preHandler: requireAuth }, async (request: any) => {
    return { userId: request.user.userId };
  });

  app.get("/username-available", {
    schema: {
      querystring: {
        type: "object",
        required: ["username"],
        properties: {
          username: { type: "string", minLength: 1, maxLength: 64 },
          email: { type: "string", minLength: 3, maxLength: 255 },
        },
      },
    },
  }, async (request: any) => {
    try {
      const username = normalizeUsername(request.query?.username);
      ensure(isValidUsername(username), 400, "Invalid username");
      const emailLower = normalizeEmail(request.query?.email);
      const hasEmail = isValidEmail(emailLower);
      const ts = now();

      const existing = await queryOne(
        `SELECT user_id FROM users WHERE username_lower = $1`,
        [username]
      );
      if (existing) {
        return { available: false };
      }

      const reservation = await queryOne(
        `SELECT email_lower, expires_at
         FROM username_reservations
         WHERE username_lower = $1 AND expires_at > $2`,
        [username, ts]
      );

      if (!reservation) {
        return { available: true };
      }

      if (hasEmail && reservation.email_lower === emailLower) {
        return {
          available: true,
          reservedByRequester: true,
        };
      }

      return { available: false };
    } catch (error) {
      if (error instanceof HttpError) {
        throw error;
      }
      request.log.error({ err: error }, "username availability check failed");
      throw new HttpError(503, "Username check temporarily unavailable");
    }
  });

  app.put("/me/details", { preHandler: requireAuth }, async (request: any) => {
    const body = request.body || {};
    const firstName = String(body.firstName || "").trim();
    const lastName = String(body.lastName || "").trim();
    const phoneCountryCode = String(body.phoneCountryCode || "").trim();
    const phoneNumber = String(body.phoneNumber || "").trim();

    ensure(firstName.length > 0 && firstName.length <= 64, 400, "Invalid first name");
    ensure(lastName.length > 0 && lastName.length <= 64, 400, "Invalid last name");

    const ts = now();
    const displayName = `${firstName} ${lastName}`.trim();

    const existing = await queryOne(
      `SELECT details FROM users WHERE user_id = $1`,
      [request.user.userId]
    );
    if (!existing) {
      throw new HttpError(404, "User not found");
    }

    const nextDetails = {
      ...(existing.details || {}),
      firstName,
      lastName,
      phoneCountryCode,
      phoneNumber,
    };

    await query(
      `UPDATE users
       SET details = $2,
           display_name = $3,
           display_name_lower = $4,
           updated_at = $5
       WHERE user_id = $1`,
      [
        request.user.userId,
        JSON.stringify(nextDetails),
        displayName,
        displayName.toLowerCase(),
        ts,
      ]
    );

    return { success: true };
  });

  app.put("/me/profile-details", { preHandler: requireAuth }, async (request: any) => {
    const body = request.body || {};
    const profileDetails: Record<string, unknown> = {};
    const fields: string[] = [];
    const params: unknown[] = [request.user.userId];

    const setField = (column: string, value: unknown) => {
      params.push(value);
      fields.push(`${column} = $${params.length}`);
    };

    if (body.bio !== undefined) {
      setField("bio", String(body.bio || "").trim().slice(0, 2000));
    }

    if (body.location !== undefined) {
      setField("location", String(body.location || "").trim().slice(0, 120));
    }

    if (body.website !== undefined) {
      setField("website", String(body.website || "").trim().slice(0, 240));
    }

    if (body.pinnedDetails !== undefined) {
      profileDetails.pinnedDetails = String(body.pinnedDetails || "").trim().slice(0, 240);
    }

    if (body.category !== undefined) {
      profileDetails.category = String(body.category || "").trim().slice(0, 80);
    }

    if (body.aiCreator !== undefined) {
      profileDetails.aiCreator = body.aiCreator === true;
    }

    if (body.hometown !== undefined) {
      profileDetails.hometown = String(body.hometown || "").trim().slice(0, 120);
    }

    if (body.phoneCountryCode !== undefined) {
      profileDetails.phoneCountryCode = String(body.phoneCountryCode || "").trim().slice(0, 8);
    }

    if (body.phoneNumber !== undefined) {
      profileDetails.phoneNumber = String(body.phoneNumber || "").trim().slice(0, 32);
    }

    if (Object.keys(profileDetails).length > 0) {
      const existing = await queryOne(
        `SELECT details FROM users WHERE user_id = $1`,
        [request.user.userId]
      );
      if (!existing) {
        throw new HttpError(404, "User not found");
      }
      setField("details", JSON.stringify({
        ...(existing.details || {}),
        ...profileDetails,
      }));
    }

    ensure(fields.length > 0, 400, "No profile changes supplied");
    setField("updated_at", now());

    await query(
      `UPDATE users SET ${fields.join(", ")} WHERE user_id = $1`,
      params
    );

    const user = await queryOne(`SELECT * FROM users WHERE user_id = $1`, [request.user.userId]);
    if (!user) {
      throw new HttpError(404, "User not found");
    }

    return { profile: accountPayload(user) };
  });

  app.put("/me/profile-media", { preHandler: requireAuth }, async (request: any) => {
    const body = request.body || {};
    const avatarUrl = body.avatarUrl === undefined
      ? undefined
      : String(body.avatarUrl || "").trim().slice(0, 1000);
    const coverUrl = body.coverUrl === undefined
      ? undefined
      : String(body.coverUrl || "").trim().slice(0, 1000);

    ensure(avatarUrl !== undefined || coverUrl !== undefined, 400, "No media changes supplied");

    const fields: string[] = [];
    const params: unknown[] = [request.user.userId];
    if (avatarUrl !== undefined) {
      params.push(avatarUrl);
      fields.push(`avatar_url = $${params.length}`);
    }
    if (coverUrl !== undefined) {
      params.push(coverUrl);
      fields.push(`cover_url = $${params.length}`);
    }
    params.push(now());
    fields.push(`updated_at = $${params.length}`);

    await query(
      `UPDATE users SET ${fields.join(", ")} WHERE user_id = $1`,
      params
    );

    const user = await queryOne(`SELECT * FROM users WHERE user_id = $1`, [request.user.userId]);
    if (!user) {
      throw new HttpError(404, "User not found");
    }

    return { profile: accountPayload(user) };
  });

  app.get("/me/account", { preHandler: requireAuth }, async (request: any) => {
    const user = await queryOne(`SELECT * FROM users WHERE user_id = $1`, [request.user.userId]);
    if (!user) {
      throw new HttpError(404, "User not found");
    }

    return { account: accountPayload(user) };
  });

  app.put("/me/email", { preHandler: requireAuth }, async (request: any) => {
    const emailLower = normalizeEmail(request.body?.email);
    ensure(isValidEmail(emailLower), 400, "Invalid email");

    const duplicate = await queryOne(
      `SELECT user_id FROM users WHERE email_lower = $1 AND user_id <> $2`,
      [emailLower, request.user.userId]
    );
    if (duplicate) {
      throw new HttpError(409, "Email already exists");
    }

    const ts = now();
    try {
      await query(
        `UPDATE users
         SET email = $2,
             email_lower = $2,
             is_verified = FALSE,
             email_verified_at = NULL,
             updated_at = $3
         WHERE user_id = $1`,
        [request.user.userId, emailLower, ts]
      );
    } catch (error: any) {
      if (error.code === "23505") {
        throw new HttpError(409, "Email already exists");
      }
      throw error;
    }

    return {
      email: emailLower,
      isVerified: false,
      emailVerifiedAt: null,
    };
  });

  app.put("/me/handle", { preHandler: requireAuth }, async (request: any) => {
    const body = request.body || {};
    const requestedUsername = body.username === undefined
      ? undefined
      : normalizeUsername(body.username);
    if (requestedUsername !== undefined) {
      ensure(isValidUsername(requestedUsername), 400, "Invalid username");
    }

    const updatedUser = await withTransaction(async (client) => {
      const currentResult = await client.query(
        `SELECT * FROM users WHERE user_id = $1 FOR UPDATE`,
        [request.user.userId]
      );
      const currentUser = currentResult.rows[0];
      if (!currentUser) {
        throw new HttpError(404, "User not found");
      }

      const fields: string[] = [];
      const params: unknown[] = [request.user.userId];
      const ts = now();

      const setField = (column: string, value: unknown) => {
        params.push(value);
        fields.push(`${column} = $${params.length}`);
      };

      if (requestedUsername !== undefined && requestedUsername !== currentUser.username_lower) {
        const password = String(body.password || "");
        ensure(password.length > 0, 400, "Password is required");
        ensure(verifyPassword(password, currentUser.password_hash), 401, "Password is incorrect");

        const nextChange = nextUsernameChangeDate(currentUser.username_changed_at);
        if (nextChange && ts < nextChange) {
          throw new HttpError(
            429,
            `Username can be changed again after ${nextChange.toISOString()}`
          );
        }

        const duplicate = await client.query(
          `SELECT user_id FROM users WHERE username_lower = $1 AND user_id <> $2`,
          [requestedUsername, request.user.userId]
        );
        if ((duplicate.rowCount ?? 0) > 0) {
          throw new HttpError(409, "Username already exists");
        }

        const reservation = await client.query(
          `SELECT email_lower
           FROM username_reservations
           WHERE username_lower = $1
             AND expires_at > $2
             AND email_lower <> $3
           LIMIT 1`,
          [requestedUsername, ts, currentUser.email_lower]
        );
        if ((reservation.rowCount ?? 0) > 0) {
          throw new HttpError(409, "Username is reserved");
        }

        const oldUsername = normalizeUsername(currentUser.username_lower || currentUser.username);
        const oldUsernameWithAt = `@${oldUsername}`;
        const pattern = mentionReplacePattern(oldUsername);
        const replacement = `\\1@${requestedUsername}\\2`;

        setField("username", requestedUsername);
        setField("username_lower", requestedUsername);
        setField("username_changed_at", ts);

        await client.query(
          `UPDATE posts
           SET body = regexp_replace(body, $1, $2, 'gi'),
               mentions = COALESCE(
                 (
                   SELECT jsonb_agg(
                     CASE
                       WHEN lower(item.value) = $3 OR lower(item.value) = $6 THEN to_jsonb($4::text)
                       ELSE to_jsonb(item.value)
                     END
                   )
                   FROM jsonb_array_elements_text(posts.mentions) AS item(value)
                 ),
                 '[]'::jsonb
               ),
               updated_at = $5
           WHERE body ~* $1 OR mentions ? $3 OR mentions ? $6`,
          [pattern, replacement, oldUsername, requestedUsername, ts, oldUsernameWithAt]
        );

        await client.query(
          `UPDATE comments
           SET body = regexp_replace(body, $1, $2, 'gi')
           WHERE body ~* $1`,
          [pattern, replacement]
        );

        await client.query(
          `UPDATE messages
           SET body = regexp_replace(body, $1, $2, 'gi'),
               updated_at = $3
           WHERE body ~* $1`,
          [pattern, replacement, ts]
        );

        await client.query(
          `UPDATE conversations
           SET last_message_body = regexp_replace(last_message_body, $1, $2, 'gi'),
               updated_at = $3
           WHERE last_message_body ~* $1`,
          [pattern, replacement, ts]
        );

        await client.query(
          `DELETE FROM username_reservations WHERE username_lower = $1`,
          [requestedUsername]
        );
      }

      if (body.displayName !== undefined) {
        const displayName = String(body.displayName || "").trim();
        ensure(displayName.length > 0 && displayName.length <= 120, 400, "Invalid display name");
        setField("display_name", displayName);
        setField("display_name_lower", displayName.toLowerCase());
      }

      if (body.bio !== undefined) {
        setField("bio", String(body.bio || "").trim().slice(0, 2000));
      }

      if (body.location !== undefined) {
        setField("location", String(body.location || "").trim().slice(0, 120));
      }

      if (body.website !== undefined) {
        setField("website", String(body.website || "").trim().slice(0, 240));
      }

      setField("updated_at", ts);

      try {
        await client.query(
          `UPDATE users SET ${fields.join(", ")} WHERE user_id = $1`,
          params
        );
      } catch (error: any) {
        if (error.code === "23505") {
          throw new HttpError(409, "Username already exists");
        }
        throw error;
      }

      const updatedResult = await client.query(`SELECT * FROM users WHERE user_id = $1`, [request.user.userId]);
      return updatedResult.rows[0];
    });

    if (!updatedUser) {
      throw new HttpError(404, "User not found");
    }
    return { profile: accountPayload(updatedUser) };
  });

  app.delete("/me", { preHandler: requireAuth }, async (request: any) => {
    const ts = now();
    const userId = request.user.userId;

    await Promise.all([
      query(
        `UPDATE users SET deleted_at = $2, updated_at = $2 WHERE user_id = $1`,
        [userId, ts]
      ),
      query(
        `UPDATE refresh_tokens SET revoked_at = $2 WHERE user_id = $1 AND revoked_at IS NULL`,
        [userId, ts]
      ),
    ]);

    return { success: true };
  });

  app.get("/search", { preHandler: requireAuth }, async (request: any) => {
    const search = String(request.query?.query || "").trim().toLowerCase().replace(/^@+/, "");
    if (search.length > 0 && !/^[a-z0-9_.]+$/.test(search)) {
      return { results: [] };
    }

    const limit = parseLimit(request.query?.limit, 20, 1, 25);
    const includeSelf = String(request.query?.includeSelf || "") === "true";
    const prefix = `${escapeLike(search)}%`;
    const rows =
      search.length === 0
        ? await queryMany(
            `SELECT user_id, username, display_name, avatar_url, is_verified
             FROM users
             WHERE ($2::boolean OR user_id <> $1)
               AND deleted_at IS NULL
             ORDER BY is_verified DESC, created_at DESC
             LIMIT $3`,
            [request.user.userId, includeSelf, limit]
          )
        : await queryMany(
            `SELECT user_id, username, display_name, avatar_url, is_verified
             FROM users
             WHERE ($3::boolean OR user_id <> $1)
               AND deleted_at IS NULL
               AND (username_lower LIKE $2 ESCAPE '\\' OR display_name_lower LIKE $2 ESCAPE '\\')
             ORDER BY username_lower ASC
             LIMIT $4`,
            [request.user.userId, prefix, includeSelf, limit]
          );

    if (rows.length === 0) {
      return { results: [] };
    }

    const ids = rows.map((row) => row.user_id);
    const [following, followedBy] = await Promise.all([
      queryMany(
        `SELECT following_id
         FROM follows
         WHERE follower_id = $1 AND following_id = ANY($2::text[])`,
        [request.user.userId, ids]
      ),
      queryMany(
        `SELECT follower_id
         FROM follows
         WHERE follower_id = ANY($1::text[]) AND following_id = $2`,
        [ids, request.user.userId]
      ),
    ]);

    const followingSet = new Set(following.map((item) => item.following_id));
    const followedBySet = new Set(followedBy.map((item) => item.follower_id));

    return {
      results: rows.map((row) => ({
        id: row.user_id,
        username: row.username,
        displayName: row.display_name || row.username,
        avatarUrl: row.avatar_url || "",
        isVerified: row.is_verified === true,
        isFollowing: followingSet.has(row.user_id),
        isFollowedBy: followedBySet.has(row.user_id),
      })),
    };
  });

  app.get("/smart-search", { preHandler: requireAuth }, async (request: any) => {
    const raw = String(request.query?.query || "")
      .trim()
      .toLowerCase()
      .replace(/\s+/g, " ");
    const search = raw.replace(/^[@#]+/, "");
    if (search.length < 2) {
      return { accounts: [], hashtags: [], posts: [] };
    }

    const limit = parseLimit(request.query?.limit, 8, 1, 12);
    const handleSearch = search.replace(/\s+/g, "");
    const canSearchHandles = /^[a-z0-9_.]+$/.test(handleSearch);
    const tagSearch = search.split(" ")[0].replace(/[^a-z0-9_]/g, "");
    const postContains = `%${escapeLike(search)}%`;
    const accountPrefix = `${escapeLike(handleSearch)}%`;
    const accountContains = `%${escapeLike(search)}%`;
    const tagPrefix = `${escapeLike(tagSearch)}%`;
    const tagContains = `%${escapeLike(tagSearch)}%`;

    const accountRows = canSearchHandles
      ? await queryMany(
          `SELECT user_id, username, display_name, avatar_url, is_verified
           FROM users
           WHERE user_id <> $1
             AND deleted_at IS NULL
             AND (username_lower LIKE $2 ESCAPE '\\' OR display_name_lower LIKE $3 ESCAPE '\\')
           ORDER BY
             CASE WHEN username_lower LIKE $2 ESCAPE '\\' THEN 0 ELSE 1 END,
             username_lower ASC
           LIMIT $4`,
          [request.user.userId, accountPrefix, accountContains, limit]
        )
      : [];

    const accountIds = accountRows.map((row) => row.user_id);
    const [following, followedBy, hashtags, posts] = await Promise.all([
      accountIds.length === 0
        ? Promise.resolve([])
        : queryMany(
            `SELECT following_id
             FROM follows
             WHERE follower_id = $1 AND following_id = ANY($2::text[])`,
            [request.user.userId, accountIds]
          ),
      accountIds.length === 0
        ? Promise.resolve([])
        : queryMany(
            `SELECT follower_id
             FROM follows
             WHERE follower_id = ANY($1::text[]) AND following_id = $2`,
            [accountIds, request.user.userId]
          ),
        tagSearch.length < 2
          ? Promise.resolve([])
          : queryMany(
              `SELECT tag, post_count, last_post_at, (post_count * 10) AS rank_score
               FROM tag_stats
               WHERE tag LIKE $1 ESCAPE '\\'
               ORDER BY
                 CASE WHEN tag LIKE $2 ESCAPE '\\' THEN 0 ELSE 1 END,
                 post_count DESC,
                 last_post_at DESC
               LIMIT $3`,
              [tagContains, tagPrefix, limit]
            ),
        queryMany(
          `SELECT p.post_id,
                  p.body,
                p.created_at,
                p.like_count,
                p.comment_count,
                p.share_count,
                p.hashtags,
                u.user_id,
                u.username,
                u.display_name,
                u.avatar_url,
                u.is_verified
         FROM posts p
         JOIN users u ON u.user_id = p.author_id
           WHERE u.deleted_at IS NULL
             AND p.body ILIKE $1 ESCAPE '\\'
           ORDER BY
             LEAST(p.like_count * 3 + p.comment_count * 4 + p.share_count * 5, 120) DESC,
             p.created_at DESC
           LIMIT $2`,
          [postContains, limit]
        ),
    ]);

    const followingSet = new Set(following.map((item: any) => item.following_id));
    const followedBySet = new Set(followedBy.map((item: any) => item.follower_id));

    return {
      accounts: accountRows.map((row) => ({
        id: row.user_id,
        username: row.username,
        displayName: row.display_name || row.username,
        avatarUrl: row.avatar_url || "",
        isVerified: row.is_verified === true,
        isFollowing: followingSet.has(row.user_id),
        isFollowedBy: followedBySet.has(row.user_id),
      })),
      hashtags: hashtags.map((row) => ({
        tag: row.tag,
        postCount: Number(row.post_count || 0),
        rankScore: Number(row.rank_score || 0),
        lastPostAt: toIso(row.last_post_at),
      })),
      posts: posts.map((row) => ({
        id: row.post_id,
        body: row.body,
        createdAt: toIso(row.created_at),
        likeCount: Number(row.like_count || 0),
        commentCount: Number(row.comment_count || 0),
        shareCount: Number(row.share_count || 0),
        hashtags: Array.isArray(row.hashtags) ? row.hashtags : [],
        author: {
          id: row.user_id,
          username: row.username,
          displayName: row.display_name || row.username,
          avatarUrl: row.avatar_url || "",
          isVerified: row.is_verified === true,
        },
      })),
    };
  });

  app.get("/location-suggestions", { preHandler: requireAuth }, async (request: any) => {
    const query = String(request.query?.query || request.query?.q || "").trim();
    const limit = parseLimit(request.query?.limit, 8, 1, 10);
    const [external, fallback] = await Promise.all([
      externalLocationSuggestions(query, limit),
      Promise.resolve(fallbackLocationSuggestions(query, limit)),
    ]);

    const seen = new Set<string>();
    const results = [...external, ...fallback].filter((item: any) => {
      const key = String(item?.label || "").toLowerCase();
      if (!key || seen.has(key)) return false;
      seen.add(key);
      return true;
    });

    return { results: results.slice(0, limit) };
  });

  app.get("/me/connections", { preHandler: requireAuth }, async (request: any) => {
    const limit = parseLimit(request.query?.limit, 20, 1, 100);

    const [followersRows, followingRows] = await Promise.all([
      queryMany(
        `SELECT follower_id, created_at
         FROM follows
         WHERE following_id = $1`,
        [request.user.userId]
      ),
      queryMany(
        `SELECT following_id, created_at
         FROM follows
         WHERE follower_id = $1`,
        [request.user.userId]
      ),
    ]);

    const followerMap = new Map(followersRows.map((row) => [row.follower_id, row]));
    const followingMap = new Map(followingRows.map((row) => [row.following_id, row]));

    const followerIds = [...followerMap.keys()];
    const followingIds = [...followingMap.keys()];

    const requestsIds = followerIds.filter((id) => !followingMap.has(id)).slice(0, limit);
    const sentIds = followingIds.filter((id) => !followerMap.has(id)).slice(0, limit);
    const friendsIds = followingIds.filter((id) => followerMap.has(id)).slice(0, limit);

    const userIds = [...new Set([...requestsIds, ...sentIds, ...friendsIds])];
    const users = await loadUsersByIds(userIds);
    const userMap = new Map(users.map((user) => [user.user_id, user]));

    const requests = requestsIds
      .map((id) => {
        const user = userMap.get(id);
        if (!user) return null;
        return mapConnectionItem(user, {
          isFollowing: false,
          isFollowedBy: true,
          since: followerMap.get(id)?.created_at,
        });
      })
      .filter(Boolean);

    const sent = sentIds
      .map((id) => {
        const user = userMap.get(id);
        if (!user) return null;
        return mapConnectionItem(user, {
          isFollowing: true,
          isFollowedBy: false,
          since: followingMap.get(id)?.created_at,
        });
      })
      .filter(Boolean);

    const friends = friendsIds
      .map((id) => {
        const user = userMap.get(id);
        if (!user) return null;
        const sinceA = followerMap.get(id)?.created_at;
        const sinceB = followingMap.get(id)?.created_at;
        const since = sinceA && sinceB
          ? (sinceA > sinceB ? sinceA : sinceB)
          : (sinceA || sinceB || null);

        return mapConnectionItem(user, {
          isFollowing: true,
          isFollowedBy: true,
          since,
        });
      })
      .filter(Boolean);

    return {
      requests,
      sent,
      friends,
    };
  });

  app.get("/:userId/connections", { preHandler: requireAuth }, async (request: any) => {
    const targetUserId = String(request.params.userId || "").trim();
    ensure(targetUserId.length >= 8, 400, "Invalid user");
    const type = String(request.query?.type || "followers") === "following"
      ? "following"
      : "followers";
    const limit = parseLimit(request.query?.limit, 50, 1, 100);

    await ensureNotBlocked(request.user.userId, targetUserId);

    const targetUser = await queryOne(
      `SELECT user_id FROM users WHERE user_id = $1 AND deleted_at IS NULL`,
      [targetUserId]
    );
    ensure(!!targetUser, 404, "User not found");

    const isSelf = request.user.userId === targetUserId;
    const [settingsDoc, isFollowing, isFollowedBy] = await Promise.all([
      queryOne(
        `SELECT settings FROM user_settings WHERE user_id = $1`,
        [targetUserId]
      ),
      isSelf
        ? Promise.resolve(null)
        : queryOne(
            `SELECT 1 FROM follows WHERE follower_id = $1 AND following_id = $2`,
            [request.user.userId, targetUserId]
          ),
      isSelf
        ? Promise.resolve(null)
        : queryOne(
            `SELECT 1 FROM follows WHERE follower_id = $1 AND following_id = $2`,
            [targetUserId, request.user.userId]
          ),
    ]);
    const relationship: ProfileRelationship = {
      state: "",
      isSelf,
      isFollowing: !!isFollowing,
      isFollowedBy: !!isFollowedBy,
      isFriend: !!isFollowing && !!isFollowedBy,
      isCloseFriend: false,
      requestPending: false,
      incomingRequestPending: false,
      isBlockedByViewer: false,
      hasBlockedViewer: false,
      isMuted: false,
      isRestricted: false,
    };
    relationship.state = relationshipState(relationship);
    const settings = mergeSettings(settingsDoc?.settings || {});
    const visibility = buildProfileVisibility(settings, relationship);
    const visible = visibility.visible as Record<string, boolean>;

    if (!visible[type]) {
      return { type, visible: false, items: [] };
    }

    const rows = type === "followers"
      ? await queryMany(
          `SELECT follower_id AS user_id, created_at
           FROM follows
           WHERE following_id = $1
           ORDER BY created_at DESC
           LIMIT $2`,
          [targetUserId, limit]
        )
      : await queryMany(
          `SELECT following_id AS user_id, created_at
           FROM follows
           WHERE follower_id = $1
           ORDER BY created_at DESC
           LIMIT $2`,
          [targetUserId, limit]
        );

    const userIds = rows.map((row) => row.user_id).filter(Boolean);
    const users = await loadUsersByIds(userIds);
    const userMap = new Map(users.map((user) => [user.user_id, user]));

    const [viewerFollowingRows, viewerFollowedByRows] = userIds.length === 0
      ? [[], []]
      : await Promise.all([
          queryMany(
            `SELECT following_id
             FROM follows
             WHERE follower_id = $1 AND following_id = ANY($2::text[])`,
            [request.user.userId, userIds]
          ),
          queryMany(
            `SELECT follower_id
             FROM follows
             WHERE follower_id = ANY($1::text[]) AND following_id = $2`,
            [userIds, request.user.userId]
          ),
        ]);
    const followingSet = new Set(viewerFollowingRows.map((row: any) => row.following_id));
    const followedBySet = new Set(viewerFollowedByRows.map((row: any) => row.follower_id));

    const items = rows
      .map((row) => {
        const user = userMap.get(row.user_id);
        if (!user) return null;
        return mapConnectionItem(user, {
          isFollowing: followingSet.has(row.user_id),
          isFollowedBy: followedBySet.has(row.user_id),
          since: row.created_at,
        });
      })
      .filter(Boolean);

    return { type, visible: true, items };
  });

  app.get("/me/profile", { preHandler: requireAuth }, async (request: any) => {
    const limit = parseLimit(request.query?.limit, 12, 1, 50);
    const previewAs = String(request.query?.previewAs || request.query?.as || "").trim();
    return buildProfileSummary(request.user.userId, request.user.userId, limit, previewAs);
  });

  app.get("/me/profile/preview", { preHandler: requireAuth }, async (request: any) => {
    const limit = parseLimit(request.query?.limit, 12, 1, 50);
    const previewAs = String(request.query?.as || "public").trim();
    return buildProfileSummary(request.user.userId, request.user.userId, limit, previewAs);
  });

  app.get("/:userId/profile", { preHandler: requireAuth }, async (request: any) => {
    const targetUserId = String(request.params.userId || "").trim();
    ensure(targetUserId.length >= 8, 400, "Invalid user");
    const limit = parseLimit(request.query?.limit, 12, 1, 50);

    return buildProfileSummary(request.user.userId, targetUserId, limit);
  });

  app.get("/me/settings", { preHandler: requireAuth }, async (request: any) => {
    const settingsDoc = await queryOne(
      `SELECT settings FROM user_settings WHERE user_id = $1`,
      [request.user.userId]
    );
    return {
      settings: mergeSettings(settingsDoc?.settings || {}),
    };
  });

  app.put("/me/settings", { preHandler: requireAuth }, async (request: any) => {
    const incoming = request.body || {};
    const existing = await queryOne(
      `SELECT settings FROM user_settings WHERE user_id = $1`,
      [request.user.userId]
    );

    const existingSettings = existing?.settings || {};
    const settings = mergeSettings({
      ...existingSettings,
      ...(incoming || {}),
      profileVisibility: {
        ...(existingSettings?.profileVisibility || {}),
        ...(incoming?.profileVisibility || {}),
      },
    });

    await query(
      `INSERT INTO user_settings (user_id, settings, updated_at)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id)
       DO UPDATE SET settings = EXCLUDED.settings, updated_at = EXCLUDED.updated_at`,
      [request.user.userId, JSON.stringify(settings), now()]
    );

    return { settings };
  });

  app.get("/me/profile-views", { preHandler: requireAuth }, async (request: any) => {
    const limit = parseLimit(request.query?.limit, 20, 1, 100);
    const rows = await queryMany(
      `SELECT pv.viewer_id, pv.view_count, pv.first_viewed_at, pv.last_viewed_at,
              u.username, u.display_name, u.avatar_url, u.is_verified
       FROM profile_views pv
       JOIN users u ON u.user_id = pv.viewer_id AND u.deleted_at IS NULL
       WHERE pv.profile_user_id = $1
       ORDER BY pv.last_viewed_at DESC
       LIMIT $2`,
      [request.user.userId, limit]
    );

    return {
      items: rows.map((row) => ({
        viewer: {
          id: row.viewer_id,
          username: row.username,
          displayName: row.display_name || row.username,
          avatarUrl: row.avatar_url || "",
          isVerified: row.is_verified === true,
        },
        viewCount: Number(row.view_count || 0),
        firstViewedAt: toIso(row.first_viewed_at),
        lastViewedAt: toIso(row.last_viewed_at),
      })),
    };
  });

  app.get("/me/profile-links", { preHandler: requireAuth }, async (request: any) => {
    const rows = await queryMany(
      `SELECT link_id, title, url, position, visibility, created_at, updated_at
       FROM profile_links
       WHERE user_id = $1
       ORDER BY position ASC, created_at DESC`,
      [request.user.userId]
    );

    return {
      items: rows.map((row) => ({
        id: row.link_id,
        title: row.title || "",
        url: row.url || "",
        position: Number(row.position || 0),
        visibility: row.visibility || "public",
        createdAt: toIso(row.created_at),
        updatedAt: toIso(row.updated_at),
      })),
    };
  });

  app.post("/me/profile-links", { preHandler: requireAuth }, async (request: any) => {
    const body = request.body || {};
    const title = String(body.title || "").trim().slice(0, 80);
    const url = normalizeUrl(body.url);
    ensure(url.length > 0, 400, "URL is required");
    const position = Math.max(0, Math.min(99, Number.parseInt(String(body.position || "0"), 10) || 0));
    const visibility = normalizeProfileResourceVisibility(body.visibility);
    const linkId = generateId();
    const ts = now();

    await query(
      `INSERT INTO profile_links (link_id, user_id, title, url, position, visibility, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $7)`,
      [linkId, request.user.userId, title, url, position, visibility, ts]
    );

    return {
      item: {
        id: linkId,
        title,
        url,
        position,
        visibility,
        createdAt: toIso(ts),
        updatedAt: toIso(ts),
      },
    };
  });

  app.put("/me/profile-links/:linkId", { preHandler: requireAuth }, async (request: any) => {
    const linkId = String(request.params.linkId || "").trim();
    ensure(linkId.length >= 8, 400, "Invalid link");
    const existing = await queryOne(
      `SELECT * FROM profile_links WHERE link_id = $1 AND user_id = $2`,
      [linkId, request.user.userId]
    );
    ensure(existing, 404, "Profile link not found");

    const body = request.body || {};
    const title = body.title === undefined ? existing.title : String(body.title || "").trim().slice(0, 80);
    const url = body.url === undefined ? existing.url : normalizeUrl(body.url);
    ensure(String(url || "").length > 0, 400, "URL is required");
    const position = body.position === undefined
      ? Number(existing.position || 0)
      : Math.max(0, Math.min(99, Number.parseInt(String(body.position || "0"), 10) || 0));
    const visibility = body.visibility === undefined
      ? normalizeProfileResourceVisibility(existing.visibility)
      : normalizeProfileResourceVisibility(body.visibility);
    const ts = now();

    await query(
      `UPDATE profile_links
       SET title = $3, url = $4, position = $5, visibility = $6, updated_at = $7
       WHERE link_id = $1 AND user_id = $2`,
      [linkId, request.user.userId, title, url, position, visibility, ts]
    );

    return {
      item: {
        id: linkId,
        title,
        url,
        position,
        visibility,
        updatedAt: toIso(ts),
      },
    };
  });

  app.delete("/me/profile-links/:linkId", { preHandler: requireAuth }, async (request: any) => {
    const linkId = String(request.params.linkId || "").trim();
    ensure(linkId.length >= 8, 400, "Invalid link");
    const result = await query(
      `DELETE FROM profile_links WHERE link_id = $1 AND user_id = $2`,
      [linkId, request.user.userId]
    );
    return { removed: (result.rowCount || 0) > 0 };
  });

  app.get("/me/profile-highlights", { preHandler: requireAuth }, async (request: any) => {
    const rows = await queryMany(
      `SELECT highlight_id, title, description, cover_url, post_ids, media_urls,
              visibility, position, created_at, updated_at
       FROM profile_highlights
       WHERE user_id = $1
       ORDER BY position ASC, created_at DESC`,
      [request.user.userId]
    );

    return {
      items: rows.map((row) => ({
        id: row.highlight_id,
        title: row.title || "",
        description: row.description || "",
        coverUrl: row.cover_url || "",
        postIds: Array.isArray(row.post_ids) ? row.post_ids : [],
        mediaUrls: Array.isArray(row.media_urls) ? row.media_urls : [],
        visibility: row.visibility || "public",
        position: Number(row.position || 0),
        createdAt: toIso(row.created_at),
        updatedAt: toIso(row.updated_at),
      })),
    };
  });

  app.post("/me/profile-highlights", { preHandler: requireAuth }, async (request: any) => {
    const body = request.body || {};
    const highlightId = generateId();
    const title = String(body.title || "").trim().slice(0, 80);
    ensure(title.length > 0, 400, "Highlight title is required");
    const description = String(body.description || "").trim().slice(0, 240);
    const coverUrl = body.coverUrl ? normalizeUrl(body.coverUrl) : "";
    const postIds = stringList(body.postIds, 50);
    const mediaUrls = stringList(body.mediaUrls, 50);
    const visibility = normalizeProfileResourceVisibility(body.visibility);
    const position = Math.max(0, Math.min(99, Number.parseInt(String(body.position || "0"), 10) || 0));
    const ts = now();

    await query(
      `INSERT INTO profile_highlights
       (highlight_id, user_id, title, description, cover_url, post_ids, media_urls, visibility, position, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $10)`,
      [
        highlightId,
        request.user.userId,
        title,
        description,
        coverUrl,
        JSON.stringify(postIds),
        JSON.stringify(mediaUrls),
        visibility,
        position,
        ts,
      ]
    );

    return {
      item: {
        id: highlightId,
        title,
        description,
        coverUrl,
        postIds,
        mediaUrls,
        visibility,
        position,
        createdAt: toIso(ts),
        updatedAt: toIso(ts),
      },
    };
  });

  app.put("/me/profile-highlights/:highlightId", { preHandler: requireAuth }, async (request: any) => {
    const highlightId = String(request.params.highlightId || "").trim();
    ensure(highlightId.length >= 8, 400, "Invalid highlight");
    const existing = await queryOne(
      `SELECT * FROM profile_highlights WHERE highlight_id = $1 AND user_id = $2`,
      [highlightId, request.user.userId]
    );
    ensure(existing, 404, "Highlight not found");
    const body = request.body || {};
    const title = body.title === undefined ? existing.title : String(body.title || "").trim().slice(0, 80);
    ensure(String(title || "").length > 0, 400, "Highlight title is required");
    const description = body.description === undefined
      ? existing.description
      : String(body.description || "").trim().slice(0, 240);
    const coverUrl = body.coverUrl === undefined
      ? existing.cover_url
      : (body.coverUrl ? normalizeUrl(body.coverUrl) : "");
    const postIds = body.postIds === undefined ? existing.post_ids || [] : stringList(body.postIds, 50);
    const mediaUrls = body.mediaUrls === undefined ? existing.media_urls || [] : stringList(body.mediaUrls, 50);
    const visibility = body.visibility === undefined
      ? normalizeProfileResourceVisibility(existing.visibility)
      : normalizeProfileResourceVisibility(body.visibility);
    const position = body.position === undefined
      ? Number(existing.position || 0)
      : Math.max(0, Math.min(99, Number.parseInt(String(body.position || "0"), 10) || 0));
    const ts = now();

    await query(
      `UPDATE profile_highlights
       SET title = $3, description = $4, cover_url = $5, post_ids = $6,
           media_urls = $7, visibility = $8, position = $9, updated_at = $10
       WHERE highlight_id = $1 AND user_id = $2`,
      [
        highlightId,
        request.user.userId,
        title,
        description,
        coverUrl,
        JSON.stringify(postIds),
        JSON.stringify(mediaUrls),
        visibility,
        position,
        ts,
      ]
    );

    return {
      item: {
        id: highlightId,
        title,
        description,
        coverUrl,
        postIds,
        mediaUrls,
        visibility,
        position,
        updatedAt: toIso(ts),
      },
    };
  });

  app.delete("/me/profile-highlights/:highlightId", { preHandler: requireAuth }, async (request: any) => {
    const highlightId = String(request.params.highlightId || "").trim();
    ensure(highlightId.length >= 8, 400, "Invalid highlight");
    const result = await query(
      `DELETE FROM profile_highlights WHERE highlight_id = $1 AND user_id = $2`,
      [highlightId, request.user.userId]
    );
    return { removed: (result.rowCount || 0) > 0 };
  });

  app.put("/me/profile-pinned-posts/:postId", { preHandler: requireAuth }, async (request: any) => {
    const postId = String(request.params.postId || "").trim();
    ensure(postId.length >= 8, 400, "Invalid post");
    const post = await queryOne(
      `SELECT post_id FROM posts WHERE post_id = $1 AND author_id = $2 AND deleted_at IS NULL`,
      [postId, request.user.userId]
    );
    ensure(post, 404, "Post not found");
    const position = Math.max(0, Math.min(9, Number.parseInt(String(request.body?.position || "0"), 10) || 0));
    const ts = now();
    await query(
      `INSERT INTO profile_pinned_posts (user_id, post_id, position, pinned_at)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (user_id, post_id)
       DO UPDATE SET position = EXCLUDED.position, pinned_at = EXCLUDED.pinned_at`,
      [request.user.userId, postId, position, ts]
    );
    return { pinned: true, postId, position, pinnedAt: toIso(ts) };
  });

  app.delete("/me/profile-pinned-posts/:postId", { preHandler: requireAuth }, async (request: any) => {
    const postId = String(request.params.postId || "").trim();
    ensure(postId.length >= 8, 400, "Invalid post");
    const result = await query(
      `DELETE FROM profile_pinned_posts WHERE user_id = $1 AND post_id = $2`,
      [request.user.userId, postId]
    );
    return { pinned: false, removed: (result.rowCount || 0) > 0 };
  });

  app.get("/me/blocks", { preHandler: requireAuth }, async (request: any) => {
    const limit = parseLimit(request.query?.limit, 30, 1, 100);
    const blocks = await queryMany(
      `SELECT blocked_id, created_at
       FROM user_blocks
       WHERE blocker_id = $1
       ORDER BY created_at DESC
       LIMIT $2`,
      [request.user.userId, limit]
    );

    if (blocks.length === 0) {
      return { items: [] };
    }

    const blockedIds = blocks.map((item) => item.blocked_id);
    const users = await loadUsersByIds(blockedIds);
    const userMap = new Map<string, any>(users.map((user) => [String(user.user_id), user]));

    return {
      items: blocks
        .map((block) => {
          const user = userMap.get(block.blocked_id);
          if (!user) return null;
          return {
            id: user.user_id,
            username: user.username,
            displayName: user.display_name || user.username,
            isVerified: user.is_verified === true,
            blockedAt: toIso(block.created_at),
          };
        })
        .filter(Boolean),
    };
  });

  app.post("/:targetUserId/block", { preHandler: requireAuth }, async (request: any) => {
    const targetUserId = String(request.params.targetUserId || "").trim();
    ensure(targetUserId.length >= 8, 400, "Invalid user");
    ensure(targetUserId !== request.user.userId, 400, "Cannot block self");
    await ensureUserExists(targetUserId);

    await withTransaction(async (client) => {
      await client.query(
        `INSERT INTO user_blocks (blocker_id, blocked_id, created_at)
         VALUES ($1, $2, $3)
         ON CONFLICT (blocker_id, blocked_id) DO NOTHING`,
        [request.user.userId, targetUserId, now()]
      );

      await client.query(
        `DELETE FROM follows
         WHERE (follower_id = $1 AND following_id = $2)
            OR (follower_id = $2 AND following_id = $1)`,
        [request.user.userId, targetUserId]
      );
    });

    return { blocked: true };
  });

  app.delete("/:targetUserId/block", { preHandler: requireAuth }, async (request: any) => {
    const targetUserId = String(request.params.targetUserId || "").trim();
    ensure(targetUserId.length >= 8, 400, "Invalid user");

    await query(
      `DELETE FROM user_blocks WHERE blocker_id = $1 AND blocked_id = $2`,
      [request.user.userId, targetUserId]
    );

    return { blocked: false };
  });

  app.get("/me/mutes", { preHandler: requireAuth }, async (request: any) => {
    const limit = parseLimit(request.query?.limit, 30, 1, 100);
    const rows = await queryMany(
      `SELECT muted_id, created_at
       FROM user_mutes
       WHERE muter_id = $1
       ORDER BY created_at DESC
       LIMIT $2`,
      [request.user.userId, limit]
    );

    if (rows.length === 0) {
      return { items: [] };
    }

    const mutedIds = rows.map((row) => row.muted_id).filter(Boolean);
    const users = await loadUsersByIds(mutedIds);
    const userMap = new Map<string, any>(users.map((user) => [String(user.user_id), user]));

    return {
      items: rows
        .map((row) => {
          const user = userMap.get(row.muted_id);
          if (!user) return null;
          return {
            id: user.user_id,
            username: user.username,
            displayName: user.display_name || user.username,
            avatarUrl: user.avatar_url || "",
            isVerified: user.is_verified === true,
            mutedAt: toIso(row.created_at),
          };
        })
        .filter(Boolean),
    };
  });

  app.post("/:targetUserId/mute", { preHandler: requireAuth }, async (request: any) => {
    const targetUserId = String(request.params.targetUserId || "").trim();
    ensure(targetUserId.length >= 8, 400, "Invalid user");
    ensure(targetUserId !== request.user.userId, 400, "Cannot mute self");
    await ensureUserExists(targetUserId);

    await query(
      `INSERT INTO user_mutes (muter_id, muted_id, created_at)
       VALUES ($1, $2, $3)
       ON CONFLICT (muter_id, muted_id) DO NOTHING`,
      [request.user.userId, targetUserId, now()]
    );

    return { muted: true };
  });

  app.delete("/:targetUserId/mute", { preHandler: requireAuth }, async (request: any) => {
    const targetUserId = String(request.params.targetUserId || "").trim();
    ensure(targetUserId.length >= 8, 400, "Invalid user");

    const result = await query(
      `DELETE FROM user_mutes WHERE muter_id = $1 AND muted_id = $2`,
      [request.user.userId, targetUserId]
    );

    return { muted: false, changed: (result.rowCount || 0) > 0 };
  });

  app.put("/:targetUserId/restrict", { preHandler: requireAuth }, async (request: any) => {
    const targetUserId = String(request.params.targetUserId || "").trim();
    const restricted = request.body?.restricted !== false;
    ensure(targetUserId.length >= 8, 400, "Invalid user");
    ensure(targetUserId !== request.user.userId, 400, "Cannot restrict self");
    await ensureUserExists(targetUserId);

    if (!restricted) {
      const result = await query(
        `DELETE FROM restricted_users WHERE owner_id = $1 AND restricted_id = $2`,
        [request.user.userId, targetUserId]
      );
      return { restricted: false, changed: (result.rowCount || 0) > 0 };
    }

    const reason = String(request.body?.reason || "").trim().slice(0, 160);
    await query(
      `INSERT INTO restricted_users (owner_id, restricted_id, reason, created_at)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (owner_id, restricted_id)
       DO UPDATE SET reason = EXCLUDED.reason`,
      [request.user.userId, targetUserId, reason, now()]
    );

    return { restricted: true };
  });

  app.delete("/:targetUserId/restrict", { preHandler: requireAuth }, async (request: any) => {
    const targetUserId = String(request.params.targetUserId || "").trim();
    ensure(targetUserId.length >= 8, 400, "Invalid user");
    const result = await query(
      `DELETE FROM restricted_users WHERE owner_id = $1 AND restricted_id = $2`,
      [request.user.userId, targetUserId]
    );
    return { restricted: false, changed: (result.rowCount || 0) > 0 };
  });

  app.put("/:targetUserId/close-friend", { preHandler: requireAuth }, async (request: any) => {
    const targetUserId = String(request.params.targetUserId || "").trim();
    const closeFriend = request.body?.closeFriend !== false;
    ensure(targetUserId.length >= 8, 400, "Invalid user");
    ensure(targetUserId !== request.user.userId, 400, "Cannot add self");
    await ensureUserExists(targetUserId);

    if (!closeFriend) {
      const result = await query(
        `DELETE FROM close_friends WHERE owner_id = $1 AND user_id = $2`,
        [request.user.userId, targetUserId]
      );
      return { closeFriend: false, changed: (result.rowCount || 0) > 0 };
    }

    const followsTarget = await queryOne(
      `SELECT 1 FROM follows WHERE follower_id = $1 AND following_id = $2`,
      [request.user.userId, targetUserId]
    );
    ensure(followsTarget, 400, "Follow this user before adding to close friends");

    await query(
      `INSERT INTO close_friends (owner_id, user_id, created_at)
       VALUES ($1, $2, $3)
       ON CONFLICT (owner_id, user_id) DO NOTHING`,
      [request.user.userId, targetUserId, now()]
    );

    return { closeFriend: true };
  });

  app.delete("/:targetUserId/close-friend", { preHandler: requireAuth }, async (request: any) => {
    const targetUserId = String(request.params.targetUserId || "").trim();
    ensure(targetUserId.length >= 8, 400, "Invalid user");
    const result = await query(
      `DELETE FROM close_friends WHERE owner_id = $1 AND user_id = $2`,
      [request.user.userId, targetUserId]
    );
    return { closeFriend: false, changed: (result.rowCount || 0) > 0 };
  });

  app.post("/:targetUserId/report", { preHandler: requireAuth }, async (request: any) => {
    const targetUserId = String(request.params.targetUserId || "").trim();
    ensure(targetUserId.length >= 8, 400, "Invalid user");
    ensure(targetUserId !== request.user.userId, 400, "Cannot report self");
    await ensureUserExists(targetUserId);

    const allowedReasons = new Set(["spam", "abuse", "impersonation", "harassment", "privacy", "other"]);
    const reason = String(request.body?.reason || "other").trim();
    const safeReason = allowedReasons.has(reason) ? reason : "other";
    const details = String(request.body?.details || "").trim().slice(0, 1000);
    const reportId = generateId();
    const ts = now();

    await query(
      `INSERT INTO profile_reports
       (report_id, reporter_user_id, profile_user_id, reason, details, status, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, 'open', $6, $6)`,
      [reportId, request.user.userId, targetUserId, safeReason, details, ts]
    );

    return {
      reported: true,
      report: {
        id: reportId,
        reason: safeReason,
        status: "open",
        createdAt: toIso(ts),
      },
    };
  });

  app.get("/me/muted-words", { preHandler: requireAuth }, async (request: any) => {
    const limit = parseLimit(request.query?.limit, 50, 1, 200);
    const rows = await queryMany(
      `SELECT muted_word_id, phrase, created_at
       FROM user_muted_words
       WHERE user_id = $1
       ORDER BY created_at DESC
       LIMIT $2`,
      [request.user.userId, limit]
    );

    return {
      items: rows.map((row) => ({
        id: row.muted_word_id,
        phrase: row.phrase,
        createdAt: toIso(row.created_at),
      })),
    };
  });

  app.post("/me/muted-words", { preHandler: requireAuth }, async (request: any) => {
    const phrase = String(request.body?.phrase || "").trim();
    ensure(phrase.length >= 2 && phrase.length <= 80, 400, "Invalid phrase");

    const phraseLower = phrase.toLowerCase();
    const existing = await queryOne(
      `SELECT muted_word_id, phrase, created_at
       FROM user_muted_words
       WHERE user_id = $1 AND phrase_lower = $2`,
      [request.user.userId, phraseLower]
    );

    if (existing) {
      return {
        item: {
          id: existing.muted_word_id,
          phrase: existing.phrase,
          createdAt: toIso(existing.created_at),
        },
      };
    }

    const mutedWordId = generateId();
    const createdAt = now();
    await query(
      `INSERT INTO user_muted_words (muted_word_id, user_id, phrase, phrase_lower, created_at)
       VALUES ($1, $2, $3, $4, $5)`,
      [mutedWordId, request.user.userId, phrase, phraseLower, createdAt]
    );

    return {
      item: {
        id: mutedWordId,
        phrase,
        createdAt: toIso(createdAt),
      },
    };
  });

  app.delete("/me/muted-words/:id", { preHandler: requireAuth }, async (request: any) => {
    const id = String(request.params.id || "").trim();
    ensure(id.length >= 3, 400, "Invalid id");

    const result = await query(
      `DELETE FROM user_muted_words WHERE user_id = $1 AND muted_word_id = $2`,
      [request.user.userId, id]
    );

    return { removed: (result.rowCount || 0) > 0 };
  });

  app.get("/me/data-export", { preHandler: requireAuth }, async (request: any) => {
    const latest = await queryOne(
      `SELECT export_id, status, format, payload, created_at, completed_at
       FROM data_exports
       WHERE user_id = $1
       ORDER BY created_at DESC
       LIMIT 1`,
      [request.user.userId]
    );

    if (!latest) {
      return { export: null };
    }

    return {
      export: {
        id: latest.export_id,
        status: latest.status,
        format: latest.format,
        payload: latest.payload || {},
        createdAt: toIso(latest.created_at),
        completedAt: toIso(latest.completed_at),
      },
    };
  });

  app.post("/me/data-export", { preHandler: requireAuth }, async (request: any) => {
    const user = await queryOne(`SELECT * FROM users WHERE user_id = $1`, [request.user.userId]);
    if (!user) {
      throw new HttpError(404, "User not found");
    }

    const ts = now();
    const exportDoc = {
      exportId: generateId(),
      status: "completed",
      format: "json",
      payload: {
        user: {
          id: user.user_id,
          email: user.email,
          username: user.username,
          displayName: user.display_name || user.username,
        },
      },
    };

    await query(
      `INSERT INTO data_exports (export_id, user_id, status, format, payload, created_at, completed_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [
        exportDoc.exportId,
        request.user.userId,
        exportDoc.status,
        exportDoc.format,
        JSON.stringify(exportDoc.payload),
        ts,
        ts,
      ]
    );

    return {
      export: {
        id: exportDoc.exportId,
        status: exportDoc.status,
        format: exportDoc.format,
        payload: exportDoc.payload,
        createdAt: toIso(ts),
        completedAt: toIso(ts),
      },
    };
  });

  app.post("/:targetUserId/follow", { preHandler: requireAuth }, async (request: any) => {
    const targetUserId = String(request.params.targetUserId || "").trim();
    ensure(targetUserId.length >= 8, 400, "Invalid user");
    ensure(targetUserId !== request.user.userId, 400, "Cannot follow self");
    await ensureUserExists(targetUserId);
    await ensureNotBlocked(request.user.userId, targetUserId);

    const existing = await queryOne(
      `SELECT follower_id FROM follows WHERE follower_id = $1 AND following_id = $2`,
      [request.user.userId, targetUserId]
    );

    if (existing) {
      await withTransaction(async (client) => {
        await client.query(
          `DELETE FROM follows WHERE follower_id = $1 AND following_id = $2`,
          [request.user.userId, targetUserId]
        );
        await client.query(
          `DELETE FROM follow_requests WHERE requester_id = $1 AND target_id = $2`,
          [request.user.userId, targetUserId]
        );
      });
      return { following: false, requested: false };
    }

    const targetSettingsDoc = await queryOne(
      `SELECT settings FROM user_settings WHERE user_id = $1`,
      [targetUserId]
    );
    const targetSettings = mergeSettings(targetSettingsDoc?.settings || {});
    if (targetSettings.privateAccount === true) {
      const ts = now();
      await query(
        `INSERT INTO follow_requests (requester_id, target_id, status, created_at, updated_at)
         VALUES ($1, $2, 'pending', $3, $3)
         ON CONFLICT (requester_id, target_id)
         DO UPDATE SET status = 'pending',
                       updated_at = EXCLUDED.updated_at,
                       responded_at = NULL`,
        [request.user.userId, targetUserId, ts]
      );
      if (await shouldCreateNotification(targetUserId, "notifyFollows")) {
        await enqueueNotificationEvent({
          eventType: "FOLLOW_REQUEST_RECEIVED",
          recipientUserId: targetUserId,
          actorUserId: request.user.userId,
          entityType: "user",
          entityId: request.user.userId,
          payload: { followerId: request.user.userId, requestStatus: "pending" },
        });
      }
      return { following: false, requested: true };
    }

    const ts = now();
    const notifyTarget = await shouldCreateNotification(targetUserId, "notifyFollows");
    await withTransaction(async (client) => {
      await client.query(
        `INSERT INTO follows (follower_id, following_id, created_at)
         VALUES ($1, $2, $3)
         ON CONFLICT (follower_id, following_id) DO NOTHING`,
        [request.user.userId, targetUserId, ts]
      );

      if (notifyTarget) {
        await enqueueNotificationEvent({
          eventType: "FOLLOW_RECEIVED",
          recipientUserId: targetUserId,
          actorUserId: request.user.userId,
          entityType: "user",
          entityId: request.user.userId,
          payload: { followerId: request.user.userId },
        }, client);
      }
    });

    return { following: true, requested: false };
  });

  app.put("/:targetUserId/follow", { preHandler: requireAuth }, async (request: any) => {
    const targetUserId = String(request.params.targetUserId || "").trim();
    const follow = request.body?.follow === true;
    ensure(targetUserId.length >= 8, 400, "Invalid user");
    ensure(targetUserId !== request.user.userId, 400, "Cannot follow self");
    await ensureUserExists(targetUserId);
    await ensureNotBlocked(request.user.userId, targetUserId);

    if (follow) {
      const targetSettingsDoc = await queryOne(
        `SELECT settings FROM user_settings WHERE user_id = $1`,
        [targetUserId]
      );
      const targetSettings = mergeSettings(targetSettingsDoc?.settings || {});
      if (targetSettings.privateAccount === true) {
        const ts = now();
        const result = await query(
          `INSERT INTO follow_requests (requester_id, target_id, status, created_at, updated_at)
           VALUES ($1, $2, 'pending', $3, $3)
           ON CONFLICT (requester_id, target_id)
           DO UPDATE SET status = 'pending',
                         updated_at = EXCLUDED.updated_at,
                         responded_at = NULL`,
          [request.user.userId, targetUserId, ts]
        );
        if ((result.rowCount || 0) > 0 && await shouldCreateNotification(targetUserId, "notifyFollows")) {
          await enqueueNotificationEvent({
            eventType: "FOLLOW_REQUEST_RECEIVED",
            recipientUserId: targetUserId,
            actorUserId: request.user.userId,
            entityType: "user",
            entityId: request.user.userId,
            payload: { followerId: request.user.userId, requestStatus: "pending" },
          });
        }
        return {
          following: false,
          requested: true,
          changed: (result.rowCount || 0) > 0,
        };
      }

      const ts = now();
      const result = await query(
        `INSERT INTO follows (follower_id, following_id, created_at)
         VALUES ($1, $2, $3)
         ON CONFLICT (follower_id, following_id) DO NOTHING`,
        [request.user.userId, targetUserId, ts]
      );
      if ((result.rowCount || 0) > 0 && await shouldCreateNotification(targetUserId, "notifyFollows")) {
        await enqueueNotificationEvent({
          eventType: "FOLLOW_RECEIVED",
          recipientUserId: targetUserId,
          actorUserId: request.user.userId,
          entityType: "user",
          entityId: request.user.userId,
          payload: { followerId: request.user.userId },
        });
      }
      return {
        following: true,
        requested: false,
        changed: (result.rowCount || 0) > 0,
      };
    }

    const result = await withTransaction(async (client) => {
      const deleteFollow = await client.query(
        `DELETE FROM follows WHERE follower_id = $1 AND following_id = $2`,
        [request.user.userId, targetUserId]
      );
      await client.query(
        `DELETE FROM follow_requests WHERE requester_id = $1 AND target_id = $2`,
        [request.user.userId, targetUserId]
      );
      return deleteFollow;
    });

    return {
      following: false,
      requested: false,
      changed: (result.rowCount || 0) > 0,
    };
  });

  app.post("/:targetUserId/follow-request/accept", { preHandler: requireAuth }, async (request: any) => {
    const targetUserId = String(request.params.targetUserId || "").trim();
    ensure(targetUserId.length >= 8, 400, "Invalid user");
    await ensureUserExists(targetUserId);
    await ensureNotBlocked(request.user.userId, targetUserId);
    const ts = now();
    const accepted = await withTransaction(async (client) => {
      const requestRow = await client.query(
        `UPDATE follow_requests
         SET status = 'accepted', updated_at = $3, responded_at = $3
         WHERE requester_id = $1 AND target_id = $2 AND status = 'pending'`,
        [targetUserId, request.user.userId, ts]
      );
      if ((requestRow.rowCount || 0) === 0) return false;
      await client.query(
        `INSERT INTO follows (follower_id, following_id, created_at)
         VALUES ($1, $2, $3)
         ON CONFLICT (follower_id, following_id) DO NOTHING`,
        [targetUserId, request.user.userId, ts]
      );
      return true;
    });
    return { accepted, following: accepted };
  });

  app.post("/:targetUserId/follow-request/reject", { preHandler: requireAuth }, async (request: any) => {
    const targetUserId = String(request.params.targetUserId || "").trim();
    ensure(targetUserId.length >= 8, 400, "Invalid user");
    const result = await query(
      `UPDATE follow_requests
       SET status = 'rejected', updated_at = $3, responded_at = $3
       WHERE requester_id = $1 AND target_id = $2 AND status = 'pending'`,
      [targetUserId, request.user.userId, now()]
    );
    return { rejected: (result.rowCount || 0) > 0 };
  });

  app.delete("/:targetUserId/follower", { preHandler: requireAuth }, async (request: any) => {
    const targetUserId = String(request.params.targetUserId || "").trim();
    ensure(targetUserId.length >= 8, 400, "Invalid user");

    const result = await query(
      `DELETE FROM follows WHERE follower_id = $1 AND following_id = $2`,
      [targetUserId, request.user.userId]
    );

    return { removed: (result.rowCount || 0) > 0 };
  });

  app.delete("/:targetUserId/connection", { preHandler: requireAuth }, async (request: any) => {
    const targetUserId = String(request.params.targetUserId || "").trim();
    ensure(targetUserId.length >= 8, 400, "Invalid user");

    const result = await query(
      `DELETE FROM follows
       WHERE (follower_id = $1 AND following_id = $2)
          OR (follower_id = $2 AND following_id = $1)`,
      [request.user.userId, targetUserId]
    );

    return { removed: (result.rowCount || 0) > 0 };
  });
}
