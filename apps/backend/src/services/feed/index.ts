import { query, queryMany, queryOne, withTransaction } from "../../lib/pg.js";
import { requireAuth } from "../../lib/auth.js";
import {
  HttpError,
  ensure,
  generateId,
  now,
  toIso,
} from "../../lib/security.js";
import { publishToFeedSubscribers } from "../realtime/hub.js";

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
  const body = String(value || "").replace(/\s+\n/g, "\n").replace(/\n{3,}/g, "\n\n").trim();
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
  const pattern = new RegExp(`(?:^|\\s)${escapeRegex(symbol)}([a-zA-Z0-9_]{2,32})`, "g");
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
    rankScore: Number(post.rank_score || 0),
    liked,
    followed,
    mentions: Array.isArray(post.mentions) ? post.mentions : [],
    hashtags: Array.isArray(post.hashtags) ? post.hashtags : [],
    relationship: followed ? "following" : "other",
    author: {
      id: author?.user_id || post.author_id,
      username: author?.username || "unknown",
      displayName: author?.display_name || author?.username || "Unknown",
      avatarUrl: author?.avatar_url || "",
    },
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

  const [authors, likes, follows] = await Promise.all([
    queryMany(
      `SELECT user_id, username, display_name, avatar_url
       FROM users
       WHERE user_id IN (${authorSql})`,
      authorIds
    ),
    queryMany(
      `SELECT post_id FROM post_likes WHERE user_id = $1 AND post_id IN (${postSql})`,
      [currentUserId, ...postIds]
    ),
    queryMany(
      `SELECT following_id
       FROM follows
       WHERE follower_id = $1
         AND following_id IN (${placeholders(authorIds.length, 2)})`,
      [currentUserId, ...authorIds]
    ),
  ]);

  const authorMap = new Map(authors.map((a) => [a.user_id, a]));
  const likedSet = new Set(likes.map((l) => l.post_id));
  const followedSet = new Set(follows.map((f) => f.following_id));

  return posts.map((post) =>
    mapFeedPost(
      post,
      authorMap.get(post.author_id),
      likedSet.has(post.post_id),
      followedSet.has(post.author_id)
    )
  );
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
     ORDER BY rank_score DESC, p.created_at DESC
     LIMIT $${params.length}`,
    params
  );
}

export default async function feedService(app: any) {
  app.get("/", { preHandler: requireAuth }, async (request: any) => {
    const q = request.query || {};
    const limit = parseLimit(q.limit, 20, 1, 50);
    const mode = String(q.mode || "for-you");
    const tag = normalizeTag(q.tag);

    let before: Date | null = null;
    const beforeRaw = String(q.before || "").trim();
    if (beforeRaw) {
      const parsed = new Date(beforeRaw);
      if (!Number.isNaN(parsed.getTime())) before = parsed;
    }

    if (tag) {
      const tagged = await findTaggedPosts(tag, request.user.userId, before, limit);
      return hydrateFeedPosts(tagged, request.user.userId);
    }

    const params: unknown[] = [request.user.userId];
    let beforeSql = "";
    if (before) {
      params.push(before);
      beforeSql = `AND p.created_at < $${params.length}`;
    }
    params.push(limit);

    const followingFilter =
      mode === "following"
        ? "AND (p.author_id = $1 OR f.following_id IS NOT NULL)"
        : "";
    const orderBy =
      mode === "following"
        ? "p.created_at DESC"
        : "rank_score DESC, p.created_at DESC";

    const posts = await queryMany(
      `SELECT p.*,
              (
                CASE
                  WHEN p.author_id = $1 THEN 6
                  WHEN f.following_id IS NOT NULL THEN 22
                  ELSE 0
                END
                + LEAST(p.like_count * 3 + p.comment_count * 4 + p.share_count * 5, 120)
                + COALESCE((
                    SELECT LEAST(SUM(ts.post_count), 80)
                    FROM post_tags pt
                    JOIN tag_stats ts ON ts.tag = pt.tag
                    WHERE pt.post_id = p.post_id
                  ), 0)
              ) AS rank_score
       FROM posts p
       LEFT JOIN follows f
         ON f.follower_id = $1 AND f.following_id = p.author_id
       WHERE p.body <> ''
         ${beforeSql}
         ${followingFilter}
       ORDER BY ${orderBy}
       LIMIT $${params.length}`,
      params
    );

    return hydrateFeedPosts(posts, request.user.userId);
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
      lastPostAt: toIso(row.last_post_at),
    }));
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
      [
        postId,
        request.user.userId,
        body,
        JSON.stringify(mentions),
        JSON.stringify(hashtags),
        createdAt,
        createdAt,
      ]
    );
    await writePostTags(postId, request.user.userId, hashtags, createdAt);

    const author = await queryOne(
      `SELECT user_id, username, display_name, avatar_url FROM users WHERE user_id = $1`,
      [request.user.userId]
    );

    const post = mapFeedPost(
      {
        post_id: postId,
        body,
        created_at: createdAt,
        like_count: 0,
        comment_count: 0,
        share_count: 0,
        rank_score: 0,
        mentions,
        hashtags,
        author_id: request.user.userId,
      },
      author,
      false,
      false
    );

    publishToFeedSubscribers("FEED_POST", post, request.user.userId);
    return post;
  });

  app.post("/:postId/like", { preHandler: requireAuth }, async (request: any) => {
    const postId = String(request.params.postId || "").trim();
    ensure(postId.length >= 8, 400, "Invalid post");

    const post = await queryOne(`SELECT post_id, like_count FROM posts WHERE post_id = $1`, [postId]);
    if (!post) {
      throw new HttpError(404, "Post not found");
    }

    const existing = await queryOne(
      `SELECT post_id FROM post_likes WHERE post_id = $1 AND user_id = $2`,
      [postId, request.user.userId]
    );

    let liked;
    const ts = now();
    if (existing) {
      await query(`DELETE FROM post_likes WHERE post_id = $1 AND user_id = $2`, [postId, request.user.userId]);
      await query(`UPDATE posts SET like_count = GREATEST(like_count - 1, 0), updated_at = $2 WHERE post_id = $1`, [postId, ts]);
      liked = false;
    } else {
      await query(
        `INSERT INTO post_likes (post_id, user_id, created_at) VALUES ($1, $2, $3)`,
        [postId, request.user.userId, ts]
      );
      await query(`UPDATE posts SET like_count = like_count + 1, updated_at = $2 WHERE post_id = $1`, [postId, ts]);
      liked = true;
    }

    const updated = await queryOne(`SELECT like_count FROM posts WHERE post_id = $1`, [postId]);
    const payload = {
      postId,
      userId: request.user.userId,
      liked,
      likeCount: Math.max(0, Number(updated?.like_count || 0)),
    };
    publishToFeedSubscribers("FEED_LIKE", payload);
    return payload;
  });

  app.get("/:postId/comments", { preHandler: requireAuth }, async (request: any) => {
    const postId = String(request.params.postId || "").trim();
    ensure(postId.length >= 8, 400, "Invalid post");

    const limit = parseLimit(request.query?.limit, 30, 1, 100);
    const comments = await queryMany(
      `SELECT * FROM comments WHERE post_id = $1 ORDER BY created_at DESC LIMIT $2`,
      [postId, limit]
    );

    if (comments.length === 0) {
      return [];
    }

    const authorIds = [...new Set(comments.map((item) => item.author_id))];
    const authors = await queryMany(
      `SELECT user_id, username, display_name, avatar_url
       FROM users
       WHERE user_id IN (${placeholders(authorIds.length)})`,
      authorIds
    );
    const authorMap = new Map(authors.map((a) => [a.user_id, a]));

    return comments.map((comment) => {
      const author = authorMap.get(comment.author_id);
      return {
        id: comment.comment_id,
        body: comment.body,
        createdAt: toIso(comment.created_at),
        author: {
          id: author?.user_id || comment.author_id,
          username: author?.username || "unknown",
          displayName: author?.display_name || author?.username || "Unknown",
          avatarUrl: author?.avatar_url || "",
        },
      };
    });
  });

  app.post("/:postId/comments", { preHandler: requireAuth }, async (request: any) => {
    const postId = String(request.params.postId || "").trim();
    ensure(postId.length >= 8, 400, "Invalid post");

    const body = normalizeBody(request.body?.body, MAX_COMMENT_WORDS, MAX_COMMENT_CHARS, "Comment");

    const post = await queryOne(`SELECT post_id FROM posts WHERE post_id = $1`, [postId]);
    if (!post) {
      throw new HttpError(404, "Post not found");
    }

    const createdAt = now();
    const commentId = generateId();

    await query(
      `INSERT INTO comments (comment_id, post_id, author_id, body, created_at)
       VALUES ($1, $2, $3, $4, $5)`,
      [commentId, postId, request.user.userId, body, createdAt]
    );
    await query(`UPDATE posts SET comment_count = comment_count + 1, updated_at = $2 WHERE post_id = $1`, [postId, createdAt]);

    const [author, postStats] = await Promise.all([
      queryOne(`SELECT user_id, username, display_name, avatar_url FROM users WHERE user_id = $1`, [request.user.userId]),
      queryOne(`SELECT comment_count FROM posts WHERE post_id = $1`, [postId]),
    ]);

    const payload = {
      postId,
      commentCount: Number(postStats?.comment_count || 0),
      comment: {
        id: commentId,
        body,
        createdAt: toIso(createdAt),
        author: {
          id: author?.user_id || request.user.userId,
          username: author?.username || "unknown",
          displayName: author?.display_name || author?.username || "Unknown",
          avatarUrl: author?.avatar_url || "",
        },
      },
    };
    publishToFeedSubscribers("FEED_COMMENT", {
      postId,
      commentCount: payload.commentCount,
    });
    return payload;
  });

  app.post("/:postId/share", { preHandler: requireAuth }, async (request: any) => {
    const postId = String(request.params.postId || "").trim();
    ensure(postId.length >= 8, 400, "Invalid post");

    const original = await queryOne(`SELECT * FROM posts WHERE post_id = $1`, [postId]);
    if (!original) {
      throw new HttpError(404, "Post not found");
    }

    const existing = await queryOne(
      `SELECT post_id FROM posts WHERE author_id = $1 AND share_of_post_id = $2`,
      [request.user.userId, postId]
    );

    const ts = now();
    if (!existing) {
      const sharedPostId = generateId();
      const hashtags = Array.isArray(original.hashtags) ? original.hashtags : [];
      await query(
        `INSERT INTO posts (post_id, author_id, body, media_urls, mentions, hashtags, like_count, comment_count, share_count, created_at, updated_at, share_of_post_id)
         VALUES ($1, $2, $3, '[]', $4, $5, 0, 0, 0, $6, $7, $8)`,
        [
          sharedPostId,
          request.user.userId,
          original.body,
          JSON.stringify(Array.isArray(original.mentions) ? original.mentions : []),
          JSON.stringify(hashtags),
          ts,
          ts,
          postId,
        ]
      );
      await writePostTags(sharedPostId, request.user.userId, hashtags.map(normalizeTag), ts);
    }

    await query(
      `UPDATE posts SET share_count = share_count + 1, updated_at = $2 WHERE post_id = $1`,
      [postId, ts]
    );

    const updated = await queryOne(`SELECT share_count FROM posts WHERE post_id = $1`, [postId]);
    const payload = {
      postId,
      userId: request.user.userId,
      shared: true,
      shareCount: Number(updated?.share_count || 0),
      created: !existing,
    };
    publishToFeedSubscribers("FEED_SHARE", payload);
    return payload;
  });
}
