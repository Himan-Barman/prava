import { getDb } from "../../lib/mongo.js";
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
    id: post.postId,
    body: post.body,
    createdAt: toIso(post.createdAt),
    likeCount: Number(post.likeCount || 0),
    commentCount: Number(post.commentCount || 0),
    shareCount: Number(post.shareCount || 0),
    liked,
    followed,
    mentions: Array.isArray(post.mentions) ? post.mentions : [],
    hashtags: Array.isArray(post.hashtags) ? post.hashtags : [],
    relationship: followed ? "following" : "other",
    author: {
      id: author?.userId || post.authorId,
      username: author?.username || "unknown",
      displayName: author?.displayName || author?.username || "Unknown",
    },
  };
}

export default async function feedService(app) {
  const db = getDb();

  app.get("/", { preHandler: requireAuth }, async (request) => {
    const query = request.query || {};
    const limit = parseLimit(query.limit, 20, 1, 50);
    const mode = String(query.mode || "for-you");

    const filter: {
      createdAt?: { $lt: Date };
      authorId?: { $in: string[] };
    } = {};
    const before = String(query.before || "").trim();
    if (before) {
      const beforeDate = new Date(before);
      if (!Number.isNaN(beforeDate.getTime())) {
        filter.createdAt = { $lt: beforeDate };
      }
    }

    if (mode === "following") {
      const follows = await db.collection("follows").find(
        { followerId: request.user.userId },
        { projection: { followingId: 1 } }
      ).toArray();
      const followingIds = follows.map((item) => item.followingId);
      followingIds.push(request.user.userId);
      filter.authorId = { $in: [...new Set(followingIds)] };
    }

    const posts = await db.collection("posts").find(filter, {
      sort: { createdAt: -1 },
      limit,
    }).toArray();

    if (posts.length === 0) {
      return [];
    }

    const postIds = posts.map((post) => post.postId);
    const authorIds = [...new Set(posts.map((post) => post.authorId))];

    const [authors, likes, follows] = await Promise.all([
      db.collection("users").find(
        { userId: { $in: authorIds } },
        { projection: { userId: 1, username: 1, displayName: 1 } }
      ).toArray(),
      db.collection("post_likes").find(
        {
          userId: request.user.userId,
          postId: { $in: postIds },
        },
        {
          projection: { postId: 1 },
        }
      ).toArray(),
      db.collection("follows").find(
        {
          followerId: request.user.userId,
          followingId: { $in: authorIds },
        },
        {
          projection: { followingId: 1 },
        }
      ).toArray(),
    ]);

    const authorMap = new Map(authors.map((author) => [author.userId, author]));
    const likedSet = new Set(likes.map((like) => like.postId));
    const followedSet = new Set(follows.map((follow) => follow.followingId));

    return posts.map((post) =>
      mapFeedPost(
        post,
        authorMap.get(post.authorId),
        likedSet.has(post.postId),
        followedSet.has(post.authorId)
      )
    );
  });

  app.post("/", { preHandler: requireAuth }, async (request) => {
    const body = String(request.body?.body || "").trim();
    ensure(body.length > 0 && body.length <= 10000, 400, "Invalid body");

    const createdAt = now();
    const post = {
      postId: generateId(),
      authorId: request.user.userId,
      body,
      mentions: extractMatches(body, "@"),
      hashtags: extractMatches(body, "#"),
      likeCount: 0,
      commentCount: 0,
      shareCount: 0,
      createdAt,
      updatedAt: createdAt,
      shareOfPostId: null,
    };

    await db.collection("posts").insertOne(post);

    const author = await db.collection("users").findOne(
      { userId: request.user.userId },
      { projection: { userId: 1, username: 1, displayName: 1 } }
    );

    return mapFeedPost(post, author, false, false);
  });

  app.post("/:postId/like", { preHandler: requireAuth }, async (request) => {
    const postId = String(request.params.postId || "").trim();
    ensure(postId.length >= 8, 400, "Invalid post");

    const post = await db.collection("posts").findOne(
      { postId },
      { projection: { _id: 1, likeCount: 1 } }
    );
    if (!post) {
      throw new HttpError(404, "Post not found");
    }

    const existing = await db.collection("post_likes").findOne({
      postId,
      userId: request.user.userId,
    });

    let liked;
    if (existing) {
      await db.collection("post_likes").deleteOne({ _id: existing._id });
      await db.collection("posts").updateOne(
        { postId },
        { $inc: { likeCount: -1 }, $set: { updatedAt: now() } }
      );
      liked = false;
    } else {
      await db.collection("post_likes").insertOne({
        postId,
        userId: request.user.userId,
        createdAt: now(),
      });
      await db.collection("posts").updateOne(
        { postId },
        { $inc: { likeCount: 1 }, $set: { updatedAt: now() } }
      );
      liked = true;
    }

    const updated = await db.collection("posts").findOne(
      { postId },
      { projection: { likeCount: 1 } }
    );

    return {
      liked,
      likeCount: Math.max(0, Number(updated?.likeCount || 0)),
    };
  });

  app.get("/:postId/comments", { preHandler: requireAuth }, async (request) => {
    const postId = String(request.params.postId || "").trim();
    ensure(postId.length >= 8, 400, "Invalid post");

    const limit = parseLimit(request.query?.limit, 30, 1, 100);
    const comments = await db.collection("comments").find(
      { postId },
      {
        sort: { createdAt: -1 },
        limit,
      }
    ).toArray();

    if (comments.length === 0) {
      return [];
    }

    const authorIds = [...new Set(comments.map((item) => item.authorId))];
    const authors = await db.collection("users").find(
      { userId: { $in: authorIds } },
      { projection: { userId: 1, username: 1, displayName: 1 } }
    ).toArray();
    const authorMap = new Map(authors.map((author) => [author.userId, author]));

    return comments.map((comment) => {
      const author = authorMap.get(comment.authorId);
      return {
        id: comment.commentId,
        body: comment.body,
        createdAt: toIso(comment.createdAt),
        author: {
          id: author?.userId || comment.authorId,
          username: author?.username || "unknown",
          displayName: author?.displayName || author?.username || "Unknown",
        },
      };
    });
  });

  app.post("/:postId/comments", { preHandler: requireAuth }, async (request) => {
    const postId = String(request.params.postId || "").trim();
    ensure(postId.length >= 8, 400, "Invalid post");

    const body = String(request.body?.body || "").trim();
    ensure(body.length > 0 && body.length <= 5000, 400, "Invalid body");

    const post = await db.collection("posts").findOne(
      { postId },
      { projection: { postId: 1 } }
    );
    if (!post) {
      throw new HttpError(404, "Post not found");
    }

    const createdAt = now();
    const comment = {
      commentId: generateId(),
      postId,
      authorId: request.user.userId,
      body,
      createdAt,
    };

    await db.collection("comments").insertOne(comment);
    await db.collection("posts").updateOne(
      { postId },
      { $inc: { commentCount: 1 }, $set: { updatedAt: createdAt } }
    );

    const [author, postStats] = await Promise.all([
      db.collection("users").findOne(
        { userId: request.user.userId },
        { projection: { userId: 1, username: 1, displayName: 1 } }
      ),
      db.collection("posts").findOne(
        { postId },
        { projection: { commentCount: 1 } }
      ),
    ]);

    return {
      comment: {
        id: comment.commentId,
        body: comment.body,
        createdAt: toIso(comment.createdAt),
        author: {
          id: author?.userId || request.user.userId,
          username: author?.username || "unknown",
          displayName: author?.displayName || author?.username || "Unknown",
        },
      },
      commentCount: Number(postStats?.commentCount || 0),
    };
  });

  app.post("/:postId/share", { preHandler: requireAuth }, async (request) => {
    const postId = String(request.params.postId || "").trim();
    ensure(postId.length >= 8, 400, "Invalid post");

    const original = await db.collection("posts").findOne({ postId });
    if (!original) {
      throw new HttpError(404, "Post not found");
    }

    const existing = await db.collection("posts").findOne({
      authorId: request.user.userId,
      shareOfPostId: postId,
    });

    if (existing) {
      return {
        shared: true,
        shareCount: Number(original.shareCount || 0),
        created: false,
      };
    }

    const ts = now();
    await db.collection("posts").insertOne({
      postId: generateId(),
      authorId: request.user.userId,
      body: original.body,
      mentions: Array.isArray(original.mentions) ? original.mentions : [],
      hashtags: Array.isArray(original.hashtags) ? original.hashtags : [],
      likeCount: 0,
      commentCount: 0,
      shareCount: 0,
      createdAt: ts,
      updatedAt: ts,
      shareOfPostId: postId,
    });

    await db.collection("posts").updateOne(
      { postId },
      {
        $inc: { shareCount: 1 },
        $set: { updatedAt: ts },
      }
    );

    const updated = await db.collection("posts").findOne(
      { postId },
      { projection: { shareCount: 1 } }
    );

    return {
      shared: true,
      shareCount: Number(updated?.shareCount || 0),
      created: true,
    };
  });
}
