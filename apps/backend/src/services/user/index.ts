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
} from "../../lib/security.js";

const PROFILE_VISIBILITY_VALUES = ["everyone", "followers", "friends", "onlyMe"] as const;
type ProfileVisibility = (typeof PROFILE_VISIBILITY_VALUES)[number];
type ProfileVisibilityMap = Record<string, ProfileVisibility>;

const DEFAULT_PROFILE_VISIBILITY: ProfileVisibilityMap = {
  bio: "everyone",
  location: "friends",
  website: "everyone",
  joined: "everyone",
  posts: "everyone",
  followers: "everyone",
  following: "everyone",
  likes: "onlyMe",
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
  dataSaver: false,
  autoDownload: true,
  autoPlayVideos: true,
  reduceMotion: false,
  themeIndex: 0,
  textScale: 1,
  languageLabel: "English",
};

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

type ProfileRelationship = {
  isSelf: boolean;
  isFollowing: boolean;
  isFollowedBy: boolean;
  isFriend: boolean;
};

function minVisibility(
  current: ProfileVisibility,
  minimum: ProfileVisibility
): ProfileVisibility {
  const rank: Record<ProfileVisibility, number> = {
    everyone: 0,
    followers: 1,
    friends: 2,
    onlyMe: 3,
  };
  return rank[current] < rank[minimum] ? minimum : current;
}

function canViewByVisibility(
  visibility: ProfileVisibility,
  relationship: ProfileRelationship
): boolean {
  if (relationship.isSelf) return true;
  if (visibility === "everyone") return true;
  if (visibility === "followers") return relationship.isFollowing;
  if (visibility === "friends") return relationship.isFriend;
  return false;
}

function buildProfileVisibility(
  settings: any,
  relationship: ProfileRelationship
) {
  const profileVisibility = normalizeProfileVisibility(settings?.profileVisibility);
  const effectiveVisibility = settings?.privateAccount && !relationship.isSelf
    ? {
        ...profileVisibility,
        posts: minVisibility(profileVisibility.posts, "followers"),
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
       (SELECT COUNT(*)::int FROM posts WHERE author_id = $1) AS posts,
       (SELECT COUNT(*)::int FROM follows WHERE following_id = $1) AS followers,
       (SELECT COUNT(*)::int FROM follows WHERE follower_id = $1) AS following,
       (SELECT COALESCE(SUM(like_count), 0)::int FROM posts WHERE author_id = $1) AS likes`,
    [userId]
  );

  return {
    posts: Number(stats?.posts || 0),
    followers: Number(stats?.followers || 0),
    following: Number(stats?.following || 0),
    likes: Number(stats?.likes || 0),
  };
}

async function buildProfileSummary(viewerUserId: string, targetUserId: string, limit: number) {
  const user = await queryOne(
    `SELECT *
     FROM users
     WHERE user_id = $1 AND deleted_at IS NULL`,
    [targetUserId]
  );
  if (!user) {
    throw new HttpError(404, "User not found");
  }

  const isSelf = viewerUserId === targetUserId;
  const [settingsDoc, isFollowing, isFollowedBy] = await Promise.all([
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
  ]);
  const relationship: ProfileRelationship = {
    isSelf,
    isFollowing: !!isFollowing,
    isFollowedBy: !!isFollowedBy,
    isFriend: !!isFollowing && !!isFollowedBy,
  };
  const settings = mergeSettings(settingsDoc?.settings || {});
  const visibility = buildProfileVisibility(settings, relationship);
  const visible = visibility.visible as Record<string, boolean>;
  const details = user.details || {};

  const [stats, posts, tags, mentions] = await Promise.all([
    buildStats(targetUserId),
    visible.posts
      ? queryMany(
          `SELECT *
           FROM posts
           WHERE author_id = $1
           ORDER BY created_at DESC
           LIMIT $2`,
          [targetUserId, limit]
        )
      : Promise.resolve([]),
    visible.posts ? buildProfileTags(targetUserId, limit) : Promise.resolve([]),
    visible.posts ? buildProfileMentions(targetUserId, limit) : Promise.resolve([]),
  ]);

  const summary = {
    user: {
      id: user.user_id,
      username: user.username,
      displayName: user.display_name || user.username,
      bio: visible.bio ? (user.bio || "") : "",
      location: visible.location ? (user.location || "") : "",
      website: visible.website ? (user.website || "") : "",
      avatarUrl: user.avatar_url || "",
      coverUrl: user.cover_url || "",
      pinnedDetails: details.pinnedDetails || "",
      category: details.category || "",
      aiCreator: details.aiCreator === true,
      hometown: visible.location ? (details.hometown || "") : "",
      phoneCountryCode: isSelf ? (details.phoneCountryCode || "") : "",
      phoneNumber: isSelf ? (details.phoneNumber || "") : "",
      isVerified: user.is_verified === true,
      createdAt: visible.joined ? toIso(user.created_at) : null,
    },
    stats: {
      posts: visible.posts ? stats.posts : 0,
      followers: visible.followers ? stats.followers : 0,
      following: visible.following ? stats.following : 0,
      likes: visible.likes ? stats.likes : 0,
    },
    posts: posts.map(mapProfilePost),
    tags: tags.map(mapProfileTag),
    mentions: mentions.map(mapProfileMention),
    visibility,
    relationship,
  };

  if (isSelf) {
    const likedPosts = await queryMany(
      `SELECT p.*
       FROM post_likes pl
       JOIN posts p ON p.post_id = pl.post_id
       WHERE pl.user_id = $1
       ORDER BY pl.created_at DESC
       LIMIT $2`,
      [targetUserId, limit]
    );

    return {
      ...summary,
      liked: likedPosts.map(mapProfilePost),
    };
  }

  return {
    ...summary,
  };
}

function accountPayload(user: any) {
  const details = user.details || {};
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
    const fields: string[] = [];
    const params: unknown[] = [request.user.userId];

    const setField = (column: string, value: unknown) => {
      params.push(value);
      fields.push(`${column} = $${params.length}`);
    };

    if (body.username !== undefined) {
      const usernameLower = normalizeUsername(body.username);
      ensure(isValidUsername(usernameLower), 400, "Invalid username");

      const duplicate = await queryOne(
        `SELECT user_id FROM users WHERE username_lower = $1 AND user_id <> $2`,
        [usernameLower, request.user.userId]
      );
      if (duplicate) {
        throw new HttpError(409, "Username already exists");
      }

      setField("username", usernameLower);
      setField("username_lower", usernameLower);
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

    setField("updated_at", now());

    try {
      await query(
        `UPDATE users SET ${fields.join(", ")} WHERE user_id = $1`,
        params
      );
    } catch (error: any) {
      if (error.code === "23505") {
        throw new HttpError(409, "Username already exists");
      }
      throw error;
    }

    const user = await queryOne(`SELECT * FROM users WHERE user_id = $1`, [request.user.userId]);
    if (!user) {
      throw new HttpError(404, "User not found");
    }
    return { profile: accountPayload(user) };
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
    if (search.length < 2 || !/^[a-z0-9_.]+$/.test(search)) {
      return { results: [] };
    }

    const limit = parseLimit(request.query?.limit, 20, 1, 25);
    const prefix = `${escapeLike(search)}%`;
    const rows = await queryMany(
      `SELECT user_id, username, display_name, is_verified
       FROM users
       WHERE user_id <> $1
         AND deleted_at IS NULL
         AND (username_lower LIKE $2 ESCAPE '\\' OR display_name_lower LIKE $2 ESCAPE '\\')
       ORDER BY username_lower ASC
       LIMIT $3`,
      [request.user.userId, prefix, limit]
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
        isVerified: row.is_verified === true,
        isFollowing: followingSet.has(row.user_id),
        isFollowedBy: followedBySet.has(row.user_id),
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

  app.get("/me/profile", { preHandler: requireAuth }, async (request: any) => {
    const limit = parseLimit(request.query?.limit, 12, 1, 50);
    return buildProfileSummary(request.user.userId, request.user.userId, limit);
  });

  app.get("/:userId/profile", { preHandler: requireAuth }, async (request: any) => {
    const targetUserId = String(request.params.userId || "").trim();
    ensure(targetUserId.length >= 8, 400, "Invalid user");
    const limit = parseLimit(request.query?.limit, 12, 1, 50);

    await ensureNotBlocked(request.user.userId, targetUserId);
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
      await query(
        `DELETE FROM follows WHERE follower_id = $1 AND following_id = $2`,
        [request.user.userId, targetUserId]
      );
      return { following: false };
    }

    const ts = now();
    await withTransaction(async (client) => {
      await client.query(
        `INSERT INTO follows (follower_id, following_id, created_at)
         VALUES ($1, $2, $3)
         ON CONFLICT (follower_id, following_id) DO NOTHING`,
        [request.user.userId, targetUserId, ts]
      );

      await client.query(
        `INSERT INTO notifications (
           notification_id, user_id, actor_user_id, type, title, body, data, created_at, read_at
         )
         VALUES ($1, $2, $3, 'follow', 'New follower', 'Someone started following you', $4, $5, NULL)`,
        [
          generateId(),
          targetUserId,
          request.user.userId,
          JSON.stringify({ followerId: request.user.userId }),
          ts,
        ]
      );
    });

    return { following: true };
  });

  app.put("/:targetUserId/follow", { preHandler: requireAuth }, async (request: any) => {
    const targetUserId = String(request.params.targetUserId || "").trim();
    const follow = request.body?.follow === true;
    ensure(targetUserId.length >= 8, 400, "Invalid user");
    ensure(targetUserId !== request.user.userId, 400, "Cannot follow self");
    await ensureUserExists(targetUserId);
    await ensureNotBlocked(request.user.userId, targetUserId);

    if (follow) {
      const result = await query(
        `INSERT INTO follows (follower_id, following_id, created_at)
         VALUES ($1, $2, $3)
         ON CONFLICT (follower_id, following_id) DO NOTHING`,
        [request.user.userId, targetUserId, now()]
      );
      return {
        following: true,
        changed: (result.rowCount || 0) > 0,
      };
    }

    const result = await query(
      `DELETE FROM follows WHERE follower_id = $1 AND following_id = $2`,
      [request.user.userId, targetUserId]
    );

    return {
      following: false,
      changed: (result.rowCount || 0) > 0,
    };
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
