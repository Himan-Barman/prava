import { query, queryMany, queryOne } from "../../lib/pg.js";
import { requireAuth } from "../../lib/auth.js";
import {
  HttpError,
  ensure,
  generateId,
  now,
  toIso,
} from "../../lib/security.js";

function parseLimit(raw, fallback, min, max) {
  const parsed = Number.parseInt(String(raw || ""), 10);
  if (Number.isNaN(parsed)) {
    return fallback;
  }
  return Math.max(min, Math.min(max, parsed));
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function extractMatches(body, symbol) {
  const pattern = new RegExp(`(?:^|\\s)${escapeRegex(symbol)}([a-zA-Z0-9_]{2,32})`, "g");
  const out = new Set();
  for (const match of body.matchAll(pattern)) {
    out.add(String(match[1] || "").toLowerCase());
  }
  return [...out];
}

function mapFeedPost(post, author, liked, followed) {
  return {
    id: post.post_id,
    body: post.body,
    createdAt: toIso(post.created_at),
    likeCount: Number(post.like_count || 0),
    commentCount: Number(post.comment_count || 0),
    shareCount: Number(post.share_count || 0),
    liked,
    followed,
    mentions: Array.isArray(post.mentions) ? post.mentions : [],
    hashtags: Array.isArray(post.hashtags) ? post.hashtags : [],
    relationship: followed ? "following" : "other",
    author: {
      id: author?.user_id || post.author_id,
      username: author?.username || "unknown",
      displayName: author?.display_name || author?.username || "Unknown",
    },
  };
}

export default async function feedService(app) {
  app.get("/", { preHandler: requireAuth }, async (request) => {
    const q = request.query || {};
    const limit = parseLimit(q.limit, 20, 1, 50);
    const mode = String(q.mode || "for-you");

    const params: unknown[] = [request.user.userId];
    const conditions: string[] = [];
    let paramIdx = 2;

    const before = String(q.before || "").trim();
    if (before) {
      const beforeDate = new Date(before);
      if (!Number.isNaN(beforeDate.getTime())) {
        conditions.push(`p.created_at < $${paramIdx}`);
        params.push(beforeDate);
        paramIdx++;
      }
    }

    let fromClause = "FROM posts p";
    if (mode === "following") {
      fromClause = `FROM posts p
        WHERE p.author_id IN (
          SELECT following_id FROM follows WHERE follower_id = $1
          UNION ALL SELECT $1
        )`;
      if (conditions.length > 0) {
        fromClause += ` AND ${conditions.join(" AND ")}`;
      }
    } else {
      if (conditions.length > 0) {
        fromClause += ` WHERE ${conditions.join(" AND ")}`;
      }
    }

    const posts = await queryMany(
      `SELECT p.* ${fromClause} ORDER BY p.created_at DESC LIMIT $${paramIdx}`,
      [...params, limit]
    );

    if (posts.length === 0) {
      return [];
    }

    const postIds = posts.map((post) => post.post_id);
    const authorIds = [...new Set(posts.map((post) => post.author_id))];

    const [authors, likes, follows] = await Promise.all([
      queryMany(
        `SELECT user_id, username, display_name FROM users WHERE user_id = ANY($1)`,
        [authorIds]
      ),
      queryMany(
        `SELECT post_id FROM post_likes WHERE user_id = $1 AND post_id = ANY($2)`,
        [request.user.userId, postIds]
      ),
      queryMany(
        `SELECT following_id FROM follows WHERE follower_id = $1 AND following_id = ANY($2)`,
        [request.user.userId, authorIds]
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
  });

  app.post("/", { preHandler: requireAuth }, async (request) => {
    const body = String(request.body?.body || "").trim();
    ensure(body.length > 0 && body.length <= 10000, 400, "Invalid body");

    const createdAt = now();
    const postId = generateId();
    const mentions = extractMatches(body, "@");
    const hashtags = extractMatches(body, "#");

    await query(
      `INSERT INTO posts (post_id, author_id, body, media_urls, mentions, hashtags, like_count, comment_count, share_count, share_of_post_id, created_at, updated_at)
       VALUES ($1, $2, $3, '[]', $4, $5, 0, 0, 0, NULL, $6, $7)`,
      [postId, request.user.userId, body, JSON.stringify(mentions), JSON.stringify(hashtags), createdAt, createdAt]
    );

    const author = await queryOne(
      `SELECT user_id, username, display_name FROM users WHERE user_id = $1`,
      [request.user.userId]
    );

    return mapFeedPost(
      { post_id: postId, body, created_at: createdAt, like_count: 0, comment_count: 0, share_count: 0, mentions, hashtags, author_id: request.user.userId },
      author,
      false,
      false
    );
  });

  app.post("/:postId/like", { preHandler: requireAuth }, async (request) => {
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
    if (existing) {
      await query(`DELETE FROM post_likes WHERE post_id = $1 AND user_id = $2`, [postId, request.user.userId]);
      await query(`UPDATE posts SET like_count = GREATEST(like_count - 1, 0), updated_at = $2 WHERE post_id = $1`, [postId, now()]);
      liked = false;
    } else {
      await query(
        `INSERT INTO post_likes (post_id, user_id, created_at) VALUES ($1, $2, $3)`,
        [postId, request.user.userId, now()]
      );
      await query(`UPDATE posts SET like_count = like_count + 1, updated_at = $2 WHERE post_id = $1`, [postId, now()]);
      liked = true;
    }

    const updated = await queryOne(`SELECT like_count FROM posts WHERE post_id = $1`, [postId]);

    return {
      liked,
      likeCount: Math.max(0, Number(updated?.like_count || 0)),
    };
  });

  app.get("/:postId/comments", { preHandler: requireAuth }, async (request) => {
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
      `SELECT user_id, username, display_name FROM users WHERE user_id = ANY($1)`,
      [authorIds]
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
        },
      };
    });
  });

  app.post("/:postId/comments", { preHandler: requireAuth }, async (request) => {
    const postId = String(request.params.postId || "").trim();
    ensure(postId.length >= 8, 400, "Invalid post");

    const body = String(request.body?.body || "").trim();
    ensure(body.length > 0 && body.length <= 5000, 400, "Invalid body");

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
      queryOne(`SELECT user_id, username, display_name FROM users WHERE user_id = $1`, [request.user.userId]),
      queryOne(`SELECT comment_count FROM posts WHERE post_id = $1`, [postId]),
    ]);

    return {
      comment: {
        id: commentId,
        body,
        createdAt: toIso(createdAt),
        author: {
          id: author?.user_id || request.user.userId,
          username: author?.username || "unknown",
          displayName: author?.display_name || author?.username || "Unknown",
        },
      },
      commentCount: Number(postStats?.comment_count || 0),
    };
  });

  app.post("/:postId/share", { preHandler: requireAuth }, async (request) => {
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

    if (existing) {
      return {
        shared: true,
        shareCount: Number(original.share_count || 0),
        created: false,
      };
    }

    const ts = now();
    await query(
      `INSERT INTO posts (post_id, author_id, body, media_urls, mentions, hashtags, like_count, comment_count, share_count, created_at, updated_at, share_of_post_id)
       VALUES ($1, $2, $3, '[]', $4, $5, 0, 0, 0, $6, $7, $8)`,
      [
        generateId(),
        request.user.userId,
        original.body,
        JSON.stringify(Array.isArray(original.mentions) ? original.mentions : []),
        JSON.stringify(Array.isArray(original.hashtags) ? original.hashtags : []),
        ts,
        ts,
        postId,
      ]
    );

    await query(
      `UPDATE posts SET share_count = share_count + 1, updated_at = $2 WHERE post_id = $1`,
      [postId, ts]
    );

    const updated = await queryOne(`SELECT share_count FROM posts WHERE post_id = $1`, [postId]);

    return {
      shared: true,
      shareCount: Number(updated?.share_count || 0),
      created: true,
    };
  });
}
