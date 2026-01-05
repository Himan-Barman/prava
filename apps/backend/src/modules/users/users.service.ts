import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { and, desc, eq, or, sql } from 'drizzle-orm';

import { db } from '@/db';
import { users } from '@/db/schema/users.schema';
import { follows } from '@/db/schema/follows.schema';
import { userSettings } from '@/db/schema/user_settings.schema';
import { userBlocks } from '@/db/schema/user_blocks.schema';
import { userMutedWords } from '@/db/schema/user_muted_words.schema';
import { userDataExports } from '@/db/schema/user_data_exports.schema';
import { feedPosts } from '@/db/schema/feed_posts.schema';
import { presenceManager } from '@/realtime/presence.manager';
import { UpdateUserSettingsDto } from './dto/user-settings.dto';
import { UserDetailsDto } from './dto/user-details.dto';
import { NotificationsService } from '@/modules/notifications/notifications.service';
import { AuthService } from '@/modules/auth/auth.service';

const MAX_PROFILE_LIMIT = 30;
const DEFAULT_SETTINGS = {
  privateAccount: false,
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
  textScale: 1.0,
  languageLabel: 'English',
};

@Injectable()
export class UsersService {
  constructor(
    private readonly notifications: NotificationsService,
    private readonly auth: AuthService,
  ) {}
  async searchUsers(input: {
    userId: string;
    query: string;
    limit?: number;
  }) {
    const normalized = input.query.trim().toLowerCase().replace(/^@+/, '');
    if (normalized.length < 2) {
      return { results: [] };
    }

    if (!/^[a-z0-9_.]+$/.test(normalized)) {
      return { results: [] };
    }

    const limit = Math.min(Math.max(input.limit ?? 20, 1), 25);

    const rows = await db.execute(sql`
      SELECT
        u.id,
        u.username,
        u.display_name AS "displayName",
        u.is_verified AS "isVerified",
        (f1.follower_id IS NOT NULL) AS "isFollowing",
        (f2.follower_id IS NOT NULL) AS "isFollowedBy"
      FROM users u
      LEFT JOIN follows f1
        ON f1.follower_id = ${input.userId}
       AND f1.following_id = u.id
      LEFT JOIN follows f2
        ON f2.follower_id = u.id
       AND f2.following_id = ${input.userId}
      LEFT JOIN user_blocks b1
        ON b1.blocker_id = ${input.userId}
       AND b1.blocked_id = u.id
      LEFT JOIN user_blocks b2
        ON b2.blocker_id = u.id
       AND b2.blocked_id = ${input.userId}
      WHERE u.id != ${input.userId}
        AND b1.blocker_id IS NULL
        AND b2.blocker_id IS NULL
        AND (
          u.username ILIKE ${`${normalized}%`}
          OR u.display_name ILIKE ${`${normalized}%`}
        )
      ORDER BY u.username ASC
      LIMIT ${limit}
    `);

    return {
      results: rows.rows.map((row) => ({
        id: row.id,
        username: row.username,
        displayName: row.displayName ?? row.username,
        isVerified: row.isVerified === true,
        isFollowing: row.isFollowing === true,
        isFollowedBy: row.isFollowedBy === true,
      })),
    };
  }

  async isUsernameAvailable(username: string) {
    const normalized = username.trim().toLowerCase();
    if (!/^[a-z0-9_]{3,32}$/.test(normalized)) {
      throw new BadRequestException('Invalid username');
    }

    const existing = await db
      .select({ id: users.id })
      .from(users)
      .where(eq(users.username, normalized))
      .limit(1);

    return existing.length === 0;
  }

  async toggleFollow(input: {
    followerId: string;
    followingId: string;
  }) {
    if (input.followerId === input.followingId) {
      throw new BadRequestException('Cannot follow self');
    }

    await this.ensureNotBlocked(
      input.followerId,
      input.followingId,
    );

    const target = await db
      .select({ id: users.id })
      .from(users)
      .where(eq(users.id, input.followingId))
      .limit(1);

    if (!target[0]) {
      throw new NotFoundException('User not found');
    }

    const existing = await db
      .select()
      .from(follows)
      .where(
        and(
          eq(follows.followerId, input.followerId),
          eq(follows.followingId, input.followingId),
        ),
      )
      .limit(1);

    if (existing[0]) {
      await db
        .delete(follows)
        .where(
          and(
            eq(follows.followerId, input.followerId),
            eq(follows.followingId, input.followingId),
          ),
        );

      return { following: false };
    }

    await db.insert(follows).values({
      followerId: input.followerId,
      followingId: input.followingId,
    });

    void this.notifyFollow(input.followerId, input.followingId).catch(
      () => {},
    );

    return { following: true };
  }

  async setFollow(input: {
    followerId: string;
    followingId: string;
    follow: boolean;
  }) {
    if (input.followerId === input.followingId) {
      throw new BadRequestException('Cannot follow self');
    }

    await this.ensureNotBlocked(
      input.followerId,
      input.followingId,
    );

    const target = await db
      .select({ id: users.id })
      .from(users)
      .where(eq(users.id, input.followingId))
      .limit(1);

    if (!target[0]) {
      throw new NotFoundException('User not found');
    }

    const existing = await db
      .select()
      .from(follows)
      .where(
        and(
          eq(follows.followerId, input.followerId),
          eq(follows.followingId, input.followingId),
        ),
      )
      .limit(1);

    if (input.follow) {
      if (existing[0]) {
        return { following: true, changed: false };
      }

      await db.insert(follows).values({
        followerId: input.followerId,
        followingId: input.followingId,
      });

      void this.notifyFollow(
        input.followerId,
        input.followingId,
      ).catch(() => {});

      return { following: true, changed: true };
    }

    if (!existing[0]) {
      return { following: false, changed: false };
    }

    await db
      .delete(follows)
      .where(
        and(
          eq(follows.followerId, input.followerId),
          eq(follows.followingId, input.followingId),
        ),
      );

    return { following: false, changed: true };
  }

  async removeFollower(input: { userId: string; followerId: string }) {
    if (input.userId === input.followerId) {
      throw new BadRequestException('Cannot remove self');
    }

    const removed = await db
      .delete(follows)
      .where(
        and(
          eq(follows.followerId, input.followerId),
          eq(follows.followingId, input.userId),
        ),
      )
      .returning({ followerId: follows.followerId });

    return { removed: removed.length > 0 };
  }

  async removeConnection(input: { userId: string; targetUserId: string }) {
    if (input.userId === input.targetUserId) {
      throw new BadRequestException('Cannot remove self');
    }

    const removed = await db
      .delete(follows)
      .where(
        or(
          and(
            eq(follows.followerId, input.userId),
            eq(follows.followingId, input.targetUserId),
          ),
          and(
            eq(follows.followerId, input.targetUserId),
            eq(follows.followingId, input.userId),
          ),
        ),
      )
      .returning({ followerId: follows.followerId });

    return { removed: removed.length > 0 };
  }

  async getConnections(input: { userId: string; limit?: number }) {
    const limit = Math.min(Math.max(input.limit ?? 20, 1), 50);

    const requestsRows = await db.execute(sql`
      SELECT
        u.id,
        u.username,
        u.display_name AS "displayName",
        u.bio,
        u.location,
        u.is_verified AS "isVerified",
        u.created_at AS "createdAt",
        f.created_at AS "since"
      FROM follows f
      JOIN users u
        ON u.id = f.follower_id
      LEFT JOIN follows f2
        ON f2.follower_id = ${input.userId}
       AND f2.following_id = f.follower_id
      WHERE f.following_id = ${input.userId}
        AND f2.follower_id IS NULL
      ORDER BY f.created_at DESC
      LIMIT ${limit}
    `);

    const sentRows = await db.execute(sql`
      SELECT
        u.id,
        u.username,
        u.display_name AS "displayName",
        u.bio,
        u.location,
        u.is_verified AS "isVerified",
        u.created_at AS "createdAt",
        f.created_at AS "since"
      FROM follows f
      JOIN users u
        ON u.id = f.following_id
      LEFT JOIN follows f2
        ON f2.follower_id = u.id
       AND f2.following_id = ${input.userId}
      WHERE f.follower_id = ${input.userId}
        AND f2.follower_id IS NULL
      ORDER BY f.created_at DESC
      LIMIT ${limit}
    `);

    const friendsRows = await db.execute(sql`
      SELECT
        u.id,
        u.username,
        u.display_name AS "displayName",
        u.bio,
        u.location,
        u.is_verified AS "isVerified",
        u.created_at AS "createdAt",
        GREATEST(f.created_at, f2.created_at) AS "since"
      FROM follows f
      JOIN users u
        ON u.id = f.following_id
      JOIN follows f2
        ON f2.follower_id = u.id
       AND f2.following_id = ${input.userId}
      WHERE f.follower_id = ${input.userId}
      ORDER BY GREATEST(f.created_at, f2.created_at) DESC
      LIMIT ${limit}
    `);

    const mapRows = async (
      rows: typeof requestsRows.rows,
      relationship: { isFollowing: boolean; isFollowedBy: boolean },
    ) => {
      const items = rows.map((row) => ({
        id: row.id,
        username: row.username,
        displayName: row.displayName ?? row.username,
        bio: row.bio ?? '',
        location: row.location ?? '',
        isVerified: row.isVerified === true,
        createdAt: row.createdAt,
        since: row.since,
        isFollowing: relationship.isFollowing,
        isFollowedBy: relationship.isFollowedBy,
      }));

      if (items.length == 0) return items;

      const statuses = await Promise.all(
        items.map((item) => presenceManager.isOnline(String(item.id))),
      );

      return items.map((item, index) => ({
        ...item,
        isOnline: statuses[index],
      }));
    };

    const requests = await mapRows(requestsRows.rows, {
      isFollowing: false,
      isFollowedBy: true,
    });
    const sent = await mapRows(sentRows.rows, {
      isFollowing: true,
      isFollowedBy: false,
    });
    const friends = await mapRows(friendsRows.rows, {
      isFollowing: true,
      isFollowedBy: true,
    });

    return {
      requests,
      sent,
      friends,
    };
  }

  async getProfileSummary(input: { userId: string; limit?: number }) {
    const limit = Math.min(
      Math.max(input.limit ?? 12, 1),
      MAX_PROFILE_LIMIT,
    );

    const [user] = await db
      .select({
        id: users.id,
        username: users.username,
        displayName: users.displayName,
        bio: users.bio,
        location: users.location,
        website: users.website,
        isVerified: users.isVerified,
        createdAt: users.createdAt,
      })
      .from(users)
      .where(eq(users.id, input.userId))
      .limit(1);

    if (!user) {
      throw new NotFoundException('User not found');
    }

    const statsRows = await db.execute(sql`
      SELECT
        (SELECT COUNT(*)::int FROM feed_posts WHERE author_id = ${input.userId}) AS "posts",
        (SELECT COUNT(*)::int FROM follows WHERE following_id = ${input.userId}) AS "followers",
        (SELECT COUNT(*)::int FROM follows WHERE follower_id = ${input.userId}) AS "following",
        (SELECT COALESCE(SUM(like_count), 0)::int FROM feed_posts WHERE author_id = ${input.userId}) AS "likes"
    `);

    const stats = statsRows.rows[0] ?? {};

    const postsRows = await db.execute(sql`
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
      WHERE p.author_id = ${input.userId}
      ORDER BY p.created_at DESC
      LIMIT ${limit}
    `);

    const likedRows = await db.execute(sql`
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
        true AS "liked",
        (f.follower_id IS NOT NULL) AS "followed"
      FROM feed_posts p
      JOIN users u ON u.id = p.author_id
      JOIN feed_likes fl
        ON fl.post_id = p.id
       AND fl.user_id = ${input.userId}
      LEFT JOIN follows f
        ON f.follower_id = ${input.userId}
       AND f.following_id = p.author_id
      ORDER BY fl.created_at DESC
      LIMIT ${limit}
    `);

    const mapRows = (rows: typeof postsRows.rows) =>
      rows.map((row) => ({
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

    return {
      user: {
        id: user.id,
        username: user.username,
        displayName: user.displayName ?? user.username,
        bio: user.bio,
        location: user.location,
        website: user.website,
        isVerified: user.isVerified,
        createdAt: user.createdAt,
      },
      stats: {
        posts: Number(stats.posts ?? 0),
        followers: Number(stats.followers ?? 0),
        following: Number(stats.following ?? 0),
        likes: Number(stats.likes ?? 0),
      },
      posts: mapRows(postsRows.rows),
      liked: mapRows(likedRows.rows),
    };
  }

  async getPublicProfileSummary(input: {
    targetUserId: string;
    viewerId: string;
    limit?: number;
  }) {
    await this.ensureNotBlocked(input.viewerId, input.targetUserId);

    const limit = Math.min(
      Math.max(input.limit ?? 12, 1),
      MAX_PROFILE_LIMIT,
    );

    const [user] = await db
      .select({
        id: users.id,
        username: users.username,
        displayName: users.displayName,
        bio: users.bio,
        location: users.location,
        website: users.website,
        isVerified: users.isVerified,
        createdAt: users.createdAt,
      })
      .from(users)
      .where(eq(users.id, input.targetUserId))
      .limit(1);

    if (!user) {
      throw new NotFoundException('User not found');
    }

    const relationshipRows = await db.execute(sql`
      SELECT
        EXISTS(
          SELECT 1
          FROM follows
          WHERE follower_id = ${input.viewerId}
            AND following_id = ${input.targetUserId}
        ) AS "isFollowing",
        EXISTS(
          SELECT 1
          FROM follows
          WHERE follower_id = ${input.targetUserId}
            AND following_id = ${input.viewerId}
        ) AS "isFollowedBy"
    `);

    const relationship = relationshipRows.rows[0] ?? {};

    const statsRows = await db.execute(sql`
      SELECT
        (SELECT COUNT(*)::int FROM feed_posts WHERE author_id = ${input.targetUserId}) AS "posts",
        (SELECT COUNT(*)::int FROM follows WHERE following_id = ${input.targetUserId}) AS "followers",
        (SELECT COUNT(*)::int FROM follows WHERE follower_id = ${input.targetUserId}) AS "following",
        (SELECT COALESCE(SUM(like_count), 0)::int FROM feed_posts WHERE author_id = ${input.targetUserId}) AS "likes"
    `);

    const stats = statsRows.rows[0] ?? {};

    const postsRows = await db.execute(sql`
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
       AND fl.user_id = ${input.viewerId}
      LEFT JOIN follows f
        ON f.follower_id = ${input.viewerId}
       AND f.following_id = p.author_id
      WHERE p.author_id = ${input.targetUserId}
      ORDER BY p.created_at DESC
      LIMIT ${limit}
    `);

    const mapRows = (rows: typeof postsRows.rows) =>
      rows.map((row) => ({
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

    return {
      user: {
        id: user.id,
        username: user.username,
        displayName: user.displayName ?? user.username,
        bio: user.bio,
        location: user.location,
        website: user.website,
        isVerified: user.isVerified,
        createdAt: user.createdAt,
      },
      stats: {
        posts: Number(stats.posts ?? 0),
        followers: Number(stats.followers ?? 0),
        following: Number(stats.following ?? 0),
        likes: Number(stats.likes ?? 0),
      },
      relationship: {
        isFollowing: relationship.isFollowing === true,
        isFollowedBy: relationship.isFollowedBy === true,
      },
      posts: mapRows(postsRows.rows),
    };
  }

  async updateDetails(userId: string, input: UserDetailsDto) {
    const firstName = this.normalizeName(input.firstName);
    const lastName = this.normalizeName(input.lastName);

    if (!firstName || !lastName) {
      throw new BadRequestException('Invalid name');
    }

    const phone = this.normalizePhone(
      input.phoneCountryCode,
      input.phoneNumber,
    );

    if (!phone) {
      throw new BadRequestException('Invalid phone number');
    }

    const displayName = `${firstName} ${lastName}`.trim();
    const now = new Date();

    const [row] = await db
      .update(users)
      .set({
        firstName,
        lastName,
        phoneCountry: phone.countryCode,
        phoneNumber: phone.phoneNumber,
        displayName,
        updatedAt: now,
      })
      .where(eq(users.id, userId))
      .returning({ id: users.id });

    if (!row) {
      throw new NotFoundException('User not found');
    }

    return {
      success: true,
      profile: {
        firstName,
        lastName,
        displayName,
        phoneCountryCode: phone.countryCode,
        phoneNumber: phone.phoneNumber,
      },
    };
  }

  async getSettings(userId: string) {
    const [record] = await db
      .select({
        settings: userSettings.settings,
        updatedAt: userSettings.updatedAt,
      })
      .from(userSettings)
      .where(eq(userSettings.userId, userId))
      .limit(1);

    const settings = {
      ...DEFAULT_SETTINGS,
      ...((record?.settings as Record<string, unknown> | undefined) ??
          {}),
    };

    return {
      settings,
      updatedAt: record?.updatedAt ?? new Date(),
    };
  }

  async updateSettings(
    userId: string,
    input: UpdateUserSettingsDto,
  ) {
    const [existing] = await db
      .select({ settings: userSettings.settings })
      .from(userSettings)
      .where(eq(userSettings.userId, userId))
      .limit(1);

    const current =
      (existing?.settings as Record<string, unknown> | undefined) ??
      {};
    const update = Object.fromEntries(
      Object.entries(input).filter(([, value]) => value !== undefined),
    );

    const next = {
      ...DEFAULT_SETTINGS,
      ...current,
      ...update,
    };

    const now = new Date();
    const [row] = await db
      .insert(userSettings)
      .values({
        userId,
        settings: next,
        updatedAt: now,
      })
      .onConflictDoUpdate({
        target: userSettings.userId,
        set: {
          settings: next,
          updatedAt: now,
        },
      })
      .returning();

    return {
      settings: row?.settings ?? next,
      updatedAt: row?.updatedAt ?? now,
    };
  }

  async getAccountInfo(userId: string) {
    const [row] = await db
      .select({
        id: users.id,
        email: users.email,
        username: users.username,
        displayName: users.displayName,
        firstName: users.firstName,
        lastName: users.lastName,
        phoneCountry: users.phoneCountry,
        phoneNumber: users.phoneNumber,
        bio: users.bio,
        location: users.location,
        website: users.website,
        isVerified: users.isVerified,
        emailVerifiedAt: users.emailVerifiedAt,
        createdAt: users.createdAt,
        updatedAt: users.updatedAt,
      })
      .from(users)
      .where(eq(users.id, userId))
      .limit(1);

    if (!row) {
      throw new NotFoundException('User not found');
    }

    return {
      account: {
        id: row.id,
        email: row.email,
        username: row.username,
        displayName: row.displayName ?? row.username,
        firstName: row.firstName ?? '',
        lastName: row.lastName ?? '',
        phoneCountryCode: row.phoneCountry ?? '',
        phoneNumber: row.phoneNumber ?? '',
        bio: row.bio ?? '',
        location: row.location ?? '',
        website: row.website ?? '',
        isVerified: row.isVerified === true,
        emailVerifiedAt: row.emailVerifiedAt,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      },
    };
  }

  async updateEmail(userId: string, email: string) {
    const normalized = email.trim().toLowerCase();
    if (!normalized) {
      throw new BadRequestException('Invalid email');
    }

    const [current] = await db
      .select({
        id: users.id,
        email: users.email,
        isVerified: users.isVerified,
        emailVerifiedAt: users.emailVerifiedAt,
      })
      .from(users)
      .where(eq(users.id, userId))
      .limit(1);

    if (!current) {
      throw new NotFoundException('User not found');
    }

    if (current.email === normalized) {
      return {
        email: current.email,
        isVerified: current.isVerified === true,
        emailVerifiedAt: current.emailVerifiedAt,
      };
    }

    const [existing] = await db
      .select({ id: users.id })
      .from(users)
      .where(eq(users.email, normalized))
      .limit(1);

    if (existing && existing.id !== userId) {
      throw new ConflictException('Email already exists');
    }

    const now = new Date();
    const [row] = await db
      .update(users)
      .set({
        email: normalized,
        isVerified: false,
        emailVerifiedAt: null,
        updatedAt: now,
      })
      .where(eq(users.id, userId))
      .returning({
        email: users.email,
        isVerified: users.isVerified,
        emailVerifiedAt: users.emailVerifiedAt,
      });

    if (!row) {
      throw new NotFoundException('User not found');
    }

    try {
      await this.auth.requestEmailVerification(normalized);
    } catch (_) {}

    return {
      email: row.email,
      isVerified: row.isVerified === true,
      emailVerifiedAt: row.emailVerifiedAt,
    };
  }

  async updateHandle(userId: string, input: {
    username?: string;
    displayName?: string;
    bio?: string;
    location?: string;
    website?: string;
  }) {
    const updates: Partial<typeof users.$inferInsert> = {};

    const [current] = await db
      .select({
        id: users.id,
        username: users.username,
      })
      .from(users)
      .where(eq(users.id, userId))
      .limit(1);

    if (!current) {
      throw new NotFoundException('User not found');
    }

    if (input.username !== undefined) {
      const normalized = input.username
        .trim()
        .toLowerCase()
        .replace(/^@+/, '');
      if (!/^[a-z0-9_]{3,32}$/.test(normalized)) {
        throw new BadRequestException('Invalid username');
      }

      if (normalized !== current.username) {
        const [existing] = await db
          .select({ id: users.id })
          .from(users)
          .where(eq(users.username, normalized))
          .limit(1);

        if (existing && existing.id !== userId) {
          throw new ConflictException('Username already exists');
        }
      }

      updates.username = normalized;
    }

    if (input.displayName !== undefined) {
      const trimmed = input.displayName.trim();
      updates.displayName = trimmed.length == 0 ? null : trimmed;
    }

    if (input.bio !== undefined) {
      const trimmed = input.bio.trim();
      updates.bio = trimmed.length == 0 ? null : trimmed;
    }

    if (input.location !== undefined) {
      const trimmed = input.location.trim();
      updates.location = trimmed.length == 0 ? null : trimmed;
    }

    if (input.website !== undefined) {
      const trimmed = input.website.trim();
      updates.website = trimmed.length == 0 ? null : trimmed;
    }

    if (Object.keys(updates).length == 0) {
      const info = await this.getAccountInfo(userId);
      return {
        profile: {
          id: info.account.id,
          username: info.account.username,
          displayName: info.account.displayName,
          bio: info.account.bio,
          location: info.account.location,
          website: info.account.website,
          updatedAt: info.account.updatedAt,
        },
      };
    }

    const [row] = await db
      .update(users)
      .set({
        ...updates,
        updatedAt: new Date(),
      })
      .where(eq(users.id, userId))
      .returning({
        id: users.id,
        username: users.username,
        displayName: users.displayName,
        bio: users.bio,
        location: users.location,
        website: users.website,
        updatedAt: users.updatedAt,
      });

    if (!row) {
      throw new NotFoundException('User not found');
    }

    return {
      profile: {
        id: row.id,
        username: row.username,
        displayName: row.displayName ?? row.username,
        bio: row.bio ?? '',
        location: row.location ?? '',
        website: row.website ?? '',
        updatedAt: row.updatedAt,
      },
    };
  }

  async listBlockedUsers(input: { userId: string; limit?: number }) {
    const limit = Math.min(Math.max(input.limit ?? 30, 1), 50);

    const rows = await db.execute(sql`
      SELECT
        u.id,
        u.username,
        u.display_name AS "displayName",
        u.is_verified AS "isVerified",
        b.created_at AS "blockedAt"
      FROM user_blocks b
      JOIN users u
        ON u.id = b.blocked_id
      WHERE b.blocker_id = ${input.userId}
      ORDER BY b.created_at DESC
      LIMIT ${limit}
    `);

    return {
      items: rows.rows.map((row) => ({
        id: row.id,
        username: row.username,
        displayName: row.displayName ?? row.username,
        isVerified: row.isVerified === true,
        blockedAt: row.blockedAt,
      })),
    };
  }

  async blockUser(input: { userId: string; targetUserId: string }) {
    if (input.userId === input.targetUserId) {
      throw new BadRequestException('Cannot block self');
    }

    const target = await db
      .select({ id: users.id })
      .from(users)
      .where(eq(users.id, input.targetUserId))
      .limit(1);

    if (!target[0]) {
      throw new NotFoundException('User not found');
    }

    await db.transaction(async (tx) => {
      await tx
        .insert(userBlocks)
        .values({
          blockerId: input.userId,
          blockedId: input.targetUserId,
        })
        .onConflictDoNothing({
          target: [userBlocks.blockerId, userBlocks.blockedId],
        });

      await tx
        .delete(follows)
        .where(
          or(
            and(
              eq(follows.followerId, input.userId),
              eq(follows.followingId, input.targetUserId),
            ),
            and(
              eq(follows.followerId, input.targetUserId),
              eq(follows.followingId, input.userId),
            ),
          ),
        );
    });

    return { blocked: true };
  }

  async unblockUser(input: { userId: string; targetUserId: string }) {
    const [row] = await db
      .delete(userBlocks)
      .where(
        and(
          eq(userBlocks.blockerId, input.userId),
          eq(userBlocks.blockedId, input.targetUserId),
        ),
      )
      .returning({ id: userBlocks.id });

    if (!row) {
      throw new NotFoundException('Block not found');
    }

    return { blocked: false };
  }

  async listMutedWords(input: { userId: string; limit?: number }) {
    const limit = Math.min(Math.max(input.limit ?? 50, 1), 200);

    const rows = await db
      .select({
        id: userMutedWords.id,
        phrase: userMutedWords.phrase,
        createdAt: userMutedWords.createdAt,
      })
      .from(userMutedWords)
      .where(eq(userMutedWords.userId, input.userId))
      .orderBy(desc(userMutedWords.createdAt))
      .limit(limit);

    return {
      items: rows.map((row) => ({
        id: row.id,
        phrase: row.phrase,
        createdAt: row.createdAt,
      })),
    };
  }

  async addMutedWord(input: { userId: string; phrase: string }) {
    const phrase = input.phrase.trim().toLowerCase();
    if (!phrase) {
      throw new BadRequestException('Phrase required');
    }

    const [row] = await db
      .insert(userMutedWords)
      .values({
        userId: input.userId,
        phrase,
      })
      .onConflictDoNothing({
        target: [userMutedWords.userId, userMutedWords.phrase],
      })
      .returning({
        id: userMutedWords.id,
        phrase: userMutedWords.phrase,
        createdAt: userMutedWords.createdAt,
      });

    if (!row) {
      return { phrase, existed: true };
    }

    return {
      item: {
        id: row.id,
        phrase: row.phrase,
        createdAt: row.createdAt,
      },
    };
  }

  async removeMutedWord(input: { userId: string; wordId: string }) {
    const [row] = await db
      .delete(userMutedWords)
      .where(
        and(
          eq(userMutedWords.userId, input.userId),
          eq(userMutedWords.id, input.wordId),
        ),
      )
      .returning({ id: userMutedWords.id });

    if (!row) {
      throw new NotFoundException('Muted word not found');
    }

    return { removed: true };
  }

  async createDataExport(userId: string) {
    const [user] = await db
      .select({
        id: users.id,
        email: users.email,
        username: users.username,
        displayName: users.displayName,
        firstName: users.firstName,
        lastName: users.lastName,
        bio: users.bio,
        location: users.location,
        website: users.website,
        phoneCountry: users.phoneCountry,
        phoneNumber: users.phoneNumber,
        isVerified: users.isVerified,
        createdAt: users.createdAt,
      })
      .from(users)
      .where(eq(users.id, userId))
      .limit(1);

    if (!user) {
      throw new NotFoundException('User not found');
    }

    const settingsSnapshot = await this.getSettings(userId);

    const statsRows = await db.execute(sql`
      SELECT
        (SELECT COUNT(*)::int FROM feed_posts WHERE author_id = ${userId}) AS "posts",
        (SELECT COUNT(*)::int FROM follows WHERE following_id = ${userId}) AS "followers",
        (SELECT COUNT(*)::int FROM follows WHERE follower_id = ${userId}) AS "following",
        (SELECT COALESCE(SUM(like_count), 0)::int FROM feed_posts WHERE author_id = ${userId}) AS "likes"
    `);

    const stats = statsRows.rows[0] ?? {};

    const recentPosts = await db
      .select({
        id: feedPosts.id,
        body: feedPosts.body,
        createdAt: feedPosts.createdAt,
        likeCount: feedPosts.likeCount,
        commentCount: feedPosts.commentCount,
        shareCount: feedPosts.shareCount,
      })
      .from(feedPosts)
      .where(eq(feedPosts.authorId, userId))
      .orderBy(desc(feedPosts.createdAt))
      .limit(50);

    const blocked = await db
      .select({
        blockedId: userBlocks.blockedId,
      })
      .from(userBlocks)
      .where(eq(userBlocks.blockerId, userId));

    const muted = await db
      .select({
        phrase: userMutedWords.phrase,
      })
      .from(userMutedWords)
      .where(eq(userMutedWords.userId, userId));

    const payload = {
      generatedAt: new Date().toISOString(),
      user: {
        id: user.id,
        email: user.email,
        username: user.username,
        displayName: user.displayName ?? user.username,
        firstName: user.firstName ?? '',
        lastName: user.lastName ?? '',
        bio: user.bio ?? '',
        location: user.location ?? '',
        website: user.website ?? '',
        phoneCountryCode: user.phoneCountry ?? '',
        phoneNumber: user.phoneNumber ?? '',
        isVerified: user.isVerified === true,
        createdAt: user.createdAt,
      },
      settings: settingsSnapshot.settings,
      stats: {
        posts: Number(stats.posts ?? 0),
        followers: Number(stats.followers ?? 0),
        following: Number(stats.following ?? 0),
        likes: Number(stats.likes ?? 0),
      },
      recentPosts: recentPosts.map((post) => ({
        id: post.id,
        body: post.body,
        createdAt: post.createdAt,
        likeCount: Number(post.likeCount ?? 0),
        commentCount: Number(post.commentCount ?? 0),
        shareCount: Number(post.shareCount ?? 0),
      })),
      blockedAccounts: blocked.map((item) => item.blockedId),
      mutedWords: muted.map((item) => item.phrase),
    };

    const now = new Date();
    const [row] = await db
      .insert(userDataExports)
      .values({
        userId,
        status: 'ready',
        format: 'json',
        payload,
        createdAt: now,
        completedAt: now,
      })
      .returning({
        id: userDataExports.id,
        status: userDataExports.status,
        format: userDataExports.format,
        payload: userDataExports.payload,
        createdAt: userDataExports.createdAt,
        completedAt: userDataExports.completedAt,
      });

    return {
      export: row ?? {
        id: '',
        status: 'ready',
        format: 'json',
        payload,
        createdAt: now,
        completedAt: now,
      },
    };
  }

  async getLatestDataExport(userId: string) {
    const [row] = await db
      .select({
        id: userDataExports.id,
        status: userDataExports.status,
        format: userDataExports.format,
        payload: userDataExports.payload,
        createdAt: userDataExports.createdAt,
        completedAt: userDataExports.completedAt,
      })
      .from(userDataExports)
      .where(eq(userDataExports.userId, userId))
      .orderBy(desc(userDataExports.createdAt))
      .limit(1);

    return { export: row ?? null };
  }

  async deleteAccount(userId: string) {
    const [row] = await db
      .delete(users)
      .where(eq(users.id, userId))
      .returning({ id: users.id });

    if (!row) {
      throw new NotFoundException('User not found');
    }

    return { deleted: true };
  }

  private async ensureNotBlocked(userId: string, targetUserId: string) {
    const [row] = await db
      .select({ id: userBlocks.id })
      .from(userBlocks)
      .where(
        or(
          and(
            eq(userBlocks.blockerId, userId),
            eq(userBlocks.blockedId, targetUserId),
          ),
          and(
            eq(userBlocks.blockerId, targetUserId),
            eq(userBlocks.blockedId, userId),
          ),
        ),
      )
      .limit(1);

    if (row) {
      throw new BadRequestException('User is blocked');
    }
  }

  private normalizeName(value: string) {
    const trimmed = value.trim().replace(/\s+/g, ' ');
    if (trimmed.length < 1 || trimmed.length > 64) {
      return null;
    }
    if (!/^[A-Za-z][A-Za-z '\-]*$/.test(trimmed)) {
      return null;
    }
    return trimmed;
  }

  private normalizePhone(
    countryCode: string,
    phoneNumber: string,
  ) {
    const normalizedCountry = countryCode
      .trim()
      .replace(/\s+/g, '');
    const normalizedNumber = phoneNumber
      .trim()
      .replace(/\s+/g, '');

    const countryDigits = normalizedCountry.startsWith('+')
      ? normalizedCountry.slice(1)
      : normalizedCountry;

    if (!/^\d{1,4}$/.test(countryDigits)) {
      return null;
    }

    if (!/^\d{4,14}$/.test(normalizedNumber)) {
      return null;
    }

    if (countryDigits.length + normalizedNumber.length > 15) {
      return null;
    }

    return {
      countryCode: `+${countryDigits}`,
      phoneNumber: normalizedNumber,
    };
  }

  private async notifyFollow(
    followerId: string,
    followingId: string,
  ) {
    const [actor] = await db
      .select({
        id: users.id,
        username: users.username,
        displayName: users.displayName,
      })
      .from(users)
      .where(eq(users.id, followerId))
      .limit(1);

    if (!actor) return;

    const name = actor.displayName ?? actor.username;

    await this.notifications.createNotification({
      userId: followingId,
      actorId: followerId,
      type: 'follow',
      title: 'New follower',
      body: `${name} started following you`,
      data: {},
      push: true,
    });
  }
}
