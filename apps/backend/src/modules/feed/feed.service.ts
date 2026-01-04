import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { and, eq, inArray, sql } from 'drizzle-orm';

import { db } from '@/db';
import { feedPosts } from '@/db/schema/feed_posts.schema';
import { feedLikes } from '@/db/schema/feed_likes.schema';
import { feedComments } from '@/db/schema/feed_comments.schema';
import { feedShares } from '@/db/schema/feed_shares.schema';
import { users } from '@/db/schema/users.schema';
import { follows } from '@/db/schema/follows.schema';
import { publishFeedEvent } from './feed.realtime';
import { NotificationsService } from '@/modules/notifications/notifications.service';

const MAX_FEED_LIMIT = 50;

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

  async createPost(input: { userId: string; body: string }) {
    const body = input.body.trim();
    if (!body) {
      throw new BadRequestException('Post body required');
    }

    const mentions = this.extractMentions(body);
    const hashtags = this.extractHashtags(body);
    const metadata = { mentions, hashtags };

    const author = await db
      .select({
        id: users.id,
        username: users.username,
        displayName: users.displayName,
      })
      .from(users)
      .where(eq(users.id, input.userId))
      .limit(1);

    if (!author[0]) {
      throw new NotFoundException('Author not found');
    }

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

    void publishFeedEvent(payload);
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
        u.id AS "authorId",
        u.username AS "authorUsername",
        u.display_name AS "authorDisplayName",
        (fl.user_id IS NOT NULL) AS "liked",
        (f.follower_id IS NOT NULL) AS "followed"
      FROM feed_posts p
      JOIN users u ON u.id = p.author_id
      LEFT JOIN feed_likes fl
        ON fl.post_id = p.id
       AND fl.user_id = ${input.userId}
      LEFT JOIN follows f
        ON f.follower_id = ${input.userId}
       AND f.following_id = p.author_id
      WHERE 1=1
      ${beforeCondition}
      ORDER BY p.created_at DESC
      LIMIT ${limit}
    `);

    return rows.rows.map((row) => ({
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
      author: {
        id: row.authorId,
        username: row.authorUsername,
        displayName: row.authorDisplayName ?? row.authorUsername,
      },
    }));
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

    return {
      comment: payload,
      commentCount: result.commentCount,
    };
  }

  async listComments(input: {
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

        return { shared: true, shareCount: post?.shareCount ?? 0 };
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

      return { shared: true, shareCount: post?.shareCount ?? 0 };
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
