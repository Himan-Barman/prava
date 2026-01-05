import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { and, eq, inArray, sql } from 'drizzle-orm';

import { config } from '@/app.config';
import { db } from '@/db';
import { feedPosts } from '@/db/schema/feed_posts.schema';
import { feedLikes } from '@/db/schema/feed_likes.schema';
import { feedComments } from '@/db/schema/feed_comments.schema';
import { feedShares } from '@/db/schema/feed_shares.schema';
import { users } from '@/db/schema/users.schema';
import { follows } from '@/db/schema/follows.schema';
import { userBlocks } from '@/db/schema/user_blocks.schema';
import { userMutedWords } from '@/db/schema/user_muted_words.schema';
import { userInterestProfiles } from '@/db/schema/user_interest_profiles.schema';
import { publishFeedEvent } from './feed.realtime';
import { NotificationsService } from '@/modules/notifications/notifications.service';

const MAX_FEED_LIMIT = 50;
type FeedMode = 'for-you' | 'following';
const MAX_FEED_CANDIDATES = 200;
const INTEREST_DECAY_HOURS = 720;
const MAX_INTEREST_SCORE = 6;
const INTEREST_CATEGORY_MULTIPLIER = 1.5;
const MAX_CATEGORIES_PER_POST = 3;
const CATEGORY_SCORE_THRESHOLD = 2;
const FEED_CATEGORY_KEYWORDS: Record<string, string[]> = {
  news: ['news', 'headline', 'breaking', 'report', 'update', 'press'],
  sports: [
    'sports',
    'football',
    'soccer',
    'cricket',
    'nba',
    'nfl',
    'f1',
    'tennis',
    'match',
    'goal',
  ],
  tech: [
    'tech',
    'technology',
    'ai',
    'android',
    'ios',
    'software',
    'coding',
    'developer',
    'startup',
    'gadget',
  ],
  music: [
    'music',
    'song',
    'album',
    'spotify',
    'concert',
    'guitar',
    'singer',
    'rapper',
  ],
  movies: [
    'movie',
    'film',
    'cinema',
    'trailer',
    'netflix',
    'actor',
    'actress',
  ],
  gaming: [
    'game',
    'gaming',
    'ps5',
    'xbox',
    'steam',
    'esports',
    'fortnite',
    'valorant',
    'pubg',
    'minecraft',
  ],
  fashion: [
    'fashion',
    'style',
    'outfit',
    'streetwear',
    'design',
    'luxury',
    'model',
  ],
  travel: [
    'travel',
    'trip',
    'flight',
    'hotel',
    'tour',
    'vacation',
    'beach',
    'mountain',
  ],
  education: [
    'education',
    'study',
    'learning',
    'school',
    'college',
    'university',
    'course',
    'exam',
    'tutorial',
  ],
  business: [
    'business',
    'startup',
    'market',
    'finance',
    'stock',
    'crypto',
    'economy',
    'sales',
    'product',
  ],
  fitness: [
    'fitness',
    'workout',
    'gym',
    'training',
    'yoga',
    'run',
    'running',
    'health',
  ],
  food: [
    'food',
    'recipe',
    'cook',
    'cooking',
    'meal',
    'restaurant',
    'coffee',
    'tea',
    'dessert',
  ],
  politics: [
    'politics',
    'election',
    'government',
    'policy',
    'parliament',
    'vote',
    'president',
    'minister',
  ],
  art: [
    'art',
    'design',
    'painting',
    'illustration',
    'sketch',
    'creative',
    'gallery',
  ],
  science: [
    'science',
    'research',
    'space',
    'nasa',
    'physics',
    'chemistry',
    'biology',
    'lab',
  ],
};
const INTEREST_WEIGHTS = {
  like: 1,
  comment: 2,
  share: 3,
};
const FEED_EXPERIMENT_KEY = 'feed_algo_v1';
const FEED_EXPERIMENT_VARIANTS: Record<string, number> = {
  control: 0.45,
  social: 0.25,
  relevance: 0.2,
  explore: 0.1,
};
const ENGAGEMENT_ENGINE_TIMEOUT_MS = 1400;
const EXPERIMENT_ENGINE_TIMEOUT_MS = 800;
const DECISION_ENGINE_TIMEOUT_MS = 1600;
type RelationshipLabel = 'friend' | 'following' | 'followed_by' | 'other';
type DecisionEngineCandidate = {
  postId: string;
  authorId: string;
  createdAt: string;
  likeCount: number;
  commentCount: number;
  shareCount: number;
  textLength: number;
  mediaCount: number;
  relationship: RelationshipLabel;
  affinity: { likes: number; comments: number; shares: number };
  hashtags: string[];
  mentions: string[];
  qualityScore?: number;
  authorReputation?: number;
  safetyScore?: number;
  negativeFeedback?: number;
  isSensitive?: boolean;
  engagementScore?: number;
  interestScore?: number;
};

type EngagementCandidate = {
  postId: string;
  createdAt?: string;
  relationship: RelationshipLabel;
  textLength: number;
  mediaCount: number;
  hashtagCount: number;
  mentionCount: number;
  ageHours: number;
  authorReputation: number;
  affinity: { likes: number; comments: number; shares: number };
};

@Injectable()
export class FeedService {
  constructor(
    private readonly notifications: NotificationsService,
  ) {}
  private extractMentions(body: string) {
    const regex = /(?:^|\s)@([a-zA-Z0-9_]{3,32})/g;
    const matches = new Set<string>();
    let match: RegExpExecArray | null;
    while ((match = regex.exec(body)) !== null) {
      matches.add(match[1].toLowerCase());
    }
    return Array.from(matches);
  }

  private extractHashtags(body: string) {
    const regex = /(?:^|\s)#([a-zA-Z0-9_]{2,32})/g;
    const matches = new Set<string>();
    let match: RegExpExecArray | null;
    while ((match = regex.exec(body)) !== null) {
      matches.add(match[1].toLowerCase());
    }
    return Array.from(matches);
  }

  private async loadMutedPhrases(userId: string) {
    const mutedRows = await db
      .select({ phrase: userMutedWords.phrase })
      .from(userMutedWords)
      .where(eq(userMutedWords.userId, userId));

    return mutedRows
      .map((row) => row.phrase.toLowerCase())
      .filter((phrase) => phrase.length > 0);
  }

  private mapFeedRows(rows: any[]) {
    return rows.map((row) => ({
      id: row.id,
      body: row.body,
      createdAt: row.createdAt,
      likeCount: Number(row.likeCount ?? 0),
      commentCount: Number(row.commentCount ?? 0),
      shareCount: Number(row.shareCount ?? 0),
      liked: row.liked === true,
      followed: row.followed === true,
      mentions: row.mentions ?? [],
      hashtags: row.hashtags ?? [],
      relationship:
        row.relationship ?? (row.followed === true ? 'following' : 'other'),
      author: {
        id: row.authorId,
        username: row.authorUsername,
        displayName: row.authorDisplayName ?? row.authorUsername,
      },
    }));
  }

  private filterMuted(items: any[], mutedPhrases: string[]) {
    if (mutedPhrases.length == 0) {
      return items;
    }

    return items.filter((item) => {
      const body = item.body?.toString().toLowerCase() ?? '';
      return !mutedPhrases.some((phrase) => body.includes(phrase));
    });
  }

  private async postJson<T>(
    url: string,
    payload: unknown,
    timeoutMs: number,
  ): Promise<T | null> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });

      if (!response.ok) return null;
      return (await response.json()) as T;
    } catch (_) {
      return null;
    } finally {
      clearTimeout(timeout);
    }
  }

  private clamp(value: number, min = 0, max = 1) {
    return Math.min(max, Math.max(min, value));
  }

  private countLinks(body: string) {
    const matches = body.match(/https?:\/\/|www\./gi);
    return matches ? matches.length : 0;
  }

  private estimateQualityScore(
    body: string,
    hashtags: string[],
    mentions: string[],
    linkCount: number,
  ) {
    const length = body.length;
    let score = 0.7;
    if (length >= 30 && length <= 220) {
      score = 1.0;
    } else if (length < 30) {
      score = 0.82;
    } else if (length <= 420) {
      score = 0.9;
    } else {
      score = 0.78;
    }

    score -= Math.min(hashtags.length * 0.05, 0.35);
    score -= Math.min(mentions.length * 0.07, 0.35);
    score -= Math.min(linkCount * 0.1, 0.3);

    return this.clamp(score, 0.2, 1.0);
  }

  private normalizeMetadata(metadata: unknown) {
    if (!metadata) return {};
    if (typeof metadata === 'object') return metadata as Record<string, unknown>;
    if (typeof metadata === 'string') {
      try {
        return JSON.parse(metadata) as Record<string, unknown>;
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  private normalizeTagsFromMetadata(metadata: unknown) {
    const meta = this.normalizeMetadata(metadata);
    const tags = Array.isArray(meta.hashtags)
      ? meta.hashtags.map((tag) => String(tag).toLowerCase())
      : [];

    const unique = Array.from(new Set(tags))
      .map((tag) => tag.trim())
      .filter(Boolean);

    return unique.slice(0, 12);
  }

  private normalizeCategoriesFromMetadata(metadata: unknown) {
    const meta = this.normalizeMetadata(metadata);
    const categories = Array.isArray(meta.categories)
      ? meta.categories.map((cat) => String(cat).toLowerCase())
      : [];

    const unique = Array.from(new Set(categories))
      .map((cat) => cat.trim())
      .filter(Boolean);

    return unique.slice(0, MAX_CATEGORIES_PER_POST);
  }

  private classifyPostCategories(body: string, hashtags: string[]) {
    if (!body && hashtags.length == 0) return [];

    const words = new Set(
      body
        .toLowerCase()
        .match(/[a-z0-9]+/g)
        ?.map((word) => word.trim())
        .filter(Boolean) ?? [],
    );
    const tags = new Set(
      hashtags.map((tag) => tag.toLowerCase().trim()).filter(Boolean),
    );

    const scores = new Map<string, number>();
    for (const [category, keywords] of Object.entries(
      FEED_CATEGORY_KEYWORDS,
    )) {
      let score = 0;
      if (tags.has(category)) score += 3;
      if (words.has(category)) score += 2;

      for (const keyword of keywords) {
        if (tags.has(keyword)) score += 3;
        if (words.has(keyword)) score += 1;
      }

      if (score >= CATEGORY_SCORE_THRESHOLD) {
        scores.set(category, score);
      }
    }

    return Array.from(scores.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, MAX_CATEGORIES_PER_POST)
      .map(([category]) => category);
  }

  private extractSafetySignals(
    metadata: unknown,
    fallbackQuality: number,
  ) {
    const meta = this.normalizeMetadata(metadata);
    const trust =
      typeof meta.trust === 'object' && meta.trust
        ? (meta.trust as Record<string, unknown>)
        : {};
    const moderation =
      typeof meta.moderation === 'object' && meta.moderation
        ? (meta.moderation as Record<string, unknown>)
        : {};

    const trustScore = Number(trust.trustScore ?? 0.5);
    const spamScore = Number(trust.spamScore ?? 0);
    const moderationAction = String(moderation.action ?? 'allow');
    const moderationPenalty =
      moderationAction === 'review'
        ? 0.15
        : moderationAction === 'block'
        ? 0.5
        : 0;

    return {
      authorReputation: this.clamp(trustScore),
      safetyScore: this.clamp(1 - this.clamp(spamScore)),
      negativeFeedback: this.clamp(spamScore + moderationPenalty),
      isSensitive: moderationAction === 'review',
      qualityScore:
        typeof meta.qualityScore === 'number'
          ? this.clamp(meta.qualityScore)
          : fallbackQuality,
    };
  }

  private async checkModeration(input: {
    content: string;
    userId?: string;
    contentId?: string;
  }) {
    if (!config.MODERATION_ENGINE_URL) {
      return { action: 'allow', reasons: [], confidence: 0 };
    }

    const url = `${config.MODERATION_ENGINE_URL.replace(/\/$/, '')}/moderation/check`;
    const response = await this.postJson<{
      action: string;
      reasons: string[];
      confidence: number;
    }>(url, input, 1200);

    return (
      response ?? { action: 'allow', reasons: [], confidence: 0 }
    );
  }

  private async updateInterestFromPost(input: {
    userId: string;
    postId: string;
    delta: number;
  }) {
    if (input.delta === 0) return;

    const [post] = await db
      .select({
        metadata: feedPosts.metadata,
        body: feedPosts.body,
      })
      .from(feedPosts)
      .where(eq(feedPosts.id, input.postId))
      .limit(1);

    if (!post) return;

    const tags = this.normalizeTagsFromMetadata(post.metadata);
    const categories = this.normalizeCategoriesFromMetadata(
      post.metadata,
    );
    const derivedCategories =
      categories.length > 0
        ? categories
        : this.classifyPostCategories(
            post.body ? String(post.body) : '',
            tags,
          );
    if (tags.length == 0 && derivedCategories.length == 0) return;

    const now = new Date();
    await db.transaction(async (tx) => {
      for (const tag of tags) {
        await tx
          .insert(userInterestProfiles)
          .values({
            userId: input.userId,
            tag,
            score: input.delta,
            updatedAt: now,
          })
          .onConflictDoUpdate({
            target: [
              userInterestProfiles.userId,
              userInterestProfiles.tag,
            ],
            set: {
              score: sql<number>`GREATEST(${userInterestProfiles.score} + ${input.delta}, 0)`,
              updatedAt: now,
            },
          });
      }

      for (const category of derivedCategories) {
        const adjusted = input.delta * INTEREST_CATEGORY_MULTIPLIER;
        await tx
          .insert(userInterestProfiles)
          .values({
            userId: input.userId,
            tag: `cat:${category}`,
            score: adjusted,
            updatedAt: now,
          })
          .onConflictDoUpdate({
            target: [
              userInterestProfiles.userId,
              userInterestProfiles.tag,
            ],
            set: {
              score: sql<number>`GREATEST(${userInterestProfiles.score} + ${adjusted}, 0)`,
              updatedAt: now,
            },
          });
      }
    });
  }

  private async fetchInterestScores(userId: string, tags: string[]) {
    if (tags.length == 0) return new Map<string, number>();

    const rows = await db
      .select({
        tag: userInterestProfiles.tag,
        score: sql<number>`(${userInterestProfiles.score} * EXP(-GREATEST(EXTRACT(EPOCH FROM (now() - ${userInterestProfiles.updatedAt})) / 3600.0, 0) / ${INTEREST_DECAY_HOURS}))`,
      })
      .from(userInterestProfiles)
      .where(
        and(
          eq(userInterestProfiles.userId, userId),
          inArray(userInterestProfiles.tag, tags),
        ),
      );

    const map = new Map<string, number>();
    for (const row of rows) {
      const tag = String(row.tag);
      const score = Number(row.score ?? 0);
      if (!Number.isNaN(score)) {
        map.set(tag, score);
      }
    }

    return map;
  }
  private async evaluateTrustSafety(input: {
    userId: string;
    accountAgeDays: number;
    emailVerified: boolean;
    phoneVerified: boolean;
    qualityScore: number;
    linkCount: number;
    mentionCount: number;
  }) {
    if (!config.TRUST_SAFETY_ENGINE_URL) {
      return {
        trustScore: 0.5,
        spamScore: 0,
        shadowBan: false,
      };
    }

    const base = config.TRUST_SAFETY_ENGINE_URL.replace(/\/$/, '');
    const trust = await this.postJson<{ trust_score: number }>(
      `${base}/trust/score`,
      {
        accountAgeDays: input.accountAgeDays,
        reportCount: 0,
        blockCount: 0,
        emailVerified: input.emailVerified,
        phoneVerified: input.phoneVerified,
        qualityScore: input.qualityScore,
      },
      1200,
    );

    const spam = await this.postJson<{ spam_score: number }>(
      `${base}/spam/score`,
      {
        linkCount: input.linkCount,
        mentionCount: input.mentionCount,
        duplicateRatio: 0,
        postRatePerHour: 0,
      },
      1200,
    );

    const trustScore = this.clamp(Number(trust?.trust_score ?? 0.5));
    const spamScore = this.clamp(Number(spam?.spam_score ?? 0));
    const shadow = await this.postJson<{ shadow_ban: boolean }>(
      `${base}/shadow/evaluate`,
      {
        trustScore,
        spamScore,
      },
      900,
    );

    return {
      trustScore,
      spamScore,
      shadowBan: shadow?.shadow_ban === true,
    };
  }

  private async fetchExperimentVariant(userId: string) {
    if (!config.EXPERIMENTATION_ENGINE_URL) return null;
    const url = `${config.EXPERIMENTATION_ENGINE_URL.replace(/\/$/, '')}/experiments/assign`;
    const response = await this.postJson<{
      variant?: string;
    }>(
      url,
      {
        user_id: userId,
        experiment_key: FEED_EXPERIMENT_KEY,
        variants: FEED_EXPERIMENT_VARIANTS,
        salt: 'feed',
      },
      EXPERIMENT_ENGINE_TIMEOUT_MS,
    );

    return response?.variant ? String(response.variant) : null;
  }

  private async fetchEngagementScores(input: {
    userId: string;
    candidates: EngagementCandidate[];
  }) {
    if (!config.ENGAGEMENT_ENGINE_URL) return null;
    if (input.candidates.length == 0) return [];

    const url = `${config.ENGAGEMENT_ENGINE_URL.replace(/\/$/, '')}/engagement/score`;
    const response = await this.postJson<{
      predictions?: Array<Record<string, unknown>>;
    }>(
      url,
      {
        user_id: input.userId,
        candidates: input.candidates,
      },
      ENGAGEMENT_ENGINE_TIMEOUT_MS,
    );

    if (!response || !Array.isArray(response.predictions)) return null;
    return response.predictions;
  }

  private async rankWithDecisionEngine(input: {
    userId: string;
    limit: number;
    mode: FeedMode;
    candidates: DecisionEngineCandidate[];
    variant?: string | null;
  }) {
    if (!config.DECISION_ENGINE_URL) return null;
    if (input.candidates.length == 0) return [];

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), DECISION_ENGINE_TIMEOUT_MS);

    try {
      const response = await fetch(
        `${config.DECISION_ENGINE_URL.replace(/\/$/, '')}/rank/feed`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            user_id: input.userId,
            limit: input.limit,
            mode: input.mode,
            candidates: input.candidates,
            variant: input.variant ?? undefined,
          }),
          signal: controller.signal,
        },
      );

      if (!response.ok) return null;

      const data = await response.json();
      if (!data || !Array.isArray(data.ordered_ids)) return null;

      return data.ordered_ids.map((id: unknown) => String(id));
    } catch (_) {
      return null;
    } finally {
      clearTimeout(timeout);
    }
  }

  async createPost(input: { userId: string; body: string }) {
    const body = input.body.trim();
    if (!body) {
      throw new BadRequestException('Post body required');
    }

    const mentions = this.extractMentions(body);
    const hashtags = this.extractHashtags(body);
    const categories = this.classifyPostCategories(body, hashtags);
    const linkCount = this.countLinks(body);
    const qualityScore = this.estimateQualityScore(
      body,
      hashtags,
      mentions,
      linkCount,
    );

    const author = await db
      .select({
        id: users.id,
        username: users.username,
        displayName: users.displayName,
        createdAt: users.createdAt,
        emailVerifiedAt: users.emailVerifiedAt,
        phoneNumber: users.phoneNumber,
      })
      .from(users)
      .where(eq(users.id, input.userId))
      .limit(1);

    if (!author[0]) {
      throw new NotFoundException('Author not found');
    }

    const moderation = await this.checkModeration({
      content: body,
      userId: input.userId,
    });
    if (moderation.action === 'block') {
      throw new BadRequestException('Post blocked by moderation');
    }

    const createdAt = author[0].createdAt ?? new Date();
    const accountAgeDays =
      Math.max(Date.now() - createdAt.getTime(), 0) /
      (1000 * 60 * 60 * 24);
    const trust = await this.evaluateTrustSafety({
      userId: input.userId,
      accountAgeDays,
      emailVerified: Boolean(author[0].emailVerifiedAt),
      phoneVerified: Boolean(author[0].phoneNumber),
      qualityScore,
      linkCount,
      mentionCount: mentions.length,
    });

    const metadata = {
      mentions,
      hashtags,
      categories,
      moderation,
      trust,
      shadowBan: trust.shadowBan === true,
      qualityScore,
    };

    const [post] = await db
      .insert(feedPosts)
      .values({
        authorId: input.userId,
        body,
        metadata,
        updatedAt: new Date(),
      })
      .returning();

    const payload = {
      type: 'FEED_POST',
      payload: {
        id: post.id,
        body: post.body,
        createdAt: post.createdAt,
        likeCount: post.likeCount,
        commentCount: post.commentCount,
        shareCount: post.shareCount,
        liked: false,
        followed: false,
        mentions,
        hashtags,
        author: {
          id: author[0].id,
          username: author[0].username,
          displayName: author[0].displayName ?? author[0].username,
        },
      },
      ts: Date.now(),
    };

    if (!trust.shadowBan) {
      void publishFeedEvent(payload);
    }
    void this.notifyMentions({
      authorId: input.userId,
      mentions,
      postId: post.id,
    }).catch(() => {});

    return payload.payload;
  }

  async listFeed(input: {
    userId: string;
    limit?: number;
    before?: Date;
    mode?: FeedMode;
  }) {
    const mutedPhrases = await this.loadMutedPhrases(input.userId);
    const mode = input.mode ?? 'for-you';

    const items =
      mode === 'following'
        ? await this.listFollowingFeed(input)
        : await this.listForYouFeed(input);

    return this.filterMuted(items, mutedPhrases);
  }

  private async listForYouFeed(input: {
    userId: string;
    limit?: number;
    before?: Date;
  }) {
    const limit = Math.min(
      Math.max(input.limit ?? 20, 1),
      MAX_FEED_LIMIT,
    );
    const candidateLimit = Math.min(limit * 5, MAX_FEED_CANDIDATES);
    const beforeCondition = input.before
      ? sql`AND p.created_at < ${input.before}`
      : sql``;

    const rows = await db.execute(sql`
      WITH affinity AS (
        SELECT
          t.author_id,
          SUM(t.likes)::int AS likes,
          SUM(t.comments)::int AS comments,
          SUM(t.shares)::int AS shares
        FROM (
          SELECT
            p.author_id,
            COUNT(*)::int AS likes,
            0::int AS comments,
            0::int AS shares
          FROM feed_likes l
          JOIN feed_posts p ON p.id = l.post_id
          WHERE l.user_id = ${input.userId}
          GROUP BY p.author_id
          UNION ALL
          SELECT
            p.author_id,
            0::int AS likes,
            COUNT(*)::int AS comments,
            0::int AS shares
          FROM feed_comments c
          JOIN feed_posts p ON p.id = c.post_id
          WHERE c.author_id = ${input.userId}
          GROUP BY p.author_id
          UNION ALL
          SELECT
            p.author_id,
            0::int AS likes,
            0::int AS comments,
            COUNT(*)::int AS shares
          FROM feed_shares s
          JOIN feed_posts p ON p.id = s.post_id
          WHERE s.user_id = ${input.userId}
          GROUP BY p.author_id
        ) t
        GROUP BY t.author_id
      ),
      base AS (
        SELECT
          p.id AS "id",
          p.body AS "body",
          p.created_at AS "createdAt",
          p.like_count AS "likeCount",
          p.comment_count AS "commentCount",
          p.share_count AS "shareCount",
          COALESCE(p.metadata->'mentions', '[]'::jsonb) AS "mentions",
          COALESCE(p.metadata->'hashtags', '[]'::jsonb) AS "hashtags",
          p.metadata AS "metadata",
          u.id AS "authorId",
          u.username AS "authorUsername",
          u.display_name AS "authorDisplayName",
          (fl.user_id IS NOT NULL) AS "liked",
          (f.follower_id IS NOT NULL) AS "followed",
          (f2.follower_id IS NOT NULL) AS "followedBy",
          COALESCE(a.likes, 0) AS "affinityLikes",
          COALESCE(a.comments, 0) AS "affinityComments",
          COALESCE(a.shares, 0) AS "affinityShares",
          CASE
            WHEN f.follower_id IS NOT NULL AND f2.follower_id IS NOT NULL THEN 'friend'
            WHEN f.follower_id IS NOT NULL THEN 'following'
            WHEN f2.follower_id IS NOT NULL THEN 'followed_by'
            ELSE 'other'
          END AS "relationship"
        FROM feed_posts p
        JOIN users u ON u.id = p.author_id
        LEFT JOIN feed_likes fl
          ON fl.post_id = p.id
         AND fl.user_id = ${input.userId}
        LEFT JOIN follows f
          ON f.follower_id = ${input.userId}
         AND f.following_id = p.author_id
        LEFT JOIN follows f2
          ON f2.follower_id = p.author_id
         AND f2.following_id = ${input.userId}
        LEFT JOIN affinity a
          ON a.author_id = p.author_id
        WHERE 1=1
        ${beforeCondition}
        AND (
          COALESCE(p.metadata->>'shadowBan', 'false') != 'true'
          OR p.author_id = ${input.userId}
        )
        AND NOT EXISTS (
          SELECT 1
          FROM user_blocks b
          WHERE (b.blocker_id = ${input.userId} AND b.blocked_id = p.author_id)
             OR (b.blocker_id = p.author_id AND b.blocked_id = ${input.userId})
        )
      )
      SELECT *
      FROM base
      ORDER BY "createdAt" DESC
      LIMIT ${candidateLimit}
    `);

    const items = this.mapFeedRows(rows.rows);
    const now = new Date();
    const engagementCandidates: EngagementCandidate[] = rows.rows.map((row) => {
      const body = row.body ? String(row.body) : '';
      const hashtags = Array.isArray(row.hashtags)
        ? row.hashtags.map((tag: unknown) => String(tag))
        : [];
      const mentions = Array.isArray(row.mentions)
        ? row.mentions.map((tag: unknown) => String(tag))
        : [];
      const createdAt = new Date(row.createdAt);
      const ageHours =
        Math.max(now.getTime() - createdAt.getTime(), 0) /
        (1000 * 60 * 60);
      const signals = this.extractSafetySignals(
        row.metadata,
        this.estimateQualityScore(body, hashtags, mentions, this.countLinks(body)),
      );

      return {
        postId: String(row.id),
        createdAt: createdAt.toISOString(),
        relationship: (row.relationship as RelationshipLabel) ?? 'other',
        textLength: body.length,
        mediaCount: 0,
        hashtagCount: hashtags.length,
        mentionCount: mentions.length,
        ageHours,
        authorReputation: signals.authorReputation,
        affinity: {
          likes: Number(row.affinityLikes ?? 0),
          comments: Number(row.affinityComments ?? 0),
          shares: Number(row.affinityShares ?? 0),
        },
      };
    });

    const tagSet = new Set<string>();
    for (const row of rows.rows) {
      const tags = Array.isArray(row.hashtags)
        ? row.hashtags.map((tag: unknown) => String(tag).toLowerCase())
        : [];
      for (const tag of tags) {
        const trimmed = tag.trim();
        if (trimmed) tagSet.add(trimmed);
      }

      const categories = this.normalizeCategoriesFromMetadata(
        row.metadata,
      );
      if (categories.length == 0) {
        const inferred = this.classifyPostCategories(
          row.body ? String(row.body) : '',
          tags,
        );
        for (const category of inferred) {
          tagSet.add(`cat:${category}`);
        }
      } else {
        for (const category of categories) {
          tagSet.add(`cat:${category}`);
        }
      }
    }

    const [variant, engagementPredictions, interestMap] = await Promise.all([
      this.fetchExperimentVariant(input.userId),
      this.fetchEngagementScores({
        userId: input.userId,
        candidates: engagementCandidates,
      }),
      this.fetchInterestScores(input.userId, Array.from(tagSet)),
    ]);

    const engagementMap = new Map<string, number>();
    if (Array.isArray(engagementPredictions)) {
      for (const prediction of engagementPredictions) {
        const postId = String(
          prediction['postId'] ?? prediction['post_id'] ?? '',
        );
        if (!postId) continue;
        const scoreRaw =
          prediction['engagementScore'] ??
          prediction['engagement_score'] ??
          0;
        const score = Number(scoreRaw);
        if (!Number.isNaN(score)) {
          engagementMap.set(postId, score);
        }
      }
    }

    const candidates: DecisionEngineCandidate[] = rows.rows.map((row) => {
      const body = row.body ? String(row.body) : '';
      const hashtags = Array.isArray(row.hashtags)
        ? row.hashtags.map((tag: unknown) => String(tag))
        : [];
      const mentions = Array.isArray(row.mentions)
        ? row.mentions.map((tag: unknown) => String(tag))
        : [];
      const categories =
        this.normalizeCategoriesFromMetadata(row.metadata).length > 0
          ? this.normalizeCategoriesFromMetadata(row.metadata)
          : this.classifyPostCategories(body, hashtags);
      const linkCount = this.countLinks(body);
      const qualityScore = this.estimateQualityScore(
        body,
        hashtags,
        mentions,
        linkCount,
      );
      const signals = this.extractSafetySignals(
        row.metadata,
        qualityScore,
      );
      const engagementScore =
        engagementMap.get(String(row.id)) ?? 0;
      let interestScore = 0;
      for (const tag of hashtags) {
        const score = interestMap.get(tag.toLowerCase());
        if (score) {
          interestScore += score;
        }
      }
      for (const category of categories) {
        const score = interestMap.get(`cat:${category}`);
        if (score) {
          interestScore += score;
        }
      }
      interestScore = Math.min(interestScore, MAX_INTEREST_SCORE);

      return {
        postId: String(row.id),
        authorId: String(row.authorId),
        createdAt: new Date(row.createdAt).toISOString(),
        likeCount: Number(row.likeCount ?? 0),
        commentCount: Number(row.commentCount ?? 0),
        shareCount: Number(row.shareCount ?? 0),
        textLength: body.length,
        mediaCount: 0,
        relationship: (row.relationship as RelationshipLabel) ?? 'other',
        affinity: {
          likes: Number(row.affinityLikes ?? 0),
          comments: Number(row.affinityComments ?? 0),
          shares: Number(row.affinityShares ?? 0),
        },
        hashtags,
        mentions,
        qualityScore: signals.qualityScore,
        authorReputation: signals.authorReputation,
        safetyScore: signals.safetyScore,
        negativeFeedback: signals.negativeFeedback,
        isSensitive: signals.isSensitive,
        engagementScore,
        interestScore,
      };
    });

    const orderedIds = await this.rankWithDecisionEngine({
      userId: input.userId,
      limit,
      mode: 'for-you',
      candidates,
      variant,
    });

    if (!orderedIds) {
      return items.slice(0, limit);
    }

    const byId = new Map(items.map((item) => [item.id, item]));
    const ordered = orderedIds
      .map((id) => byId.get(id))
      .filter((item) => item !== undefined) as typeof items;

    if (ordered.length < limit) {
      const seen = new Set(ordered.map((item) => item.id));
      for (const item of items) {
        if (ordered.length >= limit) break;
        if (!seen.has(item.id)) {
          ordered.push(item);
          seen.add(item.id);
        }
      }
    }

    return ordered.slice(0, limit);
  }

  private async listFollowingFeed(input: {
    userId: string;
    limit?: number;
    before?: Date;
  }) {
    const limit = Math.min(
      Math.max(input.limit ?? 20, 1),
      MAX_FEED_LIMIT,
    );
    const beforeCondition = input.before
      ? sql`AND p.created_at < ${input.before}`
      : sql``;

    const rows = await db.execute(sql`
      SELECT
        p.id AS "id",
        p.body AS "body",
        p.created_at AS "createdAt",
        p.like_count AS "likeCount",
        p.comment_count AS "commentCount",
        p.share_count AS "shareCount",
        COALESCE(p.metadata->'mentions', '[]'::jsonb) AS "mentions",
        COALESCE(p.metadata->'hashtags', '[]'::jsonb) AS "hashtags",
        p.metadata AS "metadata",
        u.id AS "authorId",
        u.username AS "authorUsername",
        u.display_name AS "authorDisplayName",
        (fl.user_id IS NOT NULL) AS "liked",
        (f.follower_id IS NOT NULL) AS "followed",
        CASE
          WHEN f.follower_id IS NOT NULL AND f2.follower_id IS NOT NULL THEN 'friend'
          WHEN f.follower_id IS NOT NULL THEN 'following'
          ELSE 'other'
        END AS "relationship"
      FROM feed_posts p
      JOIN users u ON u.id = p.author_id
      LEFT JOIN feed_likes fl
        ON fl.post_id = p.id
       AND fl.user_id = ${input.userId}
      LEFT JOIN follows f
        ON f.follower_id = ${input.userId}
       AND f.following_id = p.author_id
      LEFT JOIN follows f2
        ON f2.follower_id = p.author_id
       AND f2.following_id = ${input.userId}
      WHERE 1=1
      ${beforeCondition}
      AND (
        COALESCE(p.metadata->>'shadowBan', 'false') != 'true'
        OR p.author_id = ${input.userId}
      )
      AND (p.author_id = ${input.userId} OR f.follower_id IS NOT NULL)
      AND NOT EXISTS (
        SELECT 1
        FROM user_blocks b
        WHERE (b.blocker_id = ${input.userId} AND b.blocked_id = p.author_id)
           OR (b.blocker_id = p.author_id AND b.blocked_id = ${input.userId})
      )
      ORDER BY p.created_at DESC
      LIMIT ${limit}
    `);

    return this.mapFeedRows(rows.rows);
  }

  async toggleLike(input: { userId: string; postId: string }) {
    const now = new Date();

    const result = await db.transaction(async (tx) => {
      const postExists = await tx
        .select({ id: feedPosts.id })
        .from(feedPosts)
        .where(eq(feedPosts.id, input.postId))
        .limit(1);

      if (!postExists[0]) {
        throw new NotFoundException('Post not found');
      }

      const existing = await tx
        .select()
        .from(feedLikes)
        .where(
          and(
            eq(feedLikes.postId, input.postId),
            eq(feedLikes.userId, input.userId),
          ),
        )
        .limit(1);

      if (existing[0]) {
        await tx
          .delete(feedLikes)
          .where(
            and(
              eq(feedLikes.postId, input.postId),
              eq(feedLikes.userId, input.userId),
            ),
          );

        const [post] = await tx
          .update(feedPosts)
          .set({
            likeCount: sql<number>`GREATEST(${feedPosts.likeCount} - 1, 0)`,
            updatedAt: now,
          })
          .where(eq(feedPosts.id, input.postId))
          .returning();

        return { liked: false, likeCount: post?.likeCount ?? 0 };
      }

      await tx.insert(feedLikes).values({
        postId: input.postId,
        userId: input.userId,
      });

      const [post] = await tx
        .update(feedPosts)
        .set({
          likeCount: sql<number>`(${feedPosts.likeCount} + 1)`,
          updatedAt: now,
        })
        .where(eq(feedPosts.id, input.postId))
        .returning();

      return { liked: true, likeCount: post?.likeCount ?? 0 };
    });

    void publishFeedEvent({
      type: 'FEED_LIKE',
      payload: {
        postId: input.postId,
        userId: input.userId,
        liked: result.liked,
        likeCount: result.likeCount,
      },
      ts: Date.now(),
    });

    void this.updateInterestFromPost({
      userId: input.userId,
      postId: input.postId,
      delta: result.liked
        ? INTEREST_WEIGHTS.like
        : -INTEREST_WEIGHTS.like,
    }).catch(() => {});

    if (result.liked) {
      const [post] = await db
        .select({
          authorId: feedPosts.authorId,
          body: feedPosts.body,
        })
        .from(feedPosts)
        .where(eq(feedPosts.id, input.postId))
        .limit(1);

      if (post && post.authorId !== input.userId) {
        void this.notifications
          .createNotification({
            userId: post.authorId,
            actorId: input.userId,
            type: 'like',
            title: 'New like',
            body: 'Someone liked your post',
            data: { postId: input.postId },
            push: true,
          })
          .catch(() => {});
      }
    }

    return result;
  }

  async addComment(input: {
    userId: string;
    postId: string;
    body: string;
  }) {
    const body = input.body.trim();
    if (!body) {
      throw new BadRequestException('Comment body required');
    }

    const moderation = await this.checkModeration({
      content: body,
      userId: input.userId,
    });
    if (moderation.action === 'block') {
      throw new BadRequestException('Comment blocked by moderation');
    }

    const now = new Date();
    let postAuthorId: string | null = null;

    const result = await db.transaction(async (tx) => {
      const postExists = await tx
        .select({ id: feedPosts.id, authorId: feedPosts.authorId })
        .from(feedPosts)
        .where(eq(feedPosts.id, input.postId))
        .limit(1);

      if (!postExists[0]) {
        throw new NotFoundException('Post not found');
      }

      postAuthorId = postExists[0].authorId;

      const [comment] = await tx
        .insert(feedComments)
        .values({
          postId: input.postId,
          authorId: input.userId,
          body,
        })
        .returning();

      const [post] = await tx
        .update(feedPosts)
        .set({
          commentCount: sql<number>`(${feedPosts.commentCount} + 1)`,
          updatedAt: now,
        })
        .where(eq(feedPosts.id, input.postId))
        .returning();

      return { comment, commentCount: post?.commentCount ?? 0 };
    });

    const author = await db
      .select({
        id: users.id,
        username: users.username,
        displayName: users.displayName,
      })
      .from(users)
      .where(eq(users.id, input.userId))
      .limit(1);

    const payload = {
      id: result.comment.id,
      body: result.comment.body,
      createdAt: result.comment.createdAt,
      author: {
        id: author[0]?.id,
        username: author[0]?.username,
        displayName:
          author[0]?.displayName ?? author[0]?.username,
      },
    };

    void publishFeedEvent({
      type: 'FEED_COMMENT',
      payload: {
        postId: input.postId,
        comment: payload,
        commentCount: result.commentCount,
      },
      ts: Date.now(),
    });

    if (postAuthorId && postAuthorId !== input.userId) {
      void this.notifications
        .createNotification({
          userId: postAuthorId,
          actorId: input.userId,
          type: 'comment',
          title: 'New comment',
          body: 'Someone commented on your post',
          data: {
            postId: input.postId,
            commentId: result.comment.id,
          },
          push: true,
        })
        .catch(() => {});
    }

    void this.updateInterestFromPost({
      userId: input.userId,
      postId: input.postId,
      delta: INTEREST_WEIGHTS.comment,
    }).catch(() => {});

    return {
      comment: payload,
      commentCount: result.commentCount,
    };
  }

  async listComments(input: {
    userId: string;
    postId: string;
    limit?: number;
  }) {
    const limit = Math.min(
      Math.max(input.limit ?? 30, 1),
      MAX_FEED_LIMIT,
    );

    const rows = await db.execute(sql`
      SELECT
        c.id AS "id",
        c.body AS "body",
        c.created_at AS "createdAt",
        u.id AS "authorId",
        u.username AS "authorUsername",
        u.display_name AS "authorDisplayName"
      FROM feed_comments c
      JOIN users u ON u.id = c.author_id
      WHERE c.post_id = ${input.postId}
        AND NOT EXISTS (
          SELECT 1
          FROM user_blocks b
          WHERE (b.blocker_id = ${input.userId} AND b.blocked_id = u.id)
             OR (b.blocker_id = u.id AND b.blocked_id = ${input.userId})
        )
      ORDER BY c.created_at ASC
      LIMIT ${limit}
    `);

    return rows.rows.map((row) => ({
      id: row.id,
      body: row.body,
      createdAt: row.createdAt,
      author: {
        id: row.authorId,
        username: row.authorUsername,
        displayName: row.authorDisplayName ?? row.authorUsername,
      },
    }));
  }

  async sharePost(input: { userId: string; postId: string }) {
    const now = new Date();
    let postAuthorId: string | null = null;

    const result = await db.transaction(async (tx) => {
      const postExists = await tx
        .select({ id: feedPosts.id, authorId: feedPosts.authorId })
        .from(feedPosts)
        .where(eq(feedPosts.id, input.postId))
        .limit(1);

      if (!postExists[0]) {
        throw new NotFoundException('Post not found');
      }

      postAuthorId = postExists[0].authorId;

      const existing = await tx
        .select()
        .from(feedShares)
        .where(
          and(
            eq(feedShares.postId, input.postId),
            eq(feedShares.userId, input.userId),
          ),
        )
        .limit(1);

      if (existing[0]) {
        const [post] = await tx
          .select({ shareCount: feedPosts.shareCount })
          .from(feedPosts)
          .where(eq(feedPosts.id, input.postId))
          .limit(1);

        return {
          shared: true,
          shareCount: post?.shareCount ?? 0,
          created: false,
        };
      }

      await tx.insert(feedShares).values({
        postId: input.postId,
        userId: input.userId,
      });

      const [post] = await tx
        .update(feedPosts)
        .set({
          shareCount: sql<number>`(${feedPosts.shareCount} + 1)`,
          updatedAt: now,
        })
        .where(eq(feedPosts.id, input.postId))
        .returning();

      return { shared: true, shareCount: post?.shareCount ?? 0, created: true };
    });

    void publishFeedEvent({
      type: 'FEED_SHARE',
      payload: {
        postId: input.postId,
        userId: input.userId,
        shareCount: result.shareCount,
      },
      ts: Date.now(),
    });

    if (result.shared && postAuthorId && postAuthorId !== input.userId) {
      void this.notifications
        .createNotification({
          userId: postAuthorId,
          actorId: input.userId,
          type: 'share',
          title: 'Post shared',
          body: 'Someone shared your post',
          data: { postId: input.postId },
          push: true,
        })
        .catch(() => {});
    }

    if (result.created) {
      void this.updateInterestFromPost({
        userId: input.userId,
        postId: input.postId,
        delta: INTEREST_WEIGHTS.share,
      }).catch(() => {});
    }

    return result;
  }

  private async notifyMentions(input: {
    authorId: string;
    mentions: string[];
    postId: string;
  }) {
    if (!input.mentions.length) return;

    const unique = Array.from(new Set(input.mentions))
      .map((name) => name.trim().toLowerCase())
      .filter(Boolean)
      .slice(0, 20);

    if (!unique.length) return;

    const rows = await db
      .select({
        id: users.id,
        username: users.username,
        displayName: users.displayName,
      })
      .from(users)
      .where(inArray(users.username, unique));

    if (!rows.length) return;

    const author = await db
      .select({
        id: users.id,
        username: users.username,
        displayName: users.displayName,
      })
      .from(users)
      .where(eq(users.id, input.authorId))
      .limit(1);

    const authorName =
      author[0]?.displayName ?? author[0]?.username ?? 'Someone';

    await Promise.all(
      rows
        .filter((row) => row.id !== input.authorId)
        .map((row) =>
          this.notifications.createNotification({
            userId: row.id,
            actorId: input.authorId,
            type: 'mention',
            title: 'Mentioned you',
            body: `${authorName} mentioned you in a post`,
            data: { postId: input.postId },
            push: true,
          }),
        ),
    );
  }
}
