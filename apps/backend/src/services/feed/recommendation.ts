import { query, queryMany, queryOne } from "../../lib/pg.js";
import { generateId, HttpError, now, toIso } from "../../lib/security.js";

export type FeedMode =
  | "for-you"
  | "following"
  | "friends"
  | "latest"
  | "topics"
  | "conversations"
  | "explore"
  | "catch-up"
  | "custom";

export type FeedLens =
  | "balanced"
  | "latest"
  | "deep_reads"
  | "conversations"
  | "friends_first"
  | "discover"
  | "professional"
  | "local";

type CandidateSource =
  | "in_network"
  | "friend_recent"
  | "interest"
  | "topic_affinity"
  | "semantic_similarity"
  | "social_proof"
  | "trusted_network"
  | "trending"
  | "exploration"
  | "emerging_creator"
  | "conversation"
  | "language_affinity"
  | "editorial"
  | "interacted_authors"
  | "cold_start";

type FeedCursor = {
  score?: number;
  createdAt?: string;
  postId?: string;
};

type Candidate = {
  post: any;
  sources: Set<CandidateSource>;
  reasons: Set<string>;
  sourceScore?: number;
  exploration?: boolean;
  editorialLabel?: string;
};

type FeedPreferences = {
  lens: FeedLens;
  discoveryIntensity: number;
  friendPriority: number;
  latestPriority: number;
  reduceReposts: boolean;
  reducePoliticalContent: boolean;
  reduceSensitiveContent: boolean;
  preferProfessionalContent: boolean;
  preferLocalContent: boolean;
  localDiscoveryEnabled: boolean;
  perspectiveBroadeningEnabled: boolean;
  preferredLanguages: string[];
  mutedKeywords: string[];
};

type FeatureBundle = {
  stats: Map<string, any>;
  authorAffinities: Map<string, any>;
  userTopics: Map<string, number>;
  postTopics: Map<string, Array<{ topic: string; weight: number }>>;
  socialProof: Map<string, number>;
  impressions: Map<string, any>;
};

export type RankedFeedPost = any & {
  rank_score: number;
  recommendation_reason: string;
  recommendation_reasons: string[];
  candidate_sources: string[];
  score_breakdown: Record<string, number>;
};

export type FeedPageResult = {
  items: RankedFeedPost[];
  nextCursor: string | null;
  sessionId: string;
  metrics: {
    mode: FeedMode;
    lens: FeedLens;
    candidateCount: number;
    filteredCount: number;
    fallbackUsed: string | null;
    sourceCounts: Record<string, number>;
    durationMs: number;
  };
};

export type FeedEventInput = {
  type?: string;
  postId?: string;
  commentId?: string | null;
  dwellMs?: number;
  source?: string;
  sessionId?: string;
  clientEventId?: string;
  metadata?: Record<string, unknown>;
};

type RankingConfig = {
  candidateMultiplier: number;
  maxCandidatePool: number;
  maxAgeDays: number;
  servedHistoryHours: number;
  cursorEpsilon: number;
  sourceAllocation: Record<CandidateSource, number>;
  weights: {
    recency: number;
    affinity: number;
    interest: number;
    engagement: number;
    trend: number;
    socialProof: number;
    quality: number;
    exploration: number;
    negativeFeedback: number;
    repetition: number;
    spam: number;
  };
  diversity: {
    authorRepeatPenalty: number;
    sameAuthorConsecutivePenalty: number;
    topicRepeatPenalty: number;
  };
  quotas: {
    exploration: number;
    emergingCreator: number;
    outOfNetwork: number;
    trend: number;
    repost: number;
  };
};

export const FEED_EVENT_TYPES = [
  "impression",
  "view",
  "dwell",
  "click",
  "post_open",
  "profile_click",
  "like",
  "unlike",
  "comment",
  "reply",
  "share",
  "bookmark",
  "unbookmark",
  "media_expand",
  "video_progress",
  "hide",
  "not_interested",
  "mute",
  "block",
  "report",
  "follow_author",
] as const;

const POSITIVE_EVENT_TYPES = new Set([
  "view",
  "dwell",
  "click",
  "post_open",
  "profile_click",
  "like",
  "comment",
  "reply",
  "share",
  "bookmark",
  "media_expand",
  "video_progress",
  "follow_author",
]);

const NEGATIVE_EVENT_TYPES = new Set([
  "hide",
  "not_interested",
  "mute",
  "block",
  "report",
]);

const DEFAULT_CONFIG: RankingConfig = {
  candidateMultiplier: 10,
  maxCandidatePool: 360,
  maxAgeDays: 21,
  servedHistoryHours: 6,
  cursorEpsilon: 0.000001,
  sourceAllocation: {
    in_network: 0.4,
    friend_recent: 0.18,
    interest: 0.2,
    topic_affinity: 0.18,
    semantic_similarity: 0.08,
    social_proof: 0.15,
    trusted_network: 0.12,
    trending: 0.15,
    exploration: 0.1,
    emerging_creator: 0.08,
    conversation: 0.12,
    language_affinity: 0.08,
    editorial: 0.04,
    interacted_authors: 0.1,
    cold_start: 0.1,
  },
  weights: {
    recency: 0.22,
    affinity: 0.18,
    interest: 0.18,
    engagement: 0.16,
    trend: 0.1,
    socialProof: 0.08,
    quality: 0.08,
    exploration: 0.04,
    negativeFeedback: 0.35,
    repetition: 0.12,
    spam: 0.28,
  },
  diversity: {
    authorRepeatPenalty: 0.09,
    sameAuthorConsecutivePenalty: 0.24,
    topicRepeatPenalty: 0.05,
  },
  quotas: {
    exploration: 0.14,
    emergingCreator: 0.08,
    outOfNetwork: 0.45,
    trend: 0.22,
    repost: 0.25,
  },
};

const DEFAULT_FEED_PREFERENCES: FeedPreferences = {
  lens: "balanced",
  discoveryIntensity: 0.22,
  friendPriority: 0.35,
  latestPriority: 0.15,
  reduceReposts: false,
  reducePoliticalContent: false,
  reduceSensitiveContent: true,
  preferProfessionalContent: false,
  preferLocalContent: false,
  localDiscoveryEnabled: false,
  perspectiveBroadeningEnabled: false,
  preferredLanguages: [],
  mutedKeywords: [],
};

function clamp(value: number, min = 0, max = 1): number {
  if (!Number.isFinite(value)) return min;
  return Math.max(min, Math.min(max, value));
}

function parsePositiveNumber(value: string | undefined, fallback: number): number {
  const parsed = Number.parseFloat(String(value || ""));
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function clamp01(value: unknown, fallback: number): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return clamp(parsed, 0, 1);
}

export function normalizeFeedMode(value: unknown): FeedMode {
  const mode = String(value || "for-you").trim().toLowerCase();
  if (
    mode === "for-you"
    || mode === "following"
    || mode === "friends"
    || mode === "latest"
    || mode === "topics"
    || mode === "conversations"
    || mode === "explore"
    || mode === "catch-up"
    || mode === "custom"
  ) {
    return mode;
  }
  return "for-you";
}

export function normalizeFeedLens(value: unknown): FeedLens {
  const lens = String(value || "").trim().toLowerCase().replace(/-/g, "_");
  if (
    lens === "balanced"
    || lens === "latest"
    || lens === "deep_reads"
    || lens === "conversations"
    || lens === "friends_first"
    || lens === "discover"
    || lens === "professional"
    || lens === "local"
  ) {
    return lens;
  }
  return "balanced";
}

function normalizeTopic(value: unknown): string {
  return String(value || "")
    .trim()
    .replace(/^#/, "")
    .toLowerCase()
    .replace(/[^a-z0-9_ -]/g, "")
    .replace(/\s+/g, "_")
    .slice(0, 64);
}

function normalizeLanguage(value: unknown): string {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z-]/g, "")
    .slice(0, 12);
}

function jsonArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function normalizeStringList(value: unknown, max = 50): string[] {
  return [...new Set(jsonArray(value).map((item) => String(item || "").trim().toLowerCase()).filter(Boolean))]
    .slice(0, max);
}

export async function getFeedPreferences(userId: string): Promise<FeedPreferences> {
  const row = await queryOne(
    `SELECT lens, discovery_intensity, friend_priority, latest_priority,
            reduce_reposts, reduce_political_content, reduce_sensitive_content,
            prefer_professional_content, prefer_local_content, local_discovery_enabled,
            perspective_broadening_enabled, preferred_languages, muted_keywords
     FROM feed_preferences
     WHERE user_id = $1`,
    [userId]
  );
  if (!row) return { ...DEFAULT_FEED_PREFERENCES };
  return {
    lens: normalizeFeedLens(row.lens),
    discoveryIntensity: clamp01(row.discovery_intensity, DEFAULT_FEED_PREFERENCES.discoveryIntensity),
    friendPriority: clamp01(row.friend_priority, DEFAULT_FEED_PREFERENCES.friendPriority),
    latestPriority: clamp01(row.latest_priority, DEFAULT_FEED_PREFERENCES.latestPriority),
    reduceReposts: row.reduce_reposts === true,
    reducePoliticalContent: row.reduce_political_content === true,
    reduceSensitiveContent: row.reduce_sensitive_content !== false,
    preferProfessionalContent: row.prefer_professional_content === true,
    preferLocalContent: row.prefer_local_content === true,
    localDiscoveryEnabled: row.local_discovery_enabled === true,
    perspectiveBroadeningEnabled: row.perspective_broadening_enabled === true,
    preferredLanguages: normalizeStringList(row.preferred_languages, 12).map(normalizeLanguage).filter(Boolean),
    mutedKeywords: normalizeStringList(row.muted_keywords, 100),
  };
}

export async function updateFeedPreferences(userId: string, input: Record<string, unknown>) {
  const existing = await getFeedPreferences(userId);
  const next: FeedPreferences = {
    lens: input.lens === undefined ? existing.lens : normalizeFeedLens(input.lens),
    discoveryIntensity: input.discoveryIntensity === undefined ? existing.discoveryIntensity : clamp01(input.discoveryIntensity, existing.discoveryIntensity),
    friendPriority: input.friendPriority === undefined ? existing.friendPriority : clamp01(input.friendPriority, existing.friendPriority),
    latestPriority: input.latestPriority === undefined ? existing.latestPriority : clamp01(input.latestPriority, existing.latestPriority),
    reduceReposts: input.reduceReposts === undefined ? existing.reduceReposts : input.reduceReposts === true,
    reducePoliticalContent: input.reducePoliticalContent === undefined ? existing.reducePoliticalContent : input.reducePoliticalContent === true,
    reduceSensitiveContent: input.reduceSensitiveContent === undefined ? existing.reduceSensitiveContent : input.reduceSensitiveContent === true,
    preferProfessionalContent: input.preferProfessionalContent === undefined ? existing.preferProfessionalContent : input.preferProfessionalContent === true,
    preferLocalContent: input.preferLocalContent === undefined ? existing.preferLocalContent : input.preferLocalContent === true,
    localDiscoveryEnabled: input.localDiscoveryEnabled === undefined ? existing.localDiscoveryEnabled : input.localDiscoveryEnabled === true,
    perspectiveBroadeningEnabled: input.perspectiveBroadeningEnabled === undefined ? existing.perspectiveBroadeningEnabled : input.perspectiveBroadeningEnabled === true,
    preferredLanguages: input.preferredLanguages === undefined
      ? existing.preferredLanguages
      : normalizeStringList(input.preferredLanguages, 12).map(normalizeLanguage).filter(Boolean),
    mutedKeywords: input.mutedKeywords === undefined ? existing.mutedKeywords : normalizeStringList(input.mutedKeywords, 100),
  };

  await query(
    `INSERT INTO feed_preferences (
       user_id, lens, discovery_intensity, friend_priority, latest_priority,
       reduce_reposts, reduce_political_content, reduce_sensitive_content,
       prefer_professional_content, prefer_local_content, local_discovery_enabled,
       perspective_broadening_enabled, preferred_languages, muted_keywords, updated_at
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, NOW())
     ON CONFLICT (user_id)
     DO UPDATE SET lens = EXCLUDED.lens,
                   discovery_intensity = EXCLUDED.discovery_intensity,
                   friend_priority = EXCLUDED.friend_priority,
                   latest_priority = EXCLUDED.latest_priority,
                   reduce_reposts = EXCLUDED.reduce_reposts,
                   reduce_political_content = EXCLUDED.reduce_political_content,
                   reduce_sensitive_content = EXCLUDED.reduce_sensitive_content,
                   prefer_professional_content = EXCLUDED.prefer_professional_content,
                   prefer_local_content = EXCLUDED.prefer_local_content,
                   local_discovery_enabled = EXCLUDED.local_discovery_enabled,
                   perspective_broadening_enabled = EXCLUDED.perspective_broadening_enabled,
                   preferred_languages = EXCLUDED.preferred_languages,
                   muted_keywords = EXCLUDED.muted_keywords,
                   updated_at = EXCLUDED.updated_at`,
    [
      userId,
      next.lens,
      next.discoveryIntensity,
      next.friendPriority,
      next.latestPriority,
      next.reduceReposts,
      next.reducePoliticalContent,
      next.reduceSensitiveContent,
      next.preferProfessionalContent,
      next.preferLocalContent,
      next.localDiscoveryEnabled,
      next.perspectiveBroadeningEnabled,
      JSON.stringify(next.preferredLanguages),
      JSON.stringify(next.mutedKeywords),
    ]
  );
  return next;
}

function safeDate(value: unknown): Date | null {
  if (!value) return null;
  const parsed = value instanceof Date ? value : new Date(String(value));
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function encodeCursor(cursor: FeedCursor): string {
  return Buffer.from(JSON.stringify(cursor)).toString("base64url");
}

function decodeCursor(raw: unknown): FeedCursor | null {
  const value = String(raw || "").trim();
  if (!value) return null;
  try {
    const decoded = JSON.parse(Buffer.from(value, "base64url").toString("utf8"));
    if (!decoded || typeof decoded !== "object") return null;
    return decoded as FeedCursor;
  } catch {
    return null;
  }
}

function decodeCursorOrThrow(raw: unknown): FeedCursor | null {
  const value = String(raw || "").trim();
  if (!value) return null;
  const cursor = decodeCursor(value);
  if (!cursor || !cursor.postId || !safeDate(cursor.createdAt)) {
    throw new HttpError(400, "Invalid feed cursor");
  }
  return cursor;
}

async function loadRankingConfig(): Promise<RankingConfig> {
  const config: RankingConfig = {
    ...DEFAULT_CONFIG,
    sourceAllocation: { ...DEFAULT_CONFIG.sourceAllocation },
    weights: { ...DEFAULT_CONFIG.weights },
    diversity: { ...DEFAULT_CONFIG.diversity },
  };

  config.candidateMultiplier = parsePositiveNumber(
    process.env.FEED_CANDIDATE_MULTIPLIER,
    config.candidateMultiplier
  );
  config.maxAgeDays = parsePositiveNumber(process.env.FEED_MAX_AGE_DAYS, config.maxAgeDays);
  config.servedHistoryHours = parsePositiveNumber(
    process.env.FEED_SERVED_HISTORY_HOURS,
    config.servedHistoryHours
  );

  for (const key of Object.keys(config.weights) as Array<keyof RankingConfig["weights"]>) {
    const envKey = `FEED_WEIGHT_${key.replace(/[A-Z]/g, (char) => `_${char}`).toUpperCase()}`;
    config.weights[key] = parsePositiveNumber(process.env[envKey], config.weights[key]);
  }

  try {
    const row = await queryOne(
      `SELECT config_value FROM feed_algorithm_config WHERE config_key = 'default'`
    );
    const dbConfig = row?.config_value || {};
    if (dbConfig && typeof dbConfig === "object") {
      Object.assign(config.weights, dbConfig.weights || {});
      Object.assign(config.sourceAllocation, dbConfig.sourceAllocation || {});
      Object.assign(config.diversity, dbConfig.diversity || {});
      Object.assign(config.quotas, dbConfig.quotas || {});
      if (Number.isFinite(Number(dbConfig.candidateMultiplier))) {
        config.candidateMultiplier = Number(dbConfig.candidateMultiplier);
      }
      if (Number.isFinite(Number(dbConfig.maxAgeDays))) {
        config.maxAgeDays = Number(dbConfig.maxAgeDays);
      }
    }
  } catch {
    // The table is created during startup migrations. Tests may call ranking
    // helpers before the migration block has been installed, so defaults remain valid.
  }

  return config;
}

function cursorPredicate(cursor: FeedCursor | null, post: RankedFeedPost, mode: FeedMode, epsilon: number): boolean {
  if (!cursor) return true;
  const createdAt = new Date(post.created_at).getTime();
  const cursorCreatedAt = safeDate(cursor.createdAt)?.getTime() || 0;
  const postId = String(post.post_id || "");
  const cursorPostId = String(cursor.postId || "");

  if (mode === "following") {
    if (createdAt < cursorCreatedAt) return true;
    if (createdAt === cursorCreatedAt && postId < cursorPostId) return true;
    return false;
  }

  const score = Number(post.rank_score || 0);
  const cursorScore = Number(cursor.score || 0);
  if (score < cursorScore - epsilon) return true;
  if (Math.abs(score - cursorScore) <= epsilon && createdAt < cursorCreatedAt) return true;
  if (Math.abs(score - cursorScore) <= epsilon && createdAt === cursorCreatedAt && postId < cursorPostId) return true;
  return false;
}

function buildNextCursor(items: RankedFeedPost[], mode: FeedMode): string | null {
  const last = items[items.length - 1];
  if (!last) return null;
  return encodeCursor({
    score: mode === "for-you" ? Number(last.rank_score || 0) : undefined,
    createdAt: toIso(last.created_at) || "",
    postId: String(last.post_id || ""),
  });
}

function withBefore(params: unknown[], before?: Date | null): string {
  if (!before) return "";
  params.push(before);
  return `AND p.created_at < $${params.length}`;
}

function placeholders(count: number, offset = 1): string {
  return Array.from({ length: count }, (_, index) => `$${index + offset}`).join(", ");
}

function daysAgo(days: number): Date {
  return new Date(Date.now() - Math.max(1, days) * 24 * 60 * 60 * 1000);
}

function hoursAgo(hours: number): Date {
  return new Date(Date.now() - Math.max(1, hours) * 60 * 60 * 1000);
}

function sourceLimit(limit: number, config: RankingConfig, source: CandidateSource): number {
  const pool = Math.min(config.maxCandidatePool, Math.max(limit * config.candidateMultiplier, limit * 3));
  const share = config.sourceAllocation[source] || 0.1;
  return Math.max(limit, Math.ceil(pool * share));
}

function sourceReason(source: CandidateSource): string {
  switch (source) {
    case "in_network":
      return "from_followed_author";
    case "friend_recent":
      return "friend_recent";
    case "interest":
    case "topic_affinity":
      return "because_you_liked_similar_posts";
    case "semantic_similarity":
      return "similar_to_posts_you_engaged_with";
    case "social_proof":
    case "trusted_network":
      return "trending_in_your_network";
    case "trending":
      return "popular_in_topic";
    case "exploration":
      return "exploration";
    case "emerging_creator":
      return "fresh_voice";
    case "conversation":
      return "active_conversation";
    case "language_affinity":
      return "matches_your_language";
    case "editorial":
      return "editorial";
    case "interacted_authors":
      return "because_you_engaged_with_author";
    case "cold_start":
      return "cold_start_popular";
    default:
      return "recommended";
  }
}

function humanExplanation(reason: string, post?: any): string {
  const topic = Array.isArray(post?.hashtags) && post.hashtags.length > 0
    ? String(post.hashtags[0]).replace(/^#/, "")
    : "";
  switch (reason) {
    case "from_followed_author":
      return "Because you follow this account";
    case "friend_recent":
      return "Recent post from a friend";
    case "because_you_liked_similar_posts":
      return topic ? `Recommended from your interest in ${topic}` : "Because you read similar posts";
    case "similar_to_posts_you_engaged_with":
      return "Similar to posts you engaged with";
    case "trending_in_your_network":
      return "Popular among people you follow";
    case "popular_in_topic":
      return topic ? `Trending in ${topic}` : "Trending on Prava";
    case "exploration":
      return "New post you may like";
    case "fresh_voice":
      return "Fresh voice you may like";
    case "active_conversation":
      return "Active conversation in your network";
    case "matches_your_language":
      return "Matches your language preference";
    case "editorial":
      return "Curated by Prava";
    case "because_you_engaged_with_author":
      return "Because you engaged with this author before";
    case "cold_start_popular":
      return "Popular quality post to get you started";
    default:
      return "Recommended for you";
  }
}

function recommendationMetadata(candidate: Candidate, reason: string, post: any) {
  const sources = [...candidate.sources];
  return {
    reasonCode: reason,
    explanation: humanExplanation(reason, post),
    feedSource: sources[0] || "recommended",
    topicMatch: Array.isArray(post.hashtags) && post.hashtags.length > 0 ? String(post.hashtags[0]) : null,
    fromFollowedAccount: candidate.sources.has("in_network"),
    fromFriend: candidate.sources.has("friend_recent"),
    trending: candidate.sources.has("trending"),
    exploration: candidate.sources.has("exploration") || candidate.sources.has("emerging_creator"),
    editorial: candidate.sources.has("editorial"),
    sponsored: false,
  };
}

async function fetchInNetworkCandidates(viewerId: string, limit: number, config: RankingConfig, before?: Date | null) {
  const params: unknown[] = [viewerId, daysAgo(Math.ceil(config.maxAgeDays))];
  const beforeSql = withBefore(params, before);
  params.push(limit);
  return queryMany(
    `SELECT p.*
     FROM posts p
     LEFT JOIN follows f
       ON f.follower_id = $1 AND f.following_id = p.author_id
     WHERE (p.author_id = $1 OR f.following_id IS NOT NULL)
       AND p.created_at > $2
       AND p.body <> ''
       AND p.deleted_at IS NULL
       AND p.moderation_state = 'active'
       ${beforeSql}
     ORDER BY p.created_at DESC, p.post_id DESC
     LIMIT $${params.length}`,
    params
  );
}

async function fetchFriendRecentCandidates(viewerId: string, limit: number, config: RankingConfig, before?: Date | null) {
  const params: unknown[] = [viewerId, daysAgo(Math.ceil(config.maxAgeDays))];
  const beforeSql = withBefore(params, before);
  params.push(limit);
  return queryMany(
    `SELECT p.*
     FROM posts p
     JOIN follows outgoing
       ON outgoing.follower_id = $1 AND outgoing.following_id = p.author_id
     JOIN follows incoming
       ON incoming.follower_id = p.author_id AND incoming.following_id = $1
     WHERE p.created_at > $2
       AND p.body <> ''
       AND p.deleted_at IS NULL
       AND p.moderation_state = 'active'
       ${beforeSql}
     ORDER BY p.created_at DESC, p.post_id DESC
     LIMIT $${params.length}`,
    params
  );
}

async function fetchInteractedAuthorCandidates(viewerId: string, limit: number, config: RankingConfig, before?: Date | null) {
  const params: unknown[] = [viewerId, daysAgo(Math.ceil(config.maxAgeDays))];
  const beforeSql = withBefore(params, before);
  params.push(limit);
  return queryMany(
    `WITH interacted AS (
       SELECT author_id, MAX(signal_at) AS last_signal_at
       FROM (
         SELECT p.author_id, pl.created_at AS signal_at
         FROM post_likes pl
         JOIN posts p ON p.post_id = pl.post_id
         WHERE pl.user_id = $1
         UNION ALL
         SELECT p.author_id, c.created_at AS signal_at
         FROM comments c
         JOIN posts p ON p.post_id = c.post_id
         WHERE c.author_id = $1
         UNION ALL
         SELECT fe.author_id, fe.created_at AS signal_at
         FROM feed_events fe
         WHERE fe.user_id = $1
           AND fe.author_id IS NOT NULL
           AND fe.event_type IN ('view', 'dwell', 'click', 'post_open', 'profile_click', 'share', 'bookmark')
       ) signals
       WHERE author_id IS NOT NULL AND author_id <> $1
       GROUP BY author_id
       ORDER BY MAX(signal_at) DESC
       LIMIT 80
     )
     SELECT p.*
     FROM posts p
     JOIN interacted i ON i.author_id = p.author_id
     WHERE p.created_at > $2
       AND p.body <> ''
       AND p.deleted_at IS NULL
       AND p.moderation_state = 'active'
       ${beforeSql}
     ORDER BY i.last_signal_at DESC, p.created_at DESC
     LIMIT $${params.length}`,
    params
  );
}

async function fetchInterestCandidates(viewerId: string, limit: number, config: RankingConfig, before?: Date | null) {
  const params: unknown[] = [viewerId, daysAgo(Math.ceil(config.maxAgeDays))];
  const beforeSql = withBefore(params, before);
  params.push(limit);
  return queryMany(
    `WITH topics AS (
       SELECT topic, score
       FROM user_topic_affinities
       WHERE user_id = $1 AND score > 0
       UNION ALL
       SELECT pt.tag AS topic, 1::double precision AS score
       FROM post_likes pl
       JOIN post_tags pt ON pt.post_id = pl.post_id
       WHERE pl.user_id = $1
       UNION ALL
       SELECT pt.tag AS topic, 0.8::double precision AS score
       FROM comments c
       JOIN post_tags pt ON pt.post_id = c.post_id
       WHERE c.author_id = $1
     ),
     ranked_topics AS (
       SELECT topic, SUM(score) AS score
       FROM topics
       WHERE topic <> ''
       GROUP BY topic
       ORDER BY SUM(score) DESC
       LIMIT 24
     )
     SELECT p.*
     FROM ranked_topics rt
     JOIN post_tags pt ON pt.tag = rt.topic
     JOIN posts p ON p.post_id = pt.post_id
     WHERE p.author_id <> $1
       AND p.created_at > $2
       AND p.body <> ''
       AND p.deleted_at IS NULL
       AND p.moderation_state = 'active'
       ${beforeSql}
     ORDER BY rt.score DESC, p.created_at DESC
     LIMIT $${params.length}`,
    params
  );
}

async function fetchTopicCandidates(
  viewerId: string,
  topics: string[],
  limit: number,
  config: RankingConfig,
  before?: Date | null
) {
  const normalizedTopics = [...new Set(topics.map(normalizeTopic).filter(Boolean))].slice(0, 40);
  if (normalizedTopics.length === 0) return [];
  const params: unknown[] = [viewerId, normalizedTopics, daysAgo(Math.ceil(config.maxAgeDays))];
  const beforeSql = withBefore(params, before);
  params.push(limit);
  return queryMany(
    `WITH topic_posts AS (
       SELECT post_id, topic, weight, created_at FROM post_topics WHERE topic = ANY($2::text[])
       UNION ALL
       SELECT post_id, tag AS topic, 1::double precision AS weight, created_at FROM post_tags WHERE tag = ANY($2::text[])
     )
     SELECT p.*
     FROM topic_posts pt
     JOIN posts p ON p.post_id = pt.post_id
     WHERE pt.topic = ANY($2::text[])
       AND p.author_id <> $1
       AND p.created_at > $3
       AND p.body <> ''
       AND p.deleted_at IS NULL
       AND p.moderation_state = 'active'
       ${beforeSql}
     ORDER BY pt.weight DESC, p.created_at DESC, p.post_id DESC
     LIMIT $${params.length}`,
    params
  );
}

async function fetchFollowedTopicCandidates(viewerId: string, limit: number, config: RankingConfig, before?: Date | null) {
  const rows = await queryMany(
    `SELECT topic
     FROM user_followed_topics
     WHERE user_id = $1
     ORDER BY followed_at DESC
     LIMIT 40`,
    [viewerId]
  );
  return fetchTopicCandidates(viewerId, rows.map((row) => row.topic), limit, config, before);
}

async function fetchSocialProofCandidates(viewerId: string, limit: number, config: RankingConfig, before?: Date | null) {
  const params: unknown[] = [viewerId, daysAgo(Math.ceil(config.maxAgeDays))];
  const beforeSql = withBefore(params, before);
  params.push(limit);
  return queryMany(
    `WITH network_engagement AS (
       SELECT post_id, SUM(weight) AS proof_score, MAX(signal_at) AS last_signal_at
       FROM (
         SELECT pl.post_id, 1.0 AS weight, pl.created_at AS signal_at
         FROM post_likes pl
         JOIN follows f ON f.following_id = pl.user_id
         WHERE f.follower_id = $1
         UNION ALL
         SELECT c.post_id, 1.7 AS weight, c.created_at AS signal_at
         FROM comments c
         JOIN follows f ON f.following_id = c.author_id
         WHERE f.follower_id = $1
         UNION ALL
         SELECT fe.post_id, 1.3 AS weight, fe.created_at AS signal_at
         FROM feed_events fe
         JOIN follows f ON f.following_id = fe.user_id
         WHERE f.follower_id = $1
           AND fe.post_id IS NOT NULL
           AND fe.event_type IN ('share', 'bookmark', 'post_open')
       ) signals
       GROUP BY post_id
     )
     SELECT p.*
     FROM network_engagement ne
     JOIN posts p ON p.post_id = ne.post_id
     WHERE p.author_id <> $1
       AND p.created_at > $2
       AND p.body <> ''
       AND p.deleted_at IS NULL
       AND p.moderation_state = 'active'
       ${beforeSql}
     ORDER BY ne.proof_score DESC, ne.last_signal_at DESC, p.created_at DESC
     LIMIT $${params.length}`,
    params
  );
}

async function fetchConversationCandidates(viewerId: string, limit: number, config: RankingConfig, before?: Date | null) {
  const params: unknown[] = [viewerId, daysAgo(Math.ceil(config.maxAgeDays))];
  const beforeSql = withBefore(params, before);
  params.push(limit);
  return queryMany(
    `SELECT p.*
     FROM posts p
     LEFT JOIN post_engagement_stats pes ON pes.post_id = p.post_id
     LEFT JOIN follows f ON f.follower_id = $1 AND f.following_id = p.author_id
     WHERE p.created_at > $2
       AND p.body <> ''
       AND p.deleted_at IS NULL
       AND p.moderation_state = 'active'
       AND (
         p.comment_count > 0
         OR COALESCE(pes.reply_count, 0) > 0
         OR p.parent_post_id IS NOT NULL
       )
       ${beforeSql}
     ORDER BY (p.comment_count + COALESCE(pes.reply_count, 0) * 2 + CASE WHEN f.following_id IS NOT NULL THEN 5 ELSE 0 END) DESC,
              p.created_at DESC
     LIMIT $${params.length}`,
    params
  );
}

async function fetchLanguageAffinityCandidates(
  viewerId: string,
  languages: string[],
  limit: number,
  config: RankingConfig,
  before?: Date | null
) {
  const normalized = [...new Set(languages.map(normalizeLanguage).filter(Boolean))].slice(0, 8);
  if (normalized.length === 0) return [];
  const params: unknown[] = [viewerId, normalized, daysAgo(Math.ceil(config.maxAgeDays))];
  const beforeSql = withBefore(params, before);
  params.push(limit);
  return queryMany(
    `SELECT p.*
     FROM posts p
     WHERE p.author_id <> $1
       AND p.language = ANY($2::text[])
       AND p.created_at > $3
       AND p.body <> ''
       AND p.deleted_at IS NULL
       AND p.moderation_state = 'active'
       ${beforeSql}
     ORDER BY p.quality_score DESC, p.created_at DESC
     LIMIT $${params.length}`,
    params
  );
}

async function fetchTrendingCandidates(viewerId: string, limit: number, config: RankingConfig, before?: Date | null) {
  const params: unknown[] = [daysAgo(Math.ceil(config.maxAgeDays))];
  const beforeSql = withBefore(params, before);
  params.push(limit);
  return queryMany(
    `SELECT p.*
     FROM posts p
     LEFT JOIN post_engagement_stats pes ON pes.post_id = p.post_id
     WHERE p.created_at > $1
       AND p.body <> ''
       AND p.deleted_at IS NULL
       AND p.moderation_state = 'active'
       ${beforeSql}
     ORDER BY COALESCE(pes.trend_velocity_score, 0) DESC,
              (p.like_count * 3 + p.comment_count * 4 + p.share_count * 5) DESC,
              p.created_at DESC
     LIMIT $${params.length}`,
    params
  );
}

async function fetchExplorationCandidates(viewerId: string, limit: number, config: RankingConfig, before?: Date | null) {
  const params: unknown[] = [viewerId, daysAgo(Math.ceil(config.maxAgeDays))];
  const beforeSql = withBefore(params, before);
  params.push(limit);
  return queryMany(
    `SELECT p.*
     FROM posts p
     LEFT JOIN follows f
       ON f.follower_id = $1 AND f.following_id = p.author_id
     WHERE p.author_id <> $1
       AND f.following_id IS NULL
       AND p.created_at > $2
       AND p.body <> ''
       AND p.deleted_at IS NULL
       AND p.moderation_state = 'active'
       ${beforeSql}
     ORDER BY p.quality_score DESC,
              p.created_at DESC
     LIMIT $${params.length}`,
    params
  );
}

async function fetchEmergingCreatorCandidates(viewerId: string, limit: number, config: RankingConfig, before?: Date | null) {
  const params: unknown[] = [viewerId, daysAgo(Math.ceil(config.maxAgeDays))];
  const beforeSql = withBefore(params, before);
  params.push(limit);
  return queryMany(
    `SELECT p.*
     FROM posts p
     LEFT JOIN follows f
       ON f.follower_id = $1 AND f.following_id = p.author_id
     WHERE p.author_id <> $1
       AND f.following_id IS NULL
       AND p.created_at > $2
       AND p.body <> ''
       AND p.deleted_at IS NULL
       AND p.moderation_state = 'active'
       AND p.quality_score >= 0.55
       AND COALESCE(p.impression_count, 0) < 500
       ${beforeSql}
     ORDER BY p.quality_score DESC, p.created_at DESC
     LIMIT $${params.length}`,
    params
  );
}

async function fetchEditorialCandidates(limit: number, before?: Date | null) {
  const params: unknown[] = [];
  const beforeSql = withBefore(params, before);
  params.push(limit);
  return queryMany(
    `SELECT p.*, e.label AS editorial_label, e.priority AS editorial_priority
     FROM editorial_feed_items e
     JOIN posts p ON p.post_id = e.post_id
     WHERE e.starts_at <= NOW()
       AND (e.ends_at IS NULL OR e.ends_at > NOW())
       AND p.body <> ''
       AND p.deleted_at IS NULL
       AND p.moderation_state = 'active'
       ${beforeSql}
     ORDER BY e.priority DESC, p.created_at DESC
     LIMIT $${params.length}`,
    params
  );
}

async function fetchColdStartCandidates(limit: number, config: RankingConfig, before?: Date | null) {
  const params: unknown[] = [daysAgo(Math.ceil(config.maxAgeDays * 2))];
  const beforeSql = withBefore(params, before);
  params.push(limit);
  return queryMany(
    `SELECT p.*
     FROM posts p
     LEFT JOIN post_engagement_stats pes ON pes.post_id = p.post_id
     WHERE p.body <> ''
       AND p.deleted_at IS NULL
       AND p.moderation_state = 'active'
       AND p.created_at > $1
       ${beforeSql}
     ORDER BY COALESCE(pes.quality_score, p.quality_score, 1) DESC,
              COALESCE(pes.trend_velocity_score, 0) DESC,
              p.created_at DESC
     LIMIT $${params.length}`,
    params
  );
}

function mergeCandidateRows(target: Map<string, Candidate>, rows: any[], source: CandidateSource) {
  const reason = sourceReason(source);
  for (const row of rows) {
    const id = String(row.post_id || "");
    if (!id) continue;
    const existing = target.get(id);
    if (existing) {
      existing.sources.add(source);
      existing.reasons.add(reason);
    } else {
      target.set(id, {
        post: row,
        sources: new Set([source]),
        reasons: new Set([reason]),
      });
    }
  }
}

async function collectCandidates(
  viewerId: string,
  limit: number,
  config: RankingConfig,
  before?: Date | null,
  preferences: FeedPreferences = DEFAULT_FEED_PREFERENCES,
  mode: FeedMode = "for-you"
): Promise<{ candidates: Candidate[]; sourceCounts: Record<string, number> }> {
  const [
    inNetwork,
    friends,
    interacted,
    interest,
    followedTopics,
    socialProof,
    trending,
    exploration,
    emergingCreators,
    conversations,
    languageAffinity,
    editorial,
  ] = await Promise.all([
    fetchInNetworkCandidates(viewerId, sourceLimit(limit, config, "in_network"), config, before),
    fetchFriendRecentCandidates(viewerId, sourceLimit(limit, config, "friend_recent"), config, before),
    fetchInteractedAuthorCandidates(viewerId, sourceLimit(limit, config, "interacted_authors"), config, before),
    fetchInterestCandidates(viewerId, sourceLimit(limit, config, "interest"), config, before),
    fetchFollowedTopicCandidates(viewerId, sourceLimit(limit, config, "topic_affinity"), config, before),
    fetchSocialProofCandidates(viewerId, sourceLimit(limit, config, "social_proof"), config, before),
    fetchTrendingCandidates(viewerId, sourceLimit(limit, config, "trending"), config, before),
    fetchExplorationCandidates(
      viewerId,
      Math.ceil(sourceLimit(limit, config, "exploration") * (mode === "explore" ? 2.2 : 1 + preferences.discoveryIntensity)),
      config,
      before
    ),
    fetchEmergingCreatorCandidates(viewerId, sourceLimit(limit, config, "emerging_creator"), config, before),
    fetchConversationCandidates(viewerId, sourceLimit(limit, config, "conversation"), config, before),
    fetchLanguageAffinityCandidates(viewerId, preferences.preferredLanguages, sourceLimit(limit, config, "language_affinity"), config, before),
    fetchEditorialCandidates(sourceLimit(limit, config, "editorial"), before),
  ]);

  const map = new Map<string, Candidate>();
  mergeCandidateRows(map, inNetwork, "in_network");
  mergeCandidateRows(map, friends, "friend_recent");
  mergeCandidateRows(map, interacted, "interacted_authors");
  mergeCandidateRows(map, interest, "interest");
  mergeCandidateRows(map, followedTopics, "topic_affinity");
  mergeCandidateRows(map, socialProof, "social_proof");
  mergeCandidateRows(map, trending, "trending");
  mergeCandidateRows(map, exploration, "exploration");
  mergeCandidateRows(map, emergingCreators, "emerging_creator");
  mergeCandidateRows(map, conversations, "conversation");
  mergeCandidateRows(map, languageAffinity, "language_affinity");
  mergeCandidateRows(map, editorial, "editorial");

  if (map.size < limit) {
    mergeCandidateRows(
      map,
      await fetchColdStartCandidates(sourceLimit(limit, config, "cold_start"), config, before),
      "cold_start"
    );
  }

  return {
    candidates: [...map.values()],
    sourceCounts: {
      in_network: inNetwork.length,
      friend_recent: friends.length,
      interacted_authors: interacted.length,
      interest: interest.length,
      topic_affinity: followedTopics.length,
      social_proof: socialProof.length,
      trending: trending.length,
      exploration: exploration.length,
      emerging_creator: emergingCreators.length,
      conversation: conversations.length,
      language_affinity: languageAffinity.length,
      editorial: editorial.length,
      cold_start: Math.max(
        0,
        map.size
          - inNetwork.length
          - friends.length
          - interacted.length
          - interest.length
          - followedTopics.length
          - socialProof.length
          - trending.length
          - exploration.length
          - emergingCreators.length
          - conversations.length
          - languageAffinity.length
          - editorial.length
      ),
    },
  };
}

async function hardFilterCandidates(
  viewerId: string,
  candidates: Candidate[],
  config: RankingConfig,
  sessionId?: string,
  preferences: FeedPreferences = DEFAULT_FEED_PREFERENCES,
  options: { allowRecentlyServed?: boolean; strictOutOfNetwork?: boolean } = {}
): Promise<{ candidates: Candidate[]; filteredCount: number }> {
  if (candidates.length === 0) {
    return { candidates: [], filteredCount: 0 };
  }

  const ids = candidates.map((candidate) => String(candidate.post.post_id));
  const idSql = placeholders(ids.length);
  const postRows = await queryMany(
    `SELECT p.post_id, p.author_id, p.body, p.hashtags, p.share_of_post_id,
            p.deleted_at, p.moderation_state, p.visibility, p.sensitive_label,
            p.spam_score, p.toxicity_score, p.clickbait_score, p.quality_score,
            author.deleted_at AS author_deleted_at,
            author_settings.settings AS author_settings
     FROM posts p
     JOIN users author ON author.user_id = p.author_id
     LEFT JOIN user_settings author_settings ON author_settings.user_id = p.author_id
     WHERE p.post_id IN (${idSql})`,
    ids
  );
  const postMap = new Map(postRows.map((row) => [row.post_id, row]));
  const authorIds = [...new Set(postRows.map((row) => String(row.author_id)).filter(Boolean))];
  const authorSql = authorIds.length ? placeholders(authorIds.length, 2) : "";

  const [
    followingRows,
    friendRows,
    blockRows,
    muteRows,
    hiddenRows,
    notInterestedRows,
    mutedWords,
    mutedTopicRows,
    servedRows,
  ] = await Promise.all([
    authorIds.length
      ? queryMany(
          `SELECT following_id FROM follows WHERE follower_id = $1 AND following_id IN (${authorSql})`,
          [viewerId, ...authorIds]
        )
      : Promise.resolve([]),
    authorIds.length
      ? queryMany(
          `SELECT outgoing.following_id
           FROM follows outgoing
           JOIN follows incoming
             ON incoming.follower_id = outgoing.following_id
            AND incoming.following_id = $1
           WHERE outgoing.follower_id = $1
             AND outgoing.following_id IN (${authorSql})`,
          [viewerId, ...authorIds]
        )
      : Promise.resolve([]),
    authorIds.length
      ? queryMany(
          `SELECT blocker_id, blocked_id
           FROM user_blocks
           WHERE (blocker_id = $1 AND blocked_id IN (${authorSql}))
              OR (blocked_id = $1 AND blocker_id IN (${authorSql}))`,
          [viewerId, ...authorIds]
        )
      : Promise.resolve([]),
    authorIds.length
      ? queryMany(
          `SELECT muted_id FROM user_mutes WHERE muter_id = $1 AND muted_id IN (${authorSql})`,
          [viewerId, ...authorIds]
        )
      : Promise.resolve([]),
    queryMany(
      `SELECT post_id FROM post_hidden WHERE user_id = $1 AND post_id IN (${placeholders(ids.length, 2)})`,
      [viewerId, ...ids]
    ),
    queryMany(
      `SELECT post_id FROM post_not_interested WHERE user_id = $1 AND post_id IN (${placeholders(ids.length, 2)})`,
      [viewerId, ...ids]
    ),
    queryMany(
      `SELECT phrase_lower FROM user_muted_words WHERE user_id = $1`,
      [viewerId]
    ),
    queryMany(
      `SELECT topic, snoozed_until
       FROM feed_muted_topics
       WHERE user_id = $1
         AND (snoozed_until IS NULL OR snoozed_until > NOW())`,
      [viewerId]
    ),
    sessionId && !options.allowRecentlyServed
      ? queryMany(
          `SELECT post_id
           FROM feed_served_history
           WHERE user_id = $1
             AND session_id = $2
             AND created_at > $3
             AND post_id IN (${placeholders(ids.length, 4)})`,
          [viewerId, sessionId, hoursAgo(config.servedHistoryHours), ...ids]
        )
      : Promise.resolve([]),
  ]);

  const following = new Set(followingRows.map((row) => row.following_id));
  const friends = new Set(friendRows.map((row) => row.following_id));
  const blockedAuthors = new Set<string>();
  for (const row of blockRows) {
    const other = row.blocker_id === viewerId ? row.blocked_id : row.blocker_id;
    if (other) blockedAuthors.add(other);
  }
  const mutedAuthors = new Set(muteRows.map((row) => row.muted_id));
  const hidden = new Set(hiddenRows.map((row) => row.post_id));
  const notInterested = new Set(notInterestedRows.map((row) => row.post_id));
  const served = new Set(servedRows.map((row) => row.post_id));
  const mutedPhrases = mutedWords
    .map((row) => String(row.phrase_lower || "").trim().toLowerCase())
    .filter(Boolean);
  const preferenceMutedPhrases = preferences.mutedKeywords.map((word) => word.toLowerCase()).filter(Boolean);
  const mutedTopics = new Set(mutedTopicRows.map((row) => normalizeTopic(row.topic)).filter(Boolean));

  const filtered = candidates.filter((candidate) => {
    const post = postMap.get(candidate.post.post_id);
    if (!post) return false;
    const postId = String(post.post_id);
    const authorId = String(post.author_id);
    if (post.deleted_at || post.author_deleted_at) return false;
    if (String(post.moderation_state || "active") !== "active") return false;
    if (!String(post.body || "").trim()) return false;
    if (blockedAuthors.has(authorId) || mutedAuthors.has(authorId)) return false;
    if (hidden.has(postId) || notInterested.has(postId) || served.has(postId)) return false;
    if (preferences.reduceReposts && post.share_of_post_id) return false;
    const visibility = String(post.visibility || "public");
    if (authorId !== viewerId) {
      if (visibility === "private") return false;
      if (visibility === "friends" && !friends.has(authorId)) return false;
      if (visibility === "followers" && !following.has(authorId)) return false;
    }
    if (preferences.reduceSensitiveContent && String(post.sensitive_label || "")) return false;
    if (Number(post.toxicity_score || 0) >= 0.82 || Number(post.spam_score || 0) >= 0.78) return false;
    if (options.strictOutOfNetwork && !following.has(authorId) && authorId !== viewerId) {
      if (Number(post.quality_score || 0) < 0.35) return false;
      if (Number(post.spam_score || 0) >= 0.35 || Number(post.clickbait_score || 0) >= 0.6) return false;
    }

    const settings = post.author_settings || {};
    const privateAccount = settings?.privateAccount === true;
    if (privateAccount && authorId !== viewerId && !following.has(authorId)) return false;

    const hashtags = Array.isArray(post.hashtags) ? post.hashtags.map(normalizeTopic).filter(Boolean) : [];
    if (hashtags.some((tag: string) => mutedTopics.has(tag))) return false;

    const allMutedPhrases = [...mutedPhrases, ...preferenceMutedPhrases];
    if (allMutedPhrases.length > 0) {
      const body = String(post.body || "").toLowerCase();
      const hashtagText = JSON.stringify(post.hashtags || []).toLowerCase();
      if (allMutedPhrases.some((phrase) => body.includes(phrase) || hashtagText.includes(phrase))) {
        return false;
      }
    }

    return true;
  });
  return {
    candidates: filtered,
    filteredCount: candidates.length - filtered.length,
  };
}

async function hydrateFeatures(viewerId: string, posts: any[]): Promise<FeatureBundle> {
  const postIds = posts.map((post) => post.post_id).filter(Boolean);
  const authorIds = [...new Set(posts.map((post) => post.author_id).filter(Boolean))];

  if (postIds.length === 0) {
    return {
      stats: new Map(),
      authorAffinities: new Map(),
      userTopics: new Map(),
      postTopics: new Map(),
      socialProof: new Map(),
      impressions: new Map(),
    };
  }

  const [
    statsRows,
    affinityRows,
    userTopicRows,
    postTopicRows,
    socialProofRows,
    impressionRows,
  ] = await Promise.all([
    queryMany(`SELECT * FROM post_engagement_stats WHERE post_id = ANY($1::text[])`, [postIds]),
    authorIds.length
      ? queryMany(
          `SELECT author_id, score, positive_count, negative_count
           FROM user_author_affinities
           WHERE user_id = $1 AND author_id = ANY($2::text[])`,
          [viewerId, authorIds]
        )
      : Promise.resolve([]),
    queryMany(
      `SELECT topic, score
       FROM user_topic_affinities
       WHERE user_id = $1 AND score > 0
       ORDER BY score DESC
       LIMIT 80`,
      [viewerId]
    ),
    queryMany(
      `SELECT post_id, topic, weight FROM post_topics WHERE post_id = ANY($1::text[])
       UNION ALL
       SELECT post_id, tag AS topic, 1::double precision AS weight FROM post_tags WHERE post_id = ANY($1::text[])`,
      [postIds]
    ),
    queryMany(
      `SELECT post_id, SUM(weight)::double precision AS score
       FROM (
         SELECT pl.post_id, 1.0 AS weight
         FROM post_likes pl
         JOIN follows f ON f.following_id = pl.user_id
         WHERE f.follower_id = $1 AND pl.post_id = ANY($2::text[])
         UNION ALL
         SELECT c.post_id, 1.7 AS weight
         FROM comments c
         JOIN follows f ON f.following_id = c.author_id
         WHERE f.follower_id = $1 AND c.post_id = ANY($2::text[])
       ) s
       GROUP BY post_id`,
      [viewerId, postIds]
    ),
    queryMany(
      `SELECT post_id, impression_count, total_dwell_ms, engaged_at, negative_at
       FROM feed_impressions
       WHERE user_id = $1 AND post_id = ANY($2::text[])`,
      [viewerId, postIds]
    ),
  ]);

  const postTopics = new Map<string, Array<{ topic: string; weight: number }>>();
  for (const row of postTopicRows) {
    const postId = String(row.post_id || "");
    const topic = String(row.topic || "").toLowerCase();
    if (!postId || !topic) continue;
    const list = postTopics.get(postId) || [];
    if (!list.some((item) => item.topic === topic)) {
      list.push({ topic, weight: Number(row.weight || 1) });
    }
    postTopics.set(postId, list);
  }

  return {
    stats: new Map(statsRows.map((row) => [row.post_id, row])),
    authorAffinities: new Map(affinityRows.map((row) => [row.author_id, row])),
    userTopics: new Map(userTopicRows.map((row) => [String(row.topic), Number(row.score || 0)])),
    postTopics,
    socialProof: new Map(socialProofRows.map((row) => [row.post_id, Number(row.score || 0)])),
    impressions: new Map(impressionRows.map((row) => [row.post_id, row])),
  };
}

function interestScore(postId: string, features: FeatureBundle): number {
  const topics = features.postTopics.get(postId) || [];
  if (topics.length === 0 || features.userTopics.size === 0) return 0;
  let score = 0;
  let weight = 0;
  for (const topic of topics) {
    const affinity = features.userTopics.get(topic.topic) || 0;
    if (affinity <= 0) continue;
    score += clamp(affinity / 12) * topic.weight;
    weight += topic.weight;
  }
  return weight > 0 ? clamp(score / weight) : 0;
}

function recencyScore(createdAt: unknown, halfLifeHours = 36): number {
  const created = safeDate(createdAt);
  if (!created) return 0;
  const ageHours = Math.max(0, (Date.now() - created.getTime()) / 3_600_000);
  return clamp(Math.exp(-ageHours / halfLifeHours));
}

export interface ScoringProvider {
  score(input: {
    viewerId: string;
    candidate: Candidate;
    features: FeatureBundle;
    config: RankingConfig;
  }): { score: number; breakdown: Record<string, number> };
}

export class HeuristicScoringProvider implements ScoringProvider {
  score({ candidate, features, config }: {
    viewerId: string;
    candidate: Candidate;
    features: FeatureBundle;
    config: RankingConfig;
  }) {
    const post = candidate.post;
    const stats = features.stats.get(post.post_id) || {};
    const authorAffinity = features.authorAffinities.get(post.author_id) || {};
    const impression = features.impressions.get(post.post_id) || {};

    const recency = recencyScore(post.created_at);
    const affinity = clamp(
      (candidate.sources.has("in_network") ? 0.32 : 0)
      + (candidate.sources.has("friend_recent") ? 0.35 : 0)
      + Math.max(0, Number(authorAffinity.score || 0)) / 16
    );
    const interest = clamp(
      interestScore(post.post_id, features)
      + (candidate.sources.has("topic_affinity") ? 0.18 : 0)
      + (candidate.sources.has("language_affinity") ? 0.12 : 0)
    );

    const weightedEngagement =
      Number(stats.like_count ?? post.like_count ?? 0)
      + Number(stats.comment_count ?? post.comment_count ?? 0) * 1.8
      + Number(stats.reply_count || 0) * 1.4
      + Number(stats.share_count ?? post.share_count ?? 0) * 2.4
      + Number(stats.bookmark_count || 0) * 2
      + Math.min(Number(stats.total_dwell_ms || 0) / 30_000, 20);
    const impressions = Math.max(
      Number(stats.impression_count || 0),
      Number(post.impression_count || 0),
      Number(impression.impression_count || 0),
      1
    );
    const bayesianRate = (weightedEngagement + 8 * 0.04) / (impressions + 8);
    const engagement = clamp(bayesianRate * 2 + Math.log1p(weightedEngagement) / 8);

    const trend = clamp(Number(stats.trend_velocity_score || 0) / 25 + (candidate.sources.has("trending") ? 0.08 : 0));
    const socialProof = clamp(Math.log1p(features.socialProof.get(post.post_id) || 0) / Math.log(12) + (candidate.sources.has("trusted_network") ? 0.1 : 0));
    const reportRatio = Number(stats.report_count || 0) / Math.max(1, impressions);
    const negativeRate = Number(stats.negative_count || 0) / Math.max(1, impressions);
    const quality = clamp(Number(stats.quality_score ?? post.quality_score ?? 1) - reportRatio * 2 - negativeRate);
    const exploration = candidate.sources.has("exploration")
      || candidate.sources.has("emerging_creator")
      || candidate.sources.has("cold_start")
      ? 1
      : 0;
    const negativeFeedback = clamp(
      negativeRate
      + Math.max(0, Number(authorAffinity.negative_count || 0) - Number(authorAffinity.positive_count || 0)) / 20
      + (Number(impression.impression_count || 0) >= 3 && !impression.engaged_at ? 0.08 : 0)
    );
    const spam = clamp(reportRatio * 3 + (quality < 0.35 ? 0.25 : 0));

    const breakdown = {
      recency,
      affinity,
      interest,
      engagement,
      trend,
      socialProof,
      quality,
      exploration,
      negativeFeedback,
      spam,
    };

    const score =
      config.weights.recency * recency
      + config.weights.affinity * affinity
      + config.weights.interest * interest
      + config.weights.engagement * engagement
      + config.weights.trend * trend
      + config.weights.socialProof * socialProof
      + config.weights.quality * quality
      + config.weights.exploration * exploration
      + (candidate.sources.has("conversation") ? 0.04 : 0)
      + (candidate.sources.has("editorial") ? 0.03 : 0)
      - config.weights.negativeFeedback * negativeFeedback
      - config.weights.spam * spam;

    return {
      score: Number(score.toFixed(8)),
      breakdown,
    };
  }
}

export class MlScoringProvider implements ScoringProvider {
  score(): { score: number; breakdown: Record<string, number> } {
    throw new Error("ML scoring provider is not enabled. Train and deploy a real model before using it.");
  }
}

function diversify(scored: RankedFeedPost[], config: RankingConfig): RankedFeedPost[] {
  const authorCounts = new Map<string, number>();
  const topicCounts = new Map<string, number>();
  let lastAuthor = "";

  const adjusted = scored.map((post) => {
    const authorId = String(post.author_id || "");
    const authorCount = authorCounts.get(authorId) || 0;
    const topics = Array.isArray(post.hashtags) ? post.hashtags.map((tag: string) => String(tag).toLowerCase()) : [];
    const topicPenalty = topics.reduce((sum, topic) => sum + (topicCounts.get(topic) || 0) * config.diversity.topicRepeatPenalty, 0);
    const sameAuthorPenalty = lastAuthor && lastAuthor === authorId ? config.diversity.sameAuthorConsecutivePenalty : 0;
    const repeatPenalty = authorCount * config.diversity.authorRepeatPenalty + topicPenalty + sameAuthorPenalty;
    const next = {
      ...post,
      rank_score: Number((Number(post.rank_score || 0) - repeatPenalty).toFixed(8)),
      score_breakdown: {
        ...(post.score_breakdown || {}),
        repetitionPenalty: repeatPenalty,
      },
    };
    authorCounts.set(authorId, authorCount + 1);
    for (const topic of topics) {
      topicCounts.set(topic, (topicCounts.get(topic) || 0) + 1);
    }
    lastAuthor = authorId;
    return next;
  });

  adjusted.sort((a, b) => Number(b.rank_score || 0) - Number(a.rank_score || 0) || new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
  return adjusted;
}

function rankCandidates(
  viewerId: string,
  candidates: Candidate[],
  features: FeatureBundle,
  config: RankingConfig,
  provider: ScoringProvider
): RankedFeedPost[] {
  const ranked = candidates.map((candidate) => {
    const result = provider.score({ viewerId, candidate, features, config });
    const reasons = [...candidate.reasons];
    const primaryReason = reasons[0] || "recommended";
    return {
      ...candidate.post,
      rank_score: result.score,
      recommendation_reason: primaryReason,
      recommendation_explanation: humanExplanation(primaryReason, candidate.post),
      recommendation_metadata: recommendationMetadata(candidate, primaryReason, candidate.post),
      recommendation_reasons: reasons,
      candidate_sources: [...candidate.sources],
      score_breakdown: result.breakdown,
    };
  });

  ranked.sort((a, b) => Number(b.rank_score || 0) - Number(a.rank_score || 0) || new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
  return diversify(ranked, config);
}

async function buildFollowingPage(
  viewerId: string,
  limit: number,
  cursor: FeedCursor | null,
  before?: Date | null,
  sessionId?: string,
  preferences: FeedPreferences = DEFAULT_FEED_PREFERENCES
): Promise<FeedPageResult> {
  const started = Date.now();
  const config = await loadRankingConfig();
  const effectiveSessionId = sessionId || generateId();
  const rows = await fetchInNetworkCandidates(viewerId, Math.min(config.maxCandidatePool, limit * 4), config, before);
  const map = new Map<string, Candidate>();
  mergeCandidateRows(map, rows, "in_network");
  const hardFiltered = await hardFilterCandidates(viewerId, [...map.values()], config, undefined, preferences, {
    allowRecentlyServed: true,
  });
  const ranked = hardFiltered.candidates
    .map((candidate) => ({
      ...candidate.post,
      rank_score: new Date(candidate.post.created_at).getTime() / 1000,
      recommendation_reason: "from_followed_author",
      recommendation_explanation: humanExplanation("from_followed_author", candidate.post),
      recommendation_metadata: recommendationMetadata(candidate, "from_followed_author", candidate.post),
      recommendation_reasons: [...candidate.reasons],
      candidate_sources: [...candidate.sources],
      score_breakdown: {
        recency: recencyScore(candidate.post.created_at),
      },
    }))
    .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime() || String(b.post_id).localeCompare(String(a.post_id)));
  const items = ranked
    .filter((post) => cursorPredicate(cursor, post, "following", config.cursorEpsilon))
    .slice(0, limit);
  await recordServedPosts(viewerId, items, effectiveSessionId, "following");
  await persistFeedSession(viewerId, effectiveSessionId, "following", preferences.lens, items);
  return {
    items,
    nextCursor: buildNextCursor(items, "following"),
    sessionId: effectiveSessionId,
    metrics: {
      mode: "following",
      lens: preferences.lens,
      candidateCount: rows.length,
      filteredCount: hardFiltered.filteredCount,
      fallbackUsed: null,
      sourceCounts: { in_network: rows.length },
      durationMs: Date.now() - started,
    },
  };
}

async function persistFeedSession(
  viewerId: string,
  sessionId: string,
  mode: FeedMode,
  lens: FeedLens,
  posts: RankedFeedPost[]
) {
  if (!sessionId) return;
  await query(
    `INSERT INTO feed_sessions (session_id, user_id, mode, lens, config_hash, post_ids, created_at, expires_at)
     VALUES ($1, $2, $3, $4, 'heuristic_v1', $5, NOW(), NOW() + INTERVAL '30 minutes')
     ON CONFLICT (session_id, user_id)
     DO UPDATE SET mode = EXCLUDED.mode,
                   lens = EXCLUDED.lens,
                   post_ids = EXCLUDED.post_ids,
                   expires_at = EXCLUDED.expires_at`,
    [sessionId, viewerId, mode, lens, JSON.stringify(posts.map((post) => String(post.post_id)))]
  );
}

async function buildChronologicalPageFromRows({
  viewerId,
  mode,
  rows,
  source,
  limit,
  cursor,
  sessionId,
  preferences,
  started,
}: {
  viewerId: string;
  mode: FeedMode;
  rows: any[];
  source: CandidateSource;
  limit: number;
  cursor: FeedCursor | null;
  sessionId: string;
  preferences: FeedPreferences;
  started: number;
}): Promise<FeedPageResult> {
  const config = await loadRankingConfig();
  const map = new Map<string, Candidate>();
  mergeCandidateRows(map, rows, source);
  const hardFiltered = await hardFilterCandidates(viewerId, [...map.values()], config, undefined, preferences, {
    allowRecentlyServed: true,
    strictOutOfNetwork: mode === "explore",
  });
  const ranked = hardFiltered.candidates
    .map((candidate) => {
      const reason = [...candidate.reasons][0] || sourceReason(source);
      return {
        ...candidate.post,
        rank_score: new Date(candidate.post.created_at).getTime() / 1000,
        recommendation_reason: reason,
        recommendation_explanation: humanExplanation(reason, candidate.post),
        recommendation_metadata: recommendationMetadata(candidate, reason, candidate.post),
        recommendation_reasons: [...candidate.reasons],
        candidate_sources: [...candidate.sources],
        score_breakdown: {
          recency: recencyScore(candidate.post.created_at),
        },
      };
    })
    .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime() || String(b.post_id).localeCompare(String(a.post_id)));
  const items = ranked
    .filter((post) => cursorPredicate(cursor, post, "following", config.cursorEpsilon))
    .slice(0, limit);
  await recordServedPosts(viewerId, items, sessionId, mode);
  await persistFeedSession(viewerId, sessionId, mode, preferences.lens, items);
  return {
    items,
    nextCursor: buildNextCursor(items, "following"),
    sessionId,
    metrics: {
      mode,
      lens: preferences.lens,
      candidateCount: rows.length,
      filteredCount: hardFiltered.filteredCount,
      fallbackUsed: null,
      sourceCounts: { [source]: rows.length },
      durationMs: Date.now() - started,
    },
  };
}

async function buildFriendsPage(viewerId: string, limit: number, cursor: FeedCursor | null, before: Date | null | undefined, sessionId: string, preferences: FeedPreferences) {
  const started = Date.now();
  const config = await loadRankingConfig();
  const rows = await fetchFriendRecentCandidates(viewerId, Math.min(config.maxCandidatePool, limit * 4), config, before);
  return buildChronologicalPageFromRows({
    viewerId,
    mode: "friends",
    rows,
    source: "friend_recent",
    limit,
    cursor,
    sessionId,
    preferences,
    started,
  });
}

async function buildTopicPage(viewerId: string, topic: string, limit: number, cursor: FeedCursor | null, before: Date | null | undefined, sessionId: string, preferences: FeedPreferences) {
  const started = Date.now();
  const config = await loadRankingConfig();
  const rows = await fetchTopicCandidates(viewerId, [topic], Math.min(config.maxCandidatePool, limit * 5), config, before);
  return buildChronologicalPageFromRows({
    viewerId,
    mode: "topics",
    rows,
    source: "topic_affinity",
    limit,
    cursor,
    sessionId,
    preferences,
    started,
  });
}

async function buildConversationsPage(viewerId: string, limit: number, cursor: FeedCursor | null, before: Date | null | undefined, sessionId: string, preferences: FeedPreferences) {
  const started = Date.now();
  const config = await loadRankingConfig();
  const rows = await fetchConversationCandidates(viewerId, Math.min(config.maxCandidatePool, limit * 6), config, before);
  return buildChronologicalPageFromRows({
    viewerId,
    mode: "conversations",
    rows,
    source: "conversation",
    limit,
    cursor,
    sessionId,
    preferences: { ...preferences, lens: "conversations" },
    started,
  });
}

async function buildLatestPage(
  viewerId: string,
  limit: number,
  cursor: FeedCursor | null,
  before: Date | null | undefined,
  sessionId: string,
  preferences: FeedPreferences,
  scope = "network"
) {
  const started = Date.now();
  const config = await loadRankingConfig();
  const params: unknown[] = [viewerId, daysAgo(Math.ceil(config.maxAgeDays * 2))];
  const beforeSql = withBefore(params, before);
  params.push(Math.min(config.maxCandidatePool, limit * 6));
  const scopeSql = scope === "broad"
    ? ""
    : `AND (
         p.author_id = $1
         OR EXISTS (SELECT 1 FROM follows f WHERE f.follower_id = $1 AND f.following_id = p.author_id)
         OR EXISTS (
           SELECT 1
           FROM user_followed_topics uft
           JOIN post_topics pt ON pt.post_id = p.post_id AND pt.topic = uft.topic
           WHERE uft.user_id = $1
         )
       )`;
  const rows = await queryMany(
    `SELECT p.*
     FROM posts p
     WHERE p.created_at > $2
       AND p.body <> ''
       AND p.deleted_at IS NULL
       AND p.moderation_state = 'active'
       ${scopeSql}
       ${beforeSql}
     ORDER BY p.created_at DESC, p.post_id DESC
     LIMIT $${params.length}`,
    params
  );
  return buildChronologicalPageFromRows({
    viewerId,
    mode: "latest",
    rows,
    source: scope === "broad" ? "trending" : "in_network",
    limit,
    cursor,
    sessionId,
    preferences: { ...preferences, lens: "latest" },
    started,
  });
}

async function buildCustomFeedPage(
  viewerId: string,
  feedId: string,
  limit: number,
  cursor: FeedCursor | null,
  before: Date | null | undefined,
  sessionId: string,
  preferences: FeedPreferences
) {
  const row = await queryOne(
    `SELECT definition
     FROM feed_custom_feeds
     WHERE feed_id = $1 AND user_id = $2`,
    [feedId, viewerId]
  );
  if (!row) {
    throw new HttpError(404, "Custom feed not found");
  }
  const definition = row.definition || {};
  const includeTopics = normalizeStringList(definition.includeTopics || definition.topics || [], 40).map(normalizeTopic).filter(Boolean);
  const languageFilters = normalizeStringList(definition.languages || [], 12).map(normalizeLanguage).filter(Boolean);
  if (includeTopics.length > 0) {
    return buildTopicPage(viewerId, includeTopics[0], limit, cursor, before, sessionId, preferences);
  }
  if (definition.friendsOnly === true) {
    return buildFriendsPage(viewerId, limit, cursor, before, sessionId, preferences);
  }
  if (definition.latestOnly === true) {
    return buildLatestPage(viewerId, limit, cursor, before, sessionId, preferences, definition.broadNetwork === true ? "broad" : "network");
  }

  const started = Date.now();
  const config = await loadRankingConfig();
  const rows = languageFilters.length > 0
    ? await fetchLanguageAffinityCandidates(viewerId, languageFilters, Math.min(config.maxCandidatePool, limit * 5), config, before)
    : await fetchInterestCandidates(viewerId, Math.min(config.maxCandidatePool, limit * 5), config, before);
  return buildChronologicalPageFromRows({
    viewerId,
    mode: "custom",
    rows,
    source: languageFilters.length > 0 ? "language_affinity" : "topic_affinity",
    limit,
    cursor,
    sessionId,
    preferences,
    started,
  });
}

async function buildCatchUpPage(
  viewerId: string,
  limit: number,
  cursor: FeedCursor | null,
  before: Date | null | undefined,
  sessionId: string,
  preferences: FeedPreferences
) {
  const started = Date.now();
  const config = await loadRankingConfig();
  const lastSeen = await queryOne(
    `SELECT MAX(last_seen_at) AS last_seen_at
     FROM feed_impressions
     WHERE user_id = $1`,
    [viewerId]
  );
  const since = safeDate(lastSeen?.last_seen_at) || daysAgo(7);
  const params: unknown[] = [viewerId, since];
  const beforeSql = withBefore(params, before);
  params.push(Math.min(config.maxCandidatePool, limit * 8));
  const rows = await queryMany(
    `SELECT p.*
     FROM posts p
     LEFT JOIN follows f ON f.follower_id = $1 AND f.following_id = p.author_id
     LEFT JOIN post_engagement_stats pes ON pes.post_id = p.post_id
     WHERE p.created_at > $2
       AND p.body <> ''
       AND p.deleted_at IS NULL
       AND p.moderation_state = 'active'
       AND (
         f.following_id IS NOT NULL
         OR EXISTS (
           SELECT 1
           FROM user_followed_topics uft
           JOIN post_topics pt ON pt.post_id = p.post_id AND pt.topic = uft.topic
           WHERE uft.user_id = $1
         )
         OR p.comment_count > 0
       )
       ${beforeSql}
     ORDER BY CASE WHEN f.following_id IS NOT NULL THEN 6 ELSE 0 END
              + COALESCE(pes.quality_score, p.quality_score, 1) * 3
              + COALESCE(pes.trend_velocity_score, 0) DESC,
              p.created_at DESC
     LIMIT $${params.length}`,
    params
  );
  return buildChronologicalPageFromRows({
    viewerId,
    mode: "catch-up",
    rows,
    source: "conversation",
    limit,
    cursor,
    sessionId,
    preferences,
    started,
  });
}

export async function buildFeedPage({
  viewerId,
  mode,
  limit,
  cursor,
  before,
  sessionId,
  lens,
  topic,
  customFeedId,
  scope,
}: {
  viewerId: string;
  mode: FeedMode;
  limit: number;
  cursor?: string | null;
  before?: Date | null;
  sessionId?: string;
  lens?: FeedLens | string | null;
  topic?: string | null;
  customFeedId?: string | null;
  scope?: string | null;
}): Promise<FeedPageResult> {
  const normalizedLimit = Math.max(1, Math.min(50, limit));
  const decodedCursor = decodeCursorOrThrow(cursor);
  const storedPreferences = await getFeedPreferences(viewerId);
  const preferences: FeedPreferences = {
    ...storedPreferences,
    lens: lens ? normalizeFeedLens(lens) : storedPreferences.lens,
  };
  const effectiveSessionId = sessionId || generateId();
  if (mode === "following") {
    return buildFollowingPage(viewerId, normalizedLimit, decodedCursor, before, effectiveSessionId, preferences);
  }
  if (mode === "friends") {
    return buildFriendsPage(viewerId, normalizedLimit, decodedCursor, before, effectiveSessionId, preferences);
  }
  if (mode === "latest") {
    return buildLatestPage(viewerId, normalizedLimit, decodedCursor, before, effectiveSessionId, preferences, String(scope || "network"));
  }
  if (mode === "topics") {
    const normalizedTopic = normalizeTopic(topic);
    if (!normalizedTopic) throw new HttpError(400, "Topic is required");
    return buildTopicPage(viewerId, normalizedTopic, normalizedLimit, decodedCursor, before, effectiveSessionId, preferences);
  }
  if (mode === "conversations") {
    return buildConversationsPage(viewerId, normalizedLimit, decodedCursor, before, effectiveSessionId, preferences);
  }
  if (mode === "custom") {
    const feedId = String(customFeedId || "").trim();
    if (!feedId) throw new HttpError(400, "Custom feed is required");
    return buildCustomFeedPage(viewerId, feedId, normalizedLimit, decodedCursor, before, effectiveSessionId, preferences);
  }
  if (mode === "catch-up") {
    return buildCatchUpPage(viewerId, normalizedLimit, decodedCursor, before, effectiveSessionId, preferences);
  }

  const started = Date.now();
  const config = await loadRankingConfig();
  const provider = new HeuristicScoringProvider();
  const effectiveMode: FeedMode = mode === "explore" ? "explore" : "for-you";
  const collected = await collectCandidates(viewerId, normalizedLimit, config, before, preferences, effectiveMode);
  let fallbackUsed: string | null = null;
  let candidateSet = collected.candidates;

  let filtered = await hardFilterCandidates(viewerId, candidateSet, config, effectiveSessionId, preferences, {
    strictOutOfNetwork: mode === "explore",
  });
  if (filtered.candidates.length < normalizedLimit) {
    fallbackUsed = "cold_start_popular";
    const fallbackMap = new Map<string, Candidate>();
    mergeCandidateRows(
      fallbackMap,
      await fetchColdStartCandidates(Math.max(normalizedLimit * 4, 60), config, before),
      "cold_start"
    );
    candidateSet = [...new Map([...candidateSet, ...fallbackMap.values()].map((candidate) => [candidate.post.post_id, candidate])).values()];
    filtered = await hardFilterCandidates(viewerId, candidateSet, config, effectiveSessionId, preferences, {
      strictOutOfNetwork: mode === "explore",
    });
  }

  const features = await hydrateFeatures(viewerId, filtered.candidates.map((candidate) => candidate.post));
  const ranked = rankCandidates(viewerId, filtered.candidates, features, config, provider);
  const items = ranked
    .filter((post) => cursorPredicate(decodedCursor, post, "for-you", config.cursorEpsilon))
    .slice(0, normalizedLimit);

  await recordServedPosts(viewerId, items, effectiveSessionId, effectiveMode);
  await persistFeedSession(viewerId, effectiveSessionId, effectiveMode, preferences.lens, items);

  return {
    items,
    nextCursor: buildNextCursor(items, "for-you"),
    sessionId: effectiveSessionId,
    metrics: {
      mode: effectiveMode,
      lens: preferences.lens,
      candidateCount: collected.candidates.length,
      filteredCount: filtered.filteredCount,
      fallbackUsed,
      sourceCounts: collected.sourceCounts,
      durationMs: Date.now() - started,
    },
  };
}

export async function recordServedPosts(
  viewerId: string,
  posts: RankedFeedPost[],
  sessionId: string,
  source: string
) {
  if (posts.length === 0) return;

  const ts = now();
  const postIds = posts.map((post) => String(post.post_id));
  const servedParams: unknown[] = [];
  const servedValues = posts
    .map((post) => {
      const start = servedParams.length + 1;
      servedParams.push(
        viewerId,
        String(post.post_id),
        sessionId || "",
        source,
        String(post.recommendation_reason || "recommended"),
        Number(post.rank_score || 0),
        ts
      );
      return `($${start}, $${start + 1}, $${start + 2}, $${start + 3}, $${start + 4}, $${start + 5}, $${start + 6})`;
    })
    .join(", ");

  const impressionParams: unknown[] = [];
  const impressionValues = posts
    .map((post) => {
      const start = impressionParams.length + 1;
      impressionParams.push(
        viewerId,
        String(post.post_id),
        String(post.author_id),
        source,
        String(post.recommendation_reason || "recommended"),
        Number(post.rank_score || 0),
        1,
        ts,
        ts
      );
      return `($${start}, $${start + 1}, $${start + 2}, $${start + 3}, $${start + 4}, $${start + 5}, $${start + 6}, $${start + 7}, $${start + 8})`;
    })
    .join(", ");

  await Promise.all([
    query(
      `INSERT INTO feed_served_history (user_id, post_id, session_id, source, reason, score, created_at)
       VALUES ${servedValues}
       ON CONFLICT (user_id, post_id, session_id)
       DO UPDATE SET created_at = EXCLUDED.created_at,
                     source = EXCLUDED.source,
                     reason = EXCLUDED.reason,
                     score = EXCLUDED.score`,
      servedParams
    ),
    query(
      `INSERT INTO feed_impressions (user_id, post_id, author_id, source, reason, score, impression_count, first_seen_at, last_seen_at)
       VALUES ${impressionValues}
       ON CONFLICT (user_id, post_id)
       DO UPDATE SET last_seen_at = EXCLUDED.last_seen_at,
                     source = EXCLUDED.source,
                     reason = EXCLUDED.reason,
                     score = EXCLUDED.score,
                     impression_count = feed_impressions.impression_count + 1`,
      impressionParams
    ),
    query(
      `UPDATE posts
       SET impression_count = impression_count + 1
       WHERE post_id IN (${placeholders(postIds.length)})`,
      postIds
    ),
  ]);
}

function normalizeEvent(input: FeedEventInput): FeedEventInput | null {
  const type = String(input.type || "").trim().toLowerCase();
  if (!FEED_EVENT_TYPES.includes(type as any)) return null;
  const postId = String(input.postId || "").trim();
  const commentId = String(input.commentId || "").trim();
  const dwellMs = Math.max(0, Math.min(30 * 60 * 1000, Number(input.dwellMs || 0)));
  return {
    type,
    postId: postId || undefined,
    commentId: commentId || null,
    dwellMs,
    source: String(input.source || "").trim().slice(0, 64),
    sessionId: String(input.sessionId || "").trim().slice(0, 120),
    clientEventId: String(input.clientEventId || "").trim().slice(0, 160) || undefined,
    metadata: input.metadata && typeof input.metadata === "object" ? input.metadata : {},
  };
}

export async function ingestFeedEvents(userId: string, inputs: FeedEventInput[]) {
  const events = inputs.map(normalizeEvent).filter(Boolean).slice(0, 50) as FeedEventInput[];
  if (events.length === 0) {
    return { accepted: 0 };
  }

  const postIds = [...new Set(events.map((event) => event.postId).filter(Boolean))] as string[];
  const posts = postIds.length
    ? await queryMany(`SELECT post_id, author_id FROM posts WHERE post_id = ANY($1::text[])`, [postIds])
    : [];
  const postAuthorMap = new Map(posts.map((post) => [post.post_id, post.author_id]));
  const ts = now();

  let accepted = 0;
  for (const event of events) {
    const postId = event.postId && postAuthorMap.has(event.postId) ? event.postId : null;
    const authorId = postId ? postAuthorMap.get(postId) : null;
    const result = await query(
      `INSERT INTO feed_events (
         event_id, client_event_id, user_id, post_id, author_id, comment_id,
         event_type, dwell_ms, source, session_id, metadata, created_at
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
       ON CONFLICT DO NOTHING`,
      [
        generateId(),
        event.clientEventId || null,
        userId,
        postId,
        authorId,
        event.commentId || null,
        event.type,
        event.dwellMs || 0,
        event.source || "",
        event.sessionId || "",
        JSON.stringify(event.metadata || {}),
        ts,
      ]
    );
    accepted += result.rowCount || 0;

    if (!postId || !authorId) continue;
    const isPositive = POSITIVE_EVENT_TYPES.has(String(event.type));
    const isNegative = NEGATIVE_EVENT_TYPES.has(String(event.type));
    await query(
      `INSERT INTO feed_impressions (
         user_id, post_id, author_id, source, reason, score, impression_count,
         total_dwell_ms, first_seen_at, last_seen_at, engaged_at, negative_at
       )
       VALUES ($1, $2, $3, $4, $5, 0, 1, $6, $7, $7, $8, $9)
       ON CONFLICT (user_id, post_id)
       DO UPDATE SET last_seen_at = EXCLUDED.last_seen_at,
                     source = COALESCE(NULLIF(EXCLUDED.source, ''), feed_impressions.source),
                     impression_count = CASE
                       WHEN EXCLUDED.reason IN ('impression', 'view') THEN feed_impressions.impression_count + 1
                       ELSE feed_impressions.impression_count
                     END,
                     total_dwell_ms = feed_impressions.total_dwell_ms + EXCLUDED.total_dwell_ms,
                     engaged_at = COALESCE(feed_impressions.engaged_at, EXCLUDED.engaged_at),
                     negative_at = COALESCE(feed_impressions.negative_at, EXCLUDED.negative_at)`,
      [
        userId,
        postId,
        authorId,
        event.source || "",
        event.type || "",
        event.dwellMs || 0,
        ts,
        isPositive ? ts : null,
        isNegative ? ts : null,
      ]
    );
  }

  return { accepted };
}

export async function recordFeedEvent(userId: string, event: FeedEventInput) {
  return ingestFeedEvents(userId, [event]);
}

export async function markPostHidden(userId: string, postId: string, reason = "hidden") {
  const ts = now();
  await query(
    `INSERT INTO post_hidden (user_id, post_id, reason, created_at)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (user_id, post_id)
     DO UPDATE SET reason = EXCLUDED.reason, created_at = EXCLUDED.created_at`,
    [userId, postId, reason.slice(0, 80), ts]
  );
  await recordFeedEvent(userId, { type: "hide", postId, metadata: { reason } });
  return { hidden: true };
}

export async function markPostNotInterested(userId: string, postId: string, reason = "not_interested") {
  const ts = now();
  await query(
    `INSERT INTO post_not_interested (user_id, post_id, reason, created_at)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (user_id, post_id)
     DO UPDATE SET reason = EXCLUDED.reason, created_at = EXCLUDED.created_at`,
    [userId, postId, reason.slice(0, 80), ts]
  );
  await recordFeedEvent(userId, { type: "not_interested", postId, metadata: { reason } });
  return { notInterested: true };
}

export async function recordFeedFeedback(
  userId: string,
  postId: string,
  feedbackType: string,
  value = 1,
  metadata: Record<string, unknown> = {}
) {
  const normalizedType = String(feedbackType || "").trim().toLowerCase().replace(/[^a-z0-9_]/g, "_").slice(0, 80);
  if (!normalizedType) throw new HttpError(400, "Feedback type is required");
  await query(
    `INSERT INTO feed_feedback (user_id, post_id, feedback_type, feedback_value, metadata, created_at)
     VALUES ($1, $2, $3, $4, $5, NOW())
     ON CONFLICT (user_id, post_id, feedback_type)
     DO UPDATE SET feedback_value = EXCLUDED.feedback_value,
                   metadata = EXCLUDED.metadata,
                   created_at = EXCLUDED.created_at`,
    [userId, postId, normalizedType, value, JSON.stringify(metadata)]
  );
  await recordFeedEvent(userId, {
    type: value >= 0 ? "click" : "not_interested",
    postId,
    metadata: { feedbackType: normalizedType, ...metadata },
  });
  return { saved: true, feedbackType: normalizedType };
}

export async function followTopic(userId: string, topic: string) {
  const normalized = normalizeTopic(topic);
  if (!normalized) throw new HttpError(400, "Topic is required");
  await query(
    `INSERT INTO user_followed_topics (user_id, topic, followed_at)
     VALUES ($1, $2, NOW())
     ON CONFLICT (user_id, topic) DO UPDATE SET followed_at = EXCLUDED.followed_at`,
    [userId, normalized]
  );
  await query(
    `INSERT INTO user_topic_affinities (user_id, topic, score, positive_count, negative_count, last_signal_at, updated_at)
     VALUES ($1, $2, 4, 1, 0, NOW(), NOW())
     ON CONFLICT (user_id, topic)
     DO UPDATE SET score = GREATEST(user_topic_affinities.score, EXCLUDED.score),
                   positive_count = user_topic_affinities.positive_count + 1,
                   last_signal_at = EXCLUDED.last_signal_at,
                   updated_at = EXCLUDED.updated_at`,
    [userId, normalized]
  );
  return { topic: normalized, followed: true };
}

export async function unfollowTopic(userId: string, topic: string) {
  const normalized = normalizeTopic(topic);
  if (!normalized) throw new HttpError(400, "Topic is required");
  await query(`DELETE FROM user_followed_topics WHERE user_id = $1 AND topic = $2`, [userId, normalized]);
  return { topic: normalized, followed: false };
}

export async function muteTopic(userId: string, topic: string, days?: number) {
  const normalized = normalizeTopic(topic);
  if (!normalized) throw new HttpError(400, "Topic is required");
  const snoozedUntil = Number.isFinite(Number(days)) && Number(days) > 0
    ? new Date(Date.now() + Math.min(Number(days), 365) * 24 * 60 * 60 * 1000)
    : null;
  await query(
    `INSERT INTO feed_muted_topics (user_id, topic, reason, snoozed_until, created_at)
     VALUES ($1, $2, $3, $4, NOW())
     ON CONFLICT (user_id, topic)
     DO UPDATE SET reason = EXCLUDED.reason,
                   snoozed_until = EXCLUDED.snoozed_until,
                   created_at = EXCLUDED.created_at`,
    [userId, normalized, snoozedUntil ? "snoozed" : "muted", snoozedUntil]
  );
  return { topic: normalized, muted: !snoozedUntil, snoozedUntil: toIso(snoozedUntil) };
}

export async function unmuteTopic(userId: string, topic: string) {
  const normalized = normalizeTopic(topic);
  if (!normalized) throw new HttpError(400, "Topic is required");
  await query(`DELETE FROM feed_muted_topics WHERE user_id = $1 AND topic = $2`, [userId, normalized]);
  return { topic: normalized, muted: false };
}

export async function listFeedTopics(userId: string, limit = 50) {
  const rows = await queryMany(
    `WITH all_topics AS (
       SELECT slug AS topic FROM topics WHERE is_active = TRUE
       UNION
       SELECT topic FROM trending_topics
     )
     SELECT at.topic AS topic,
            COALESCE(t.name, at.topic) AS name,
            COALESCE(t.category, 'general') AS category,
            COALESCE(t.language, tt.language, '') AS language,
            COALESCE(tt.post_count, 0) AS post_count,
            COALESCE(tt.velocity_score, 0) AS velocity_score,
            CASE WHEN uft.topic IS NULL THEN FALSE ELSE TRUE END AS followed,
            CASE WHEN umt.topic IS NULL THEN FALSE ELSE TRUE END AS muted
     FROM all_topics at
     LEFT JOIN trending_topics tt ON tt.topic = at.topic
     LEFT JOIN topics t ON t.slug = at.topic
     LEFT JOIN user_followed_topics uft ON uft.user_id = $1 AND uft.topic = at.topic
     LEFT JOIN feed_muted_topics umt
       ON umt.user_id = $1 AND umt.topic = at.topic AND (umt.snoozed_until IS NULL OR umt.snoozed_until > NOW())
     ORDER BY COALESCE(tt.velocity_score, 0) DESC, COALESCE(tt.post_count, 0) DESC, topic ASC
     LIMIT $2`,
    [userId, Math.max(1, Math.min(100, limit))]
  );
  return {
    items: rows.map((row) => ({
      topic: row.topic,
      name: row.name,
      category: row.category,
      language: row.language,
      postCount: Number(row.post_count || 0),
      velocityScore: Number(row.velocity_score || 0),
      followed: row.followed === true,
      muted: row.muted === true,
    })),
  };
}

export async function listInferredInterests(userId: string) {
  const [affinities, followed, muted] = await Promise.all([
    queryMany(
      `SELECT topic, score, positive_count, negative_count, last_signal_at
       FROM user_topic_affinities
       WHERE user_id = $1
       ORDER BY score DESC, last_signal_at DESC
       LIMIT 80`,
      [userId]
    ),
    queryMany(`SELECT topic FROM user_followed_topics WHERE user_id = $1`, [userId]),
    queryMany(
      `SELECT topic FROM feed_muted_topics WHERE user_id = $1 AND (snoozed_until IS NULL OR snoozed_until > NOW())`,
      [userId]
    ),
  ]);
  const followedSet = new Set(followed.map((row) => row.topic));
  const mutedSet = new Set(muted.map((row) => row.topic));
  return {
    items: affinities.map((row) => ({
      topic: row.topic,
      score: Number(row.score || 0),
      positiveCount: Number(row.positive_count || 0),
      negativeCount: Number(row.negative_count || 0),
      lastSignalAt: toIso(row.last_signal_at),
      followed: followedSet.has(row.topic),
      muted: mutedSet.has(row.topic),
    })),
  };
}

export async function removeInferredInterest(userId: string, topic: string) {
  const normalized = normalizeTopic(topic);
  if (!normalized) throw new HttpError(400, "Topic is required");
  await query(`DELETE FROM user_topic_affinities WHERE user_id = $1 AND topic = $2`, [userId, normalized]);
  return { topic: normalized, removed: true };
}

export async function resetFeedPersonalization(userId: string) {
  await Promise.all([
    query(`DELETE FROM user_topic_affinities WHERE user_id = $1`, [userId]),
    query(`DELETE FROM user_author_affinities WHERE user_id = $1`, [userId]),
    query(`DELETE FROM feed_impressions WHERE user_id = $1`, [userId]),
    query(`DELETE FROM feed_served_history WHERE user_id = $1`, [userId]),
    query(`DELETE FROM feed_feedback WHERE user_id = $1`, [userId]),
  ]);
  return { reset: true };
}

export async function clearFeedServedHistory(userId: string) {
  await Promise.all([
    query(`DELETE FROM feed_served_history WHERE user_id = $1`, [userId]),
    query(`DELETE FROM feed_sessions WHERE user_id = $1`, [userId]),
  ]);
  return { cleared: true };
}

function sanitizeCustomFeedDefinition(input: Record<string, unknown>) {
  const definition = {
    includeTopics: normalizeStringList(input.includeTopics || input.topics || [], 40).map(normalizeTopic).filter(Boolean),
    excludeTopics: normalizeStringList(input.excludeTopics || [], 40).map(normalizeTopic).filter(Boolean),
    includeAccounts: normalizeStringList(input.includeAccounts || [], 80),
    excludeAccounts: normalizeStringList(input.excludeAccounts || [], 80),
    friendsOnly: input.friendsOnly === true,
    followedOnly: input.followedOnly === true,
    latestOnly: input.latestOnly === true,
    allowReposts: input.allowReposts !== false,
    languages: normalizeStringList(input.languages || [], 12).map(normalizeLanguage).filter(Boolean),
    media: String(input.media || "any").slice(0, 24),
    minimumQuality: clamp01(input.minimumQuality, 0.25),
    localScope: input.localScope === true,
    broadNetwork: input.broadNetwork === true,
  };
  if (definition.includeTopics.length === 0 && !definition.friendsOnly && !definition.followedOnly && !definition.latestOnly && definition.languages.length === 0) {
    throw new HttpError(400, "Custom feed needs at least one filter");
  }
  return definition;
}

export async function listCustomFeeds(userId: string) {
  const rows = await queryMany(
    `SELECT feed_id, name, definition, is_public, created_at, updated_at
     FROM feed_custom_feeds
     WHERE user_id = $1
     ORDER BY updated_at DESC`,
    [userId]
  );
  return {
    items: rows.map((row) => ({
      id: row.feed_id,
      name: row.name,
      definition: row.definition || {},
      isPublic: row.is_public === true,
      createdAt: toIso(row.created_at),
      updatedAt: toIso(row.updated_at),
    })),
  };
}

export async function saveCustomFeed(userId: string, input: Record<string, unknown>, feedId?: string | null) {
  const id = String(feedId || input.feedId || "").trim() || generateId();
  const name = String(input.name || "").trim().slice(0, 80);
  if (!name) throw new HttpError(400, "Custom feed name is required");
  const definition = sanitizeCustomFeedDefinition((input.definition && typeof input.definition === "object" ? input.definition : input) as Record<string, unknown>);
  await query(
    `INSERT INTO feed_custom_feeds (feed_id, user_id, name, definition, is_public, created_at, updated_at)
     VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
     ON CONFLICT (feed_id)
     DO UPDATE SET name = EXCLUDED.name,
                   definition = EXCLUDED.definition,
                   is_public = EXCLUDED.is_public,
                   updated_at = EXCLUDED.updated_at
     WHERE feed_custom_feeds.user_id = EXCLUDED.user_id`,
    [id, userId, name, JSON.stringify(definition), input.isPublic === true]
  );
  return { id, name, definition, isPublic: input.isPublic === true };
}

export async function deleteCustomFeed(userId: string, feedId: string) {
  const result = await query(`DELETE FROM feed_custom_feeds WHERE feed_id = $1 AND user_id = $2`, [feedId, userId]);
  return { deleted: (result.rowCount || 0) > 0 };
}

export async function exportFeedSettings(userId: string) {
  const [preferences, interests, customFeeds, followedTopics, mutedTopics] = await Promise.all([
    getFeedPreferences(userId),
    listInferredInterests(userId),
    listCustomFeeds(userId),
    queryMany(`SELECT topic, followed_at FROM user_followed_topics WHERE user_id = $1 ORDER BY followed_at DESC`, [userId]),
    queryMany(`SELECT topic, reason, snoozed_until, created_at FROM feed_muted_topics WHERE user_id = $1 ORDER BY created_at DESC`, [userId]),
  ]);
  return {
    preferences,
    interests: interests.items,
    customFeeds: customFeeds.items,
    followedTopics: followedTopics.map((row) => ({ topic: row.topic, followedAt: toIso(row.followed_at) })),
    mutedTopics: mutedTopics.map((row) => ({
      topic: row.topic,
      reason: row.reason,
      snoozedUntil: toIso(row.snoozed_until),
      createdAt: toIso(row.created_at),
    })),
  };
}

export async function explainPostRecommendation(userId: string, postId: string) {
  const served = await queryOne(
    `SELECT reason, source, score, created_at
     FROM feed_served_history
     WHERE user_id = $1 AND post_id = $2
     ORDER BY created_at DESC
     LIMIT 1`,
    [userId, postId]
  );
  const post = await queryOne(
    `SELECT post_id, author_id, hashtags
     FROM posts
     WHERE post_id = $1`,
    [postId]
  );
  const reason = String(served?.reason || "recommended");
  return {
    postId,
    reasonCode: reason,
    explanation: humanExplanation(reason, post),
    feedSource: served?.source || "unknown",
    servedAt: toIso(served?.created_at),
    score: served ? Number(served.score || 0) : null,
    topicMatch: Array.isArray(post?.hashtags) && post.hashtags.length > 0 ? String(post.hashtags[0]) : null,
  };
}

export async function runFeedAggregationJobs() {
  const ts = now();

  await query(
    `INSERT INTO post_topics (post_id, topic, weight, source, created_at)
     SELECT post_id, tag, 1, 'hashtag', MIN(created_at)
     FROM post_tags
     WHERE tag <> ''
     GROUP BY post_id, tag
     ON CONFLICT (post_id, topic)
     DO UPDATE SET weight = EXCLUDED.weight, source = EXCLUDED.source`
  );

  await query(
    `INSERT INTO post_engagement_stats (
       post_id, impression_count, unique_impressions, like_count, comment_count,
       reply_count, share_count, bookmark_count, click_count, profile_click_count,
       total_dwell_ms, negative_count, report_count, unique_engaged_users,
       engagement_rate, trend_velocity_score, quality_score, updated_at
     )
     SELECT
       p.post_id,
       COALESCE(SUM(fi.impression_count), 0)::int AS impression_count,
       COUNT(DISTINCT fi.user_id)::int AS unique_impressions,
       p.like_count,
       p.comment_count,
       COALESCE((SELECT COUNT(*)::int FROM comments c WHERE c.post_id = p.post_id AND c.parent_comment_id IS NOT NULL), 0) AS reply_count,
       p.share_count,
       COALESCE((SELECT COUNT(*)::int FROM feed_events fe WHERE fe.post_id = p.post_id AND fe.event_type = 'bookmark'), 0) AS bookmark_count,
       COALESCE((SELECT COUNT(*)::int FROM feed_events fe WHERE fe.post_id = p.post_id AND fe.event_type IN ('click', 'post_open', 'media_expand')), 0) AS click_count,
       COALESCE((SELECT COUNT(*)::int FROM feed_events fe WHERE fe.post_id = p.post_id AND fe.event_type = 'profile_click'), 0) AS profile_click_count,
       COALESCE(SUM(fi.total_dwell_ms), 0)::bigint AS total_dwell_ms,
       COALESCE((SELECT COUNT(*)::int FROM feed_events fe WHERE fe.post_id = p.post_id AND fe.event_type IN ('hide', 'not_interested', 'mute', 'block', 'report')), 0) AS negative_count,
       COALESCE((SELECT COUNT(*)::int FROM feed_events fe WHERE fe.post_id = p.post_id AND fe.event_type = 'report'), 0) AS report_count,
       COALESCE((SELECT COUNT(DISTINCT fe.user_id)::int FROM feed_events fe WHERE fe.post_id = p.post_id AND fe.event_type IN ('like', 'comment', 'reply', 'share', 'bookmark', 'post_open', 'profile_click')), 0) AS unique_engaged_users,
       (
         (p.like_count + p.comment_count * 1.8 + p.share_count * 2.4)
         / GREATEST(COALESCE(SUM(fi.impression_count), 0), 8)
       )::double precision AS engagement_rate,
       (
         COALESCE((
           SELECT COUNT(*)::double precision
           FROM feed_events fe
           WHERE fe.post_id = p.post_id
             AND fe.event_type IN ('like', 'comment', 'reply', 'share', 'bookmark', 'post_open')
             AND fe.created_at > NOW() - INTERVAL '60 minutes'
         ), 0)
         / GREATEST(EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 3600, 0.25)
       )::double precision AS trend_velocity_score,
       GREATEST(0.05, LEAST(1.0,
         p.quality_score
         - COALESCE((SELECT COUNT(*)::double precision FROM feed_events fe WHERE fe.post_id = p.post_id AND fe.event_type = 'report'), 0)
           / GREATEST(COALESCE(SUM(fi.impression_count), 0), 20)
       )) AS quality_score,
       $1
     FROM posts p
     LEFT JOIN feed_impressions fi ON fi.post_id = p.post_id
     WHERE p.deleted_at IS NULL
     GROUP BY p.post_id
     ON CONFLICT (post_id)
     DO UPDATE SET impression_count = EXCLUDED.impression_count,
                   unique_impressions = EXCLUDED.unique_impressions,
                   like_count = EXCLUDED.like_count,
                   comment_count = EXCLUDED.comment_count,
                   reply_count = EXCLUDED.reply_count,
                   share_count = EXCLUDED.share_count,
                   bookmark_count = EXCLUDED.bookmark_count,
                   click_count = EXCLUDED.click_count,
                   profile_click_count = EXCLUDED.profile_click_count,
                   total_dwell_ms = EXCLUDED.total_dwell_ms,
                   negative_count = EXCLUDED.negative_count,
                   report_count = EXCLUDED.report_count,
                   unique_engaged_users = EXCLUDED.unique_engaged_users,
                   engagement_rate = EXCLUDED.engagement_rate,
                   trend_velocity_score = EXCLUDED.trend_velocity_score,
                   quality_score = EXCLUDED.quality_score,
                   updated_at = EXCLUDED.updated_at`,
    [ts]
  );

  await query(
    `INSERT INTO user_author_affinities (
       user_id, author_id, score, positive_count, negative_count, last_signal_at, updated_at
     )
     SELECT
       fe.user_id,
       p.author_id,
       SUM(CASE
         WHEN fe.event_type = 'like' THEN 3
         WHEN fe.event_type IN ('comment', 'reply') THEN 4
         WHEN fe.event_type = 'share' THEN 5
         WHEN fe.event_type = 'bookmark' THEN 3
         WHEN fe.event_type IN ('post_open', 'profile_click') THEN 1.5
         WHEN fe.event_type = 'dwell' THEN LEAST(fe.dwell_ms::double precision / 30000, 2)
         WHEN fe.event_type IN ('hide', 'not_interested', 'mute', 'block', 'report') THEN -5
         ELSE 0.2
       END)::double precision AS score,
       COUNT(*) FILTER (WHERE fe.event_type IN ('like', 'comment', 'reply', 'share', 'bookmark', 'post_open', 'profile_click'))::int AS positive_count,
       COUNT(*) FILTER (WHERE fe.event_type IN ('hide', 'not_interested', 'mute', 'block', 'report'))::int AS negative_count,
       MAX(fe.created_at),
       $1
     FROM feed_events fe
     JOIN posts p ON p.post_id = fe.post_id
     WHERE fe.post_id IS NOT NULL
       AND p.author_id <> fe.user_id
       AND fe.created_at > NOW() - INTERVAL '90 days'
     GROUP BY fe.user_id, p.author_id
     ON CONFLICT (user_id, author_id)
     DO UPDATE SET score = EXCLUDED.score,
                   positive_count = EXCLUDED.positive_count,
                   negative_count = EXCLUDED.negative_count,
                   last_signal_at = EXCLUDED.last_signal_at,
                   updated_at = EXCLUDED.updated_at`,
    [ts]
  );

  await query(
    `INSERT INTO user_topic_affinities (
       user_id, topic, score, positive_count, negative_count, last_signal_at, updated_at
     )
     SELECT
       fe.user_id,
       pt.topic,
       SUM(CASE
         WHEN fe.event_type = 'like' THEN 3
         WHEN fe.event_type IN ('comment', 'reply') THEN 4
         WHEN fe.event_type = 'share' THEN 5
         WHEN fe.event_type = 'bookmark' THEN 3
         WHEN fe.event_type IN ('post_open', 'profile_click') THEN 1.5
         WHEN fe.event_type = 'dwell' THEN LEAST(fe.dwell_ms::double precision / 30000, 2)
         WHEN fe.event_type IN ('hide', 'not_interested', 'mute', 'block', 'report') THEN -4
         ELSE 0.1
       END * pt.weight)::double precision AS score,
       COUNT(*) FILTER (WHERE fe.event_type IN ('like', 'comment', 'reply', 'share', 'bookmark', 'post_open', 'profile_click'))::int AS positive_count,
       COUNT(*) FILTER (WHERE fe.event_type IN ('hide', 'not_interested', 'mute', 'block', 'report'))::int AS negative_count,
       MAX(fe.created_at),
       $1
     FROM feed_events fe
     JOIN post_topics pt ON pt.post_id = fe.post_id
     WHERE fe.post_id IS NOT NULL
       AND fe.created_at > NOW() - INTERVAL '90 days'
     GROUP BY fe.user_id, pt.topic
     ON CONFLICT (user_id, topic)
     DO UPDATE SET score = EXCLUDED.score,
                   positive_count = EXCLUDED.positive_count,
                   negative_count = EXCLUDED.negative_count,
                   last_signal_at = EXCLUDED.last_signal_at,
                   updated_at = EXCLUDED.updated_at`,
    [ts]
  );

  await query(
    `INSERT INTO post_trend_snapshots (post_id, window_minutes, engagement_count, unique_user_count, velocity_score, captured_at)
     SELECT
       p.post_id,
       60,
       COUNT(fe.event_id)::int,
       COUNT(DISTINCT fe.user_id)::int,
       (COUNT(fe.event_id)::double precision / GREATEST(EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 3600, 0.25))::double precision,
       $1
     FROM posts p
     LEFT JOIN feed_events fe
       ON fe.post_id = p.post_id
      AND fe.event_type IN ('like', 'comment', 'reply', 'share', 'bookmark', 'post_open')
      AND fe.created_at > NOW() - INTERVAL '60 minutes'
     WHERE p.created_at > NOW() - INTERVAL '7 days'
       AND p.deleted_at IS NULL
     GROUP BY p.post_id`,
    [ts]
  );

  await query(
    `INSERT INTO trending_topics (topic, post_count, engagement_count, velocity_score, language, region, updated_at)
     SELECT
       pt.topic,
       COUNT(DISTINCT pt.post_id)::int,
       COALESCE(SUM(pes.like_count + pes.comment_count + pes.share_count), 0)::int,
       COALESCE(SUM(pes.trend_velocity_score), 0)::double precision,
       '',
       '',
       $1
     FROM post_topics pt
     JOIN posts p ON p.post_id = pt.post_id
     LEFT JOIN post_engagement_stats pes ON pes.post_id = pt.post_id
     WHERE p.created_at > NOW() - INTERVAL '7 days'
       AND p.deleted_at IS NULL
     GROUP BY pt.topic
     ON CONFLICT (topic)
     DO UPDATE SET post_count = EXCLUDED.post_count,
                   engagement_count = EXCLUDED.engagement_count,
                   velocity_score = EXCLUDED.velocity_score,
                   updated_at = EXCLUDED.updated_at`,
    [ts]
  );

  await Promise.all([
    query(`DELETE FROM feed_served_history WHERE created_at < NOW() - INTERVAL '7 days'`),
    query(`DELETE FROM post_trend_snapshots WHERE captured_at < NOW() - INTERVAL '14 days'`),
  ]);
}

export function startFeedAggregationScheduler(app: any) {
  if (process.env.NODE_ENV === "test") return;
  const intervalMs = Math.max(60_000, parsePositiveNumber(process.env.FEED_AGGREGATION_INTERVAL_MS, 300_000));
  const run = async () => {
    const started = Date.now();
    try {
      await runFeedAggregationJobs();
      app.log?.info?.({ durationMs: Date.now() - started }, "feed aggregation complete");
    } catch (error) {
      app.log?.warn?.({ err: error }, "feed aggregation failed");
    }
  };

  const initial = setTimeout(() => {
    void run();
  }, 45_000);
  initial.unref?.();
  const timer = setInterval(() => {
    void run();
  }, intervalMs);
  timer.unref?.();

  app.addHook?.("onClose", async () => {
    clearTimeout(initial);
    clearInterval(timer);
  });
}
