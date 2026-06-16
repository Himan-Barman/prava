import { query, queryMany, queryOne, withTransaction } from "../../lib/pg.js";
import { requireAuth } from "../../lib/auth.js";
import { HttpError, ensure, generateId, now, toIso } from "../../lib/security.js";
import { publishToFeedSubscribers } from "../realtime/hub.js";
import { enqueueNotificationEvent } from "../notification/repository.js";
import {
  buildFeedPage,
  clearFeedServedHistory,
  deleteCustomFeed,
  explainPostRecommendation,
  exportFeedSettings,
  followTopic,
  getFeedPreferences,
  ingestFeedEvents,
  listCustomFeeds,
  listFeedTopics,
  listInferredInterests,
  markPostHidden,
  markPostNotInterested,
  normalizeFeedMode,
  muteTopic,
  recordFeedFeedback,
  recordFeedEvent,
  removeInferredInterest,
  resetFeedPersonalization,
  runFeedAggregationJobs,
  saveCustomFeed,
  startFeedAggregationScheduler,
  unfollowTopic,
  unmuteTopic,
  updateFeedPreferences,
} from "./recommendation.js";

const MAX_POST_WORDS = 200;
const MAX_POST_CHARS = 1600;
const MAX_COMMENT_WORDS = 120;
const MAX_COMMENT_CHARS = 900;
const MAX_TAGS_PER_POST = 12;

function parseLimit(raw: unknown, fallback: number, min: number, max: number): number {
  const parsed = Number.parseInt(String(raw || ""), 10);
  if (Number.isNaN(parsed)) {
    return fallback;
  }
  return Math.max(min, Math.min(max, parsed));
}

function escapeRegex(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function wordCount(value: string): number {
  return value.split(/\s+/).filter(Boolean).length;
}

function normalizeBody(value: unknown, maxWords: number, maxChars: number, label: string): string {
  const body = String(value || "")
    .replace(/\s+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
  ensure(body.length > 0, 400, `${label} cannot be empty`);
  ensure(body.length <= maxChars, 400, `${label} is too long`);
  ensure(wordCount(body) <= maxWords, 400, `${label} must be under ${maxWords} words`);
  return body;
}

function normalizeTag(value: unknown): string {
  return String(value || "")
    .trim()
    .replace(/^#/, "")
    .toLowerCase()
    .replace(/[^a-z0-9_]/g, "")
    .slice(0, 32);
}

function placeholders(count: number, offset = 1): string {
  return Array.from({ length: count }, (_, index) => `$${index + offset}`).join(", ");
}

function extractMatches(body: string, symbol: string): string[] {
  const charset = symbol === "@" ? "a-zA-Z0-9_." : "a-zA-Z0-9_";
  const pattern = new RegExp(`(?:^|\\s)${escapeRegex(symbol)}([${charset}]{2,32})`, "g");
  const out = new Set<string>();
  for (const match of body.matchAll(pattern)) {
    out.add(String(match[1] || "").toLowerCase());
  }
  return [...out];
}

function extractHashtags(body: string): string[] {
  return extractMatches(body, "#")
    .map(normalizeTag)
    .filter((tag) => tag.length >= 2)
    .slice(0, MAX_TAGS_PER_POST);
}

function mapFeedPost(post: any, author: any, liked: boolean, followed: boolean) {
  return {
    id: post.post_id,
    body: post.body,
    createdAt: toIso(post.created_at),
    likeCount: Number(post.like_count || 0),
    commentCount: Number(post.comment_count || 0),
    shareCount: Number(post.share_count || 0),
    readCount: Number(post.read_count || 0),
    rankScore: Number(post.rank_score || 0),
    recommendationReason: post.recommendation_reason || null,
    recommendationExplanation: post.recommendation_explanation || null,
    recommendationMetadata: post.recommendation_metadata || null,
    recommendationReasons: Array.isArray(post.recommendation_reasons) ? post.recommendation_reasons : [],
    candidateSources: Array.isArray(post.candidate_sources) ? post.candidate_sources : [],
    liked,
    followed,
    mentions: Array.isArray(post.mentions) ? post.mentions : [],
    hashtags: Array.isArray(post.hashtags) ? post.hashtags : [],
    relationship: followed ? "following" : "other",
    author: {
      id: author?.user_id || post.author_id,
      username: author?.username || "unknown",
      displayName: author?.display_name || author?.username || "Unknown",
      avatarUrl: author?.avatar_url || ""
    }
  };
}

function mapFeedComment(comment: any, author: any, liked: boolean) {
  return {
    id: comment.comment_id,
    postId: comment.post_id,
    parentCommentId: comment.parent_comment_id || null,
    body: comment.body,
    createdAt: toIso(comment.created_at),
    likeCount: Number(comment.like_count || 0),
    replyCount: Number(comment.reply_count || 0),
    liked,
    author: {
      id: author?.user_id || comment.author_id,
      username: author?.username || "unknown",
      displayName: author?.display_name || author?.username || "Unknown",
      avatarUrl: author?.avatar_url || ""
    }
  };
}

async function recordPostReads(postIds: string[], userId: string) {
  if (postIds.length === 0) return;
  const params: unknown[] = [];
  const values = postIds
    .map((postId) => {
      const start = params.length + 1;
      params.push(postId, userId);
      return `($${start}, $${start + 1}, NOW(), NOW())`;
    })
    .join(", ");

  await query(
    `INSERT INTO post_reads (post_id, user_id, first_read_at, last_read_at)
     VALUES ${values}
     ON CONFLICT (post_id, user_id)
     DO UPDATE SET last_read_at = EXCLUDED.last_read_at`,
    params
  );
}

function parseDateCursor(raw: unknown): Date | null {
  const value = String(raw || "").trim();
  if (!value) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

async function hydrateFeedPage(page: Awaited<ReturnType<typeof buildFeedPage>>, currentUserId: string) {
  return {
    items: await hydrateFeedPosts(page.items, currentUserId),
    nextCursor: page.nextCursor,
    sessionId: page.sessionId,
    metrics: page.metrics,
  };
}

async function hydrateFeedPosts(posts: any[], currentUserId: string) {
  if (posts.length === 0) {
    return [];
  }

  const postIds = posts.map((post) => post.post_id);
  const authorIds = [...new Set(posts.map((post) => post.author_id))];
  const authorSql = placeholders(authorIds.length);
  const postSql = placeholders(postIds.length, 2);
  const readPostSql = placeholders(postIds.length);

  await recordPostReads(postIds, currentUserId);

  const [authors, likes, follows, reads] = await Promise.all([
    queryMany(
      `SELECT user_id, username, display_name, avatar_url
       FROM users
       WHERE user_id IN (${authorSql})`,
      authorIds
    ),
    queryMany(`SELECT post_id FROM post_likes WHERE user_id = $1 AND post_id IN (${postSql})`, [currentUserId, ...postIds]),
    queryMany(
      `SELECT following_id
       FROM follows
       WHERE follower_id = $1
         AND following_id IN (${placeholders(authorIds.length, 2)})`,
      [currentUserId, ...authorIds]
    ),
    queryMany(
      `SELECT post_id, COUNT(*)::int AS read_count
       FROM post_reads
       WHERE post_id IN (${readPostSql})
       GROUP BY post_id`,
      postIds
    )
  ]);

  const authorMap = new Map(authors.map((a) => [a.user_id, a]));
  const likedSet = new Set(likes.map((l) => l.post_id));
  const followedSet = new Set(follows.map((f) => f.following_id));
  const readMap = new Map(reads.map((r) => [r.post_id, Number(r.read_count || 0)]));

  return posts.map((post) =>
    mapFeedPost(
      {
        ...post,
        read_count: readMap.get(post.post_id) || 0
      },
      authorMap.get(post.author_id),
      likedSet.has(post.post_id),
      followedSet.has(post.author_id)
    )
  );
}

async function hydrateFeedComments(comments: any[], currentUserId: string) {
  if (comments.length === 0) {
    return [];
  }

  const commentIds = comments.map((comment) => comment.comment_id);
  const authorIds = [...new Set(comments.map((comment) => comment.author_id))];

  const [authors, likes] = await Promise.all([
    queryMany(
      `SELECT user_id, username, display_name, avatar_url
       FROM users
       WHERE user_id IN (${placeholders(authorIds.length)})`,
      authorIds
    ),
    queryMany(
      `SELECT comment_id
       FROM comment_likes
       WHERE user_id = $1
         AND comment_id IN (${placeholders(commentIds.length, 2)})`,
      [currentUserId, ...commentIds]
    )
  ]);

  const authorMap = new Map(authors.map((author) => [author.user_id, author]));
  const likedSet = new Set(likes.map((like) => like.comment_id));

  return comments.map((comment) => mapFeedComment(comment, authorMap.get(comment.author_id), likedSet.has(comment.comment_id)));
}

async function writePostTags(postId: string, authorId: string, tags: string[], createdAt: Date) {
  if (tags.length === 0) return;

  await withTransaction(async (client) => {
    for (const tag of tags) {
      await client.query(
        `INSERT INTO post_tags (post_id, tag, author_id, created_at)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (post_id, tag) DO NOTHING`,
        [postId, tag, authorId, createdAt]
      );
      await client.query(
        `INSERT INTO tag_stats (tag, post_count, last_post_at, updated_at)
         VALUES ($1, 1, $2, $2)
         ON CONFLICT (tag) DO UPDATE
         SET post_count = tag_stats.post_count + 1,
             last_post_at = CASE
               WHEN tag_stats.last_post_at > EXCLUDED.last_post_at
                 THEN tag_stats.last_post_at
               ELSE EXCLUDED.last_post_at
             END,
             updated_at = EXCLUDED.updated_at`,
        [tag, createdAt]
      );
    }
  });
}

async function shouldCreateNotification(userId: string, categoryKey: string) {
  const row = await queryOne(`SELECT settings FROM user_settings WHERE user_id = $1`, [userId]);
  const settings = row?.settings || {};
  return settings.pushNotifications !== false && settings[categoryKey] !== false;
}

async function createNotification({ userId, actorUserId, type, title, body, data, categoryKey }: { userId: string; actorUserId: string; type: string; title: string; body: string; data: Record<string, unknown>; categoryKey: string }) {
  if (!userId || userId === actorUserId) return;
  try {
    if (!(await shouldCreateNotification(userId, categoryKey))) return;
    await enqueueNotificationEvent({
      eventType: type,
      recipientUserId: userId,
      actorUserId,
      entityType: String(data.entityType || (data.commentId ? "comment" : data.postId ? "post" : "system")),
      entityId: String(data.commentId || data.postId || data.followerId || ""),
      payload: {
        ...data,
        title,
        body,
      },
    });
  } catch {
    // Notification failures must not block likes, comments, shares, or posts.
  }
}

async function notifyMentionedUsers({ usernames, actorUserId, postId, commentId }: { usernames: string[]; actorUserId: string; postId: string; commentId?: string }) {
  const unique = [...new Set(usernames.map((item) => item.toLowerCase()))];
  if (unique.length === 0) return;
  const users = await queryMany(
    `SELECT user_id FROM users
     WHERE username_lower = ANY($1::text[]) AND deleted_at IS NULL`,
    [unique]
  );
  for (const user of users) {
    await createNotification({
      userId: user.user_id,
      actorUserId,
      type: commentId ? "COMMENT_MENTIONED" : "POST_MENTIONED",
      title: "New mention",
      body: commentId ? "Someone mentioned you in a comment" : "Someone mentioned you in a post",
      data: { postId, commentId: commentId || null },
      categoryKey: "notifyMentions"
    });
  }
}

async function findTaggedPosts(tag: string, currentUserId: string, before: Date | null, limit: number) {
  const params: unknown[] = [currentUserId, tag];
  let beforeSql = "";
  if (before) {
    params.push(before);
    beforeSql = `AND p.created_at < $${params.length}`;
  }
  params.push(limit);

  return queryMany(
    `SELECT p.*,
            (
              LEAST(p.like_count * 3 + p.comment_count * 4 + p.share_count * 5, 120)
              + CASE WHEN f.following_id IS NOT NULL THEN 16 ELSE 0 END
            ) AS rank_score
     FROM post_tags pt
     JOIN posts p ON p.post_id = pt.post_id
     LEFT JOIN follows f
       ON f.follower_id = $1 AND f.following_id = p.author_id
     WHERE pt.tag = $2
       ${beforeSql}
     ORDER BY p.created_at DESC, rank_score DESC
     LIMIT $${params.length}`,
    params
  );
}

export default async function feedService(app: any) {
  startFeedAggregationScheduler(app);

  app.get("/", { preHandler: requireAuth }, async (request: any) => {
    const q = request.query || {};
    const limit = parseLimit(q.limit, 20, 1, 50);
    const mode = normalizeFeedMode(q.mode);
    const tag = normalizeTag(q.tag);

    const before = parseDateCursor(q.before);

    if (tag) {
      const tagged = await findTaggedPosts(tag, request.user.userId, before, limit);
      return hydrateFeedPosts(tagged, request.user.userId);
    }

    const page = await buildFeedPage({
      viewerId: request.user.userId,
      mode,
      limit,
      before,
      sessionId: String(q.sessionId || "").trim(),
      lens: String(q.lens || "").trim(),
      topic: String(q.topic || "").trim(),
      customFeedId: String(q.feedId || "").trim(),
      scope: String(q.scope || "").trim(),
    });

    request.log?.info?.(page.metrics, "feed served");
    return hydrateFeedPosts(page.items, request.user.userId);
  });

  app.get("/for-you", { preHandler: requireAuth }, async (request: any) => {
    const q = request.query || {};
    const limit = parseLimit(q.limit, 20, 1, 50);
    const page = await buildFeedPage({
      viewerId: request.user.userId,
      mode: "for-you",
      limit,
      cursor: String(q.cursor || "").trim(),
      before: parseDateCursor(q.before),
      sessionId: String(q.sessionId || "").trim(),
      lens: String(q.lens || "").trim(),
    });

    request.log?.info?.(page.metrics, "for-you feed served");
    return hydrateFeedPage(page, request.user.userId);
  });

  app.get("/following", { preHandler: requireAuth }, async (request: any) => {
    const q = request.query || {};
    const limit = parseLimit(q.limit, 20, 1, 50);
    const page = await buildFeedPage({
      viewerId: request.user.userId,
      mode: "following",
      limit,
      cursor: String(q.cursor || "").trim(),
      before: parseDateCursor(q.before),
      sessionId: String(q.sessionId || "").trim(),
      lens: String(q.lens || "").trim(),
    });

    request.log?.info?.(page.metrics, "following feed served");
    return hydrateFeedPage(page, request.user.userId);
  });

  app.get("/friends", { preHandler: requireAuth }, async (request: any) => {
    const q = request.query || {};
    const page = await buildFeedPage({
      viewerId: request.user.userId,
      mode: "friends",
      limit: parseLimit(q.limit, 20, 1, 50),
      cursor: String(q.cursor || "").trim(),
      before: parseDateCursor(q.before),
      sessionId: String(q.sessionId || "").trim(),
      lens: String(q.lens || "friends_first").trim(),
    });
    return hydrateFeedPage(page, request.user.userId);
  });

  app.get("/latest", { preHandler: requireAuth }, async (request: any) => {
    const q = request.query || {};
    const page = await buildFeedPage({
      viewerId: request.user.userId,
      mode: "latest",
      limit: parseLimit(q.limit, 20, 1, 50),
      cursor: String(q.cursor || "").trim(),
      before: parseDateCursor(q.before),
      sessionId: String(q.sessionId || "").trim(),
      lens: String(q.lens || "latest").trim(),
      scope: String(q.scope || "network").trim(),
    });
    return hydrateFeedPage(page, request.user.userId);
  });

  app.get("/explore", { preHandler: requireAuth }, async (request: any) => {
    const q = request.query || {};
    const page = await buildFeedPage({
      viewerId: request.user.userId,
      mode: "explore",
      limit: parseLimit(q.limit, 20, 1, 50),
      cursor: String(q.cursor || "").trim(),
      before: parseDateCursor(q.before),
      sessionId: String(q.sessionId || "").trim(),
      lens: String(q.lens || "discover").trim(),
    });
    return hydrateFeedPage(page, request.user.userId);
  });

  app.get("/conversations", { preHandler: requireAuth }, async (request: any) => {
    const q = request.query || {};
    const page = await buildFeedPage({
      viewerId: request.user.userId,
      mode: "conversations",
      limit: parseLimit(q.limit, 20, 1, 50),
      cursor: String(q.cursor || "").trim(),
      before: parseDateCursor(q.before),
      sessionId: String(q.sessionId || "").trim(),
      lens: String(q.lens || "conversations").trim(),
    });
    return hydrateFeedPage(page, request.user.userId);
  });

  app.get("/catch-up", { preHandler: requireAuth }, async (request: any) => {
    const q = request.query || {};
    const page = await buildFeedPage({
      viewerId: request.user.userId,
      mode: "catch-up",
      limit: parseLimit(q.limit, 20, 1, 50),
      cursor: String(q.cursor || "").trim(),
      before: parseDateCursor(q.before),
      sessionId: String(q.sessionId || "").trim(),
      lens: String(q.lens || "balanced").trim(),
    });
    return hydrateFeedPage(page, request.user.userId);
  });

  app.get("/topic/:topic", { preHandler: requireAuth }, async (request: any) => {
    const q = request.query || {};
    const page = await buildFeedPage({
      viewerId: request.user.userId,
      mode: "topics",
      topic: String(request.params.topic || "").trim(),
      limit: parseLimit(q.limit, 20, 1, 50),
      cursor: String(q.cursor || "").trim(),
      before: parseDateCursor(q.before),
      sessionId: String(q.sessionId || "").trim(),
      lens: String(q.lens || "").trim(),
    });
    return hydrateFeedPage(page, request.user.userId);
  });

  app.get("/custom/:feedId", { preHandler: requireAuth }, async (request: any) => {
    const q = request.query || {};
    const page = await buildFeedPage({
      viewerId: request.user.userId,
      mode: "custom",
      customFeedId: String(request.params.feedId || "").trim(),
      limit: parseLimit(q.limit, 20, 1, 50),
      cursor: String(q.cursor || "").trim(),
      before: parseDateCursor(q.before),
      sessionId: String(q.sessionId || "").trim(),
      lens: String(q.lens || "").trim(),
    });
    return hydrateFeedPage(page, request.user.userId);
  });

  app.get("/tags", { preHandler: requireAuth }, async (request: any) => {
    const limit = parseLimit(request.query?.limit, 16, 1, 50);
    const rows = await queryMany(
      `SELECT tag,
              post_count,
              last_post_at,
              (post_count * 10) AS rank_score
       FROM tag_stats
       ORDER BY rank_score DESC, last_post_at DESC
       LIMIT $1`,
      [limit]
    );

    return rows.map((row) => ({
      tag: row.tag,
      postCount: Number(row.post_count || 0),
      rankScore: Number(row.rank_score || 0),
      lastPostAt: toIso(row.last_post_at)
    }));
  });

  app.get("/topics", { preHandler: requireAuth }, async (request: any) => {
    return listFeedTopics(request.user.userId, parseLimit(request.query?.limit, 40, 1, 100));
  });

  app.post("/topics/:topic/follow", { preHandler: requireAuth }, async (request: any) => {
    return followTopic(request.user.userId, String(request.params.topic || ""));
  });

  app.delete("/topics/:topic/follow", { preHandler: requireAuth }, async (request: any) => {
    return unfollowTopic(request.user.userId, String(request.params.topic || ""));
  });

  app.post("/topics/:topic/mute", { preHandler: requireAuth }, async (request: any) => {
    return muteTopic(request.user.userId, String(request.params.topic || ""));
  });

  app.delete("/topics/:topic/mute", { preHandler: requireAuth }, async (request: any) => {
    return unmuteTopic(request.user.userId, String(request.params.topic || ""));
  });

  app.post("/topics/:topic/snooze", { preHandler: requireAuth }, async (request: any) => {
    const days = Number(request.body?.days || 7);
    return muteTopic(request.user.userId, String(request.params.topic || ""), Number.isFinite(days) ? days : 7);
  });

  app.get("/preferences", { preHandler: requireAuth }, async (request: any) => {
    return { preferences: await getFeedPreferences(request.user.userId) };
  });

  app.patch("/preferences", { preHandler: requireAuth }, async (request: any) => {
    return { preferences: await updateFeedPreferences(request.user.userId, request.body || {}) };
  });

  app.post("/preferences/reset", { preHandler: requireAuth }, async (request: any) => {
    await updateFeedPreferences(request.user.userId, {});
    return resetFeedPersonalization(request.user.userId);
  });

  app.get("/preferences/export", { preHandler: requireAuth }, async (request: any) => {
    return exportFeedSettings(request.user.userId);
  });

  app.get("/interests", { preHandler: requireAuth }, async (request: any) => {
    return listInferredInterests(request.user.userId);
  });

  app.delete("/interests/:topic", { preHandler: requireAuth }, async (request: any) => {
    return removeInferredInterest(request.user.userId, String(request.params.topic || ""));
  });

  app.post("/history/clear", { preHandler: requireAuth }, async (request: any) => {
    return clearFeedServedHistory(request.user.userId);
  });

  app.get("/custom-feeds", { preHandler: requireAuth }, async (request: any) => {
    return listCustomFeeds(request.user.userId);
  });

  app.post("/custom-feeds", { preHandler: requireAuth }, async (request: any) => {
    return saveCustomFeed(request.user.userId, request.body || {});
  });

  app.patch("/custom-feeds/:feedId", { preHandler: requireAuth }, async (request: any) => {
    return saveCustomFeed(request.user.userId, request.body || {}, String(request.params.feedId || ""));
  });

  app.delete("/custom-feeds/:feedId", { preHandler: requireAuth }, async (request: any) => {
    return deleteCustomFeed(request.user.userId, String(request.params.feedId || ""));
  });

  app.post("/events", { preHandler: requireAuth }, async (request: any) => {
    const body = request.body || {};
    const events = Array.isArray(body.events) ? body.events : [body];
    return ingestFeedEvents(request.user.userId, events);
  });

  app.post("/aggregate", { preHandler: requireAuth }, async (request: any) => {
    if (process.env.NODE_ENV === "production") {
      throw new HttpError(404, "Route not found");
    }
    await runFeedAggregationJobs();
    request.log?.info?.("feed aggregation triggered manually");
    return { success: true };
  });

  app.post("/", { preHandler: requireAuth }, async (request: any) => {
    const body = normalizeBody(request.body?.body, MAX_POST_WORDS, MAX_POST_CHARS, "Post");

    const createdAt = now();
    const postId = generateId();
    const mentions = extractMatches(body, "@");
    const hashtags = extractHashtags(body);

    await query(
      `INSERT INTO posts (post_id, author_id, body, media_urls, mentions, hashtags, like_count, comment_count, share_count, share_of_post_id, created_at, updated_at)
       VALUES ($1, $2, $3, '[]', $4, $5, 0, 0, 0, NULL, $6, $7)`,
      [postId, request.user.userId, body, JSON.stringify(mentions), JSON.stringify(hashtags), createdAt, createdAt]
    );
    await writePostTags(postId, request.user.userId, hashtags, createdAt);
    await recordPostReads([postId], request.user.userId);

    const author = await queryOne(`SELECT user_id, username, display_name, avatar_url FROM users WHERE user_id = $1`, [request.user.userId]);

    const post = mapFeedPost(
      {
        post_id: postId,
        body,
        created_at: createdAt,
        like_count: 0,
        comment_count: 0,
        share_count: 0,
        read_count: 1,
        rank_score: 0,
        mentions,
        hashtags,
        author_id: request.user.userId
      },
      author,
      false,
      false
    );

    publishToFeedSubscribers("FEED_POST", post, request.user.userId);
    await recordFeedEvent(request.user.userId, { type: "post_open", postId });
    await notifyMentionedUsers({
      usernames: mentions,
      actorUserId: request.user.userId,
      postId
    });
    return post;
  });

  app.post("/:postId/not-interested", { preHandler: requireAuth }, async (request: any) => {
    const postId = String(request.params.postId || "").trim();
    ensure(postId.length >= 8, 400, "Invalid post");
    const post = await queryOne(`SELECT post_id FROM posts WHERE post_id = $1`, [postId]);
    if (!post) {
      throw new HttpError(404, "Post not found");
    }
    return markPostNotInterested(request.user.userId, postId, String(request.body?.reason || "not_interested"));
  });

  app.post("/:postId/hide", { preHandler: requireAuth }, async (request: any) => {
    const postId = String(request.params.postId || "").trim();
    ensure(postId.length >= 8, 400, "Invalid post");
    const post = await queryOne(`SELECT post_id FROM posts WHERE post_id = $1`, [postId]);
    if (!post) {
      throw new HttpError(404, "Post not found");
    }
    return markPostHidden(request.user.userId, postId, String(request.body?.reason || "hidden"));
  });

  app.post("/:postId/show-more", { preHandler: requireAuth }, async (request: any) => {
    const postId = String(request.params.postId || "").trim();
    ensure(postId.length >= 8, 400, "Invalid post");
    return recordFeedFeedback(request.user.userId, postId, "show_more", 1, request.body || {});
  });

  app.post("/:postId/show-fewer", { preHandler: requireAuth }, async (request: any) => {
    const postId = String(request.params.postId || "").trim();
    ensure(postId.length >= 8, 400, "Invalid post");
    return recordFeedFeedback(request.user.userId, postId, "show_fewer", -1, request.body || {});
  });

  app.get("/:postId/why", { preHandler: requireAuth }, async (request: any) => {
    const postId = String(request.params.postId || "").trim();
    ensure(postId.length >= 8, 400, "Invalid post");
    return explainPostRecommendation(request.user.userId, postId);
  });

  app.get("/:postId", { preHandler: requireAuth }, async (request: any) => {
    const postId = String(request.params.postId || "").trim();
    ensure(postId.length >= 8, 400, "Invalid post");

    const post = await queryOne(`SELECT * FROM posts WHERE post_id = $1`, [postId]);
    if (!post) {
      throw new HttpError(404, "Post not found");
    }

    const hydrated = await hydrateFeedPosts([post], request.user.userId);
    return hydrated[0] || null;
  });

  app.post("/:postId/like", { preHandler: requireAuth }, async (request: any) => {
    const postId = String(request.params.postId || "").trim();
    ensure(postId.length >= 8, 400, "Invalid post");

    const post = await queryOne(`SELECT post_id, author_id, like_count FROM posts WHERE post_id = $1`, [postId]);
    if (!post) {
      throw new HttpError(404, "Post not found");
    }

    const ts = now();
    let liked = false;
    await withTransaction(async (client) => {
      const current = await client.query(
        `SELECT COUNT(*)::int AS count
         FROM post_likes
         WHERE post_id = $1 AND user_id = $2`,
        [postId, request.user.userId]
      );
      const currentCount = Number(current.rows[0]?.count || 0);

      if (currentCount > 0) {
        await client.query(`DELETE FROM post_likes WHERE post_id = $1 AND user_id = $2`, [postId, request.user.userId]);
        liked = false;
      } else {
        await client.query(
          `INSERT INTO post_likes (post_id, user_id, created_at)
           VALUES ($1, $2, $3)
           ON CONFLICT DO NOTHING`,
          [postId, request.user.userId, ts]
        );
        liked = true;
      }

      await client.query(
        `UPDATE posts
         SET like_count = (
           SELECT COUNT(*)::int FROM post_likes WHERE post_id = $1
         ),
         updated_at = $2
         WHERE post_id = $1`,
        [postId, ts]
      );
    });

    const updated = await queryOne(`SELECT like_count FROM posts WHERE post_id = $1`, [postId]);
    const payload = {
      postId,
      userId: request.user.userId,
      liked,
      likeCount: Math.max(0, Number(updated?.like_count || 0))
    };
    if (liked) {
      await recordFeedEvent(request.user.userId, { type: "like", postId });
      await createNotification({
        userId: post.author_id,
        actorUserId: request.user.userId,
        type: "like",
        title: "New like",
        body: "Someone liked your post",
        data: { postId },
        categoryKey: "notifyPosts"
      });
    } else {
      await recordFeedEvent(request.user.userId, { type: "unlike", postId });
    }
    publishToFeedSubscribers("FEED_LIKE", payload);
    return payload;
  });

  app.get("/:postId/comments", { preHandler: requireAuth }, async (request: any) => {
    const postId = String(request.params.postId || "").trim();
    ensure(postId.length >= 8, 400, "Invalid post");

    const limit = parseLimit(request.query?.limit, 30, 1, 100);
    const comments = await queryMany(
      `SELECT *
       FROM comments
       WHERE post_id = $1
       ORDER BY created_at DESC
       LIMIT $2`,
      [postId, limit]
    );

    return hydrateFeedComments(comments, request.user.userId);
  });

  app.post("/:postId/comments", { preHandler: requireAuth }, async (request: any) => {
    const postId = String(request.params.postId || "").trim();
    ensure(postId.length >= 8, 400, "Invalid post");

    const body = normalizeBody(request.body?.body, MAX_COMMENT_WORDS, MAX_COMMENT_CHARS, "Comment");
    const mentions = extractMatches(body, "@");
    const parentCommentId = String(request.body?.parentCommentId || "").trim() || null;

    const post = await queryOne(`SELECT post_id, author_id FROM posts WHERE post_id = $1`, [postId]);
    if (!post) {
      throw new HttpError(404, "Post not found");
    }
    if (parentCommentId) {
      ensure(parentCommentId.length >= 8, 400, "Invalid comment");
      const parent = await queryOne(`SELECT comment_id FROM comments WHERE comment_id = $1 AND post_id = $2`, [parentCommentId, postId]);
      if (!parent) {
        throw new HttpError(404, "Comment not found");
      }
    }

    const createdAt = now();
    const commentId = generateId();

    await withTransaction(async (client) => {
      await client.query(
        `INSERT INTO comments (comment_id, post_id, parent_comment_id, author_id, body, like_count, reply_count, created_at)
         VALUES ($1, $2, $3, $4, $5, 0, 0, $6)`,
        [commentId, postId, parentCommentId, request.user.userId, body, createdAt]
      );
      await client.query(`UPDATE posts SET comment_count = comment_count + 1, updated_at = $2 WHERE post_id = $1`, [postId, createdAt]);
      if (parentCommentId) {
        await client.query(`UPDATE comments SET reply_count = reply_count + 1 WHERE comment_id = $1`, [parentCommentId]);
      }
    });

    const [author, postStats] = await Promise.all([queryOne(`SELECT user_id, username, display_name, avatar_url FROM users WHERE user_id = $1`, [request.user.userId]), queryOne(`SELECT comment_count FROM posts WHERE post_id = $1`, [postId])]);

    const payload = {
      postId,
      commentCount: Number(postStats?.comment_count || 0),
      comment: mapFeedComment(
        {
          comment_id: commentId,
          post_id: postId,
          parent_comment_id: parentCommentId,
          author_id: request.user.userId,
          body,
          like_count: 0,
          reply_count: 0,
          created_at: createdAt
        },
        author,
        false
      )
    };
    await recordFeedEvent(request.user.userId, { type: parentCommentId ? "reply" : "comment", postId, commentId });
    await createNotification({
      userId: post.author_id,
      actorUserId: request.user.userId,
      type: parentCommentId ? "reply" : "comment",
      title: parentCommentId ? "New reply" : "New comment",
      body: parentCommentId ? "Someone replied on your post" : "Someone commented on your post",
      data: { postId, commentId, parentCommentId },
      categoryKey: "notifyPosts"
    });
    await notifyMentionedUsers({
      usernames: mentions,
      actorUserId: request.user.userId,
      postId,
      commentId
    });
    publishToFeedSubscribers("FEED_COMMENT", {
      postId,
      commentCount: payload.commentCount
    });
    return payload;
  });

  app.post("/:postId/comments/:commentId/like", { preHandler: requireAuth }, async (request: any) => {
    const postId = String(request.params.postId || "").trim();
    const commentId = String(request.params.commentId || "").trim();
    ensure(postId.length >= 8, 400, "Invalid post");
    ensure(commentId.length >= 8, 400, "Invalid comment");

    const comment = await queryOne(`SELECT comment_id, like_count FROM comments WHERE comment_id = $1 AND post_id = $2`, [commentId, postId]);
    if (!comment) {
      throw new HttpError(404, "Comment not found");
    }

    const ts = now();
    let liked = false;
    await withTransaction(async (client) => {
      const current = await client.query(
        `SELECT COUNT(*)::int AS count
         FROM comment_likes
         WHERE comment_id = $1 AND user_id = $2`,
        [commentId, request.user.userId]
      );
      const currentCount = Number(current.rows[0]?.count || 0);

      if (currentCount > 0) {
        await client.query(`DELETE FROM comment_likes WHERE comment_id = $1 AND user_id = $2`, [commentId, request.user.userId]);
        liked = false;
      } else {
        await client.query(
          `INSERT INTO comment_likes (comment_id, user_id, created_at)
           VALUES ($1, $2, $3)
           ON CONFLICT DO NOTHING`,
          [commentId, request.user.userId, ts]
        );
        liked = true;
      }

      await client.query(
        `UPDATE comments
         SET like_count = (
           SELECT COUNT(*)::int FROM comment_likes WHERE comment_id = $1
         )
         WHERE comment_id = $1`,
        [commentId]
      );
    });

    const updated = await queryOne(`SELECT like_count FROM comments WHERE comment_id = $1`, [commentId]);
    await recordFeedEvent(request.user.userId, { type: liked ? "like" : "unlike", postId, commentId });

    return {
      postId,
      commentId,
      userId: request.user.userId,
      liked,
      likeCount: Math.max(0, Number(updated?.like_count || 0))
    };
  });

  app.post("/:postId/share", { preHandler: requireAuth }, async (request: any) => {
    const postId = String(request.params.postId || "").trim();
    ensure(postId.length >= 8, 400, "Invalid post");

    const original = await queryOne(`SELECT * FROM posts WHERE post_id = $1`, [postId]);
    if (!original) {
      throw new HttpError(404, "Post not found");
    }

    const existing = await queryOne(`SELECT post_id FROM posts WHERE author_id = $1 AND share_of_post_id = $2`, [request.user.userId, postId]);

    const ts = now();
    if (!existing) {
      const sharedPostId = generateId();
      const hashtags = Array.isArray(original.hashtags) ? original.hashtags : [];
      await query(
        `INSERT INTO posts (post_id, author_id, body, media_urls, mentions, hashtags, like_count, comment_count, share_count, created_at, updated_at, share_of_post_id)
         VALUES ($1, $2, $3, '[]', $4, $5, 0, 0, 0, $6, $7, $8)`,
        [sharedPostId, request.user.userId, original.body, JSON.stringify(Array.isArray(original.mentions) ? original.mentions : []), JSON.stringify(hashtags), ts, ts, postId]
      );
      await writePostTags(sharedPostId, request.user.userId, hashtags.map(normalizeTag), ts);
    }

    await query(`UPDATE posts SET share_count = share_count + 1, updated_at = $2 WHERE post_id = $1`, [postId, ts]);

    const updated = await queryOne(`SELECT share_count FROM posts WHERE post_id = $1`, [postId]);
    const payload = {
      postId,
      userId: request.user.userId,
      shared: true,
      shareCount: Number(updated?.share_count || 0),
      created: !existing
    };
    await recordFeedEvent(request.user.userId, { type: "share", postId });
    await createNotification({
      userId: original.author_id,
      actorUserId: request.user.userId,
      type: "share",
      title: "New share",
      body: "Someone shared your post",
      data: { postId },
      categoryKey: "notifyPosts"
    });
    publishToFeedSubscribers("FEED_SHARE", payload);
    return payload;
  });
}
