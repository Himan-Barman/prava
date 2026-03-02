import { getDb } from "../../lib/mongo.js";
import { requireAuth } from "../../lib/auth.js";
import {
  HttpError,
  ensure,
  isValidEmail,
  isValidUsername,
  normalizeEmail,
  normalizeUsername,
  now,
  toIso,
} from "../../lib/security.js";

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
  textScale: 1,
  languageLabel: "English",
};

function parseLimit(raw, fallback, min, max) {
  const parsed = Number.parseInt(String(raw || ""), 10);
  if (Number.isNaN(parsed)) {
    return fallback;
  }
  return Math.max(min, Math.min(max, parsed));
}

async function ensureUserExists(db, userId) {
  const user = await db.collection("users").findOne(
    { userId },
    {
      projection: {
        userId: 1,
      },
    }
  );
  if (!user) {
    throw new HttpError(404, "User not found");
  }
}

async function ensureNotBlocked(db, a, b) {
  const block = await db.collection("user_blocks").findOne({
    $or: [
      { blockerId: a, blockedId: b },
      { blockerId: b, blockedId: a },
    ],
  });
  if (block) {
    throw new HttpError(403, "User interaction is blocked");
  }
}

function mapProfilePost(post) {
  return {
    id: post.postId,
    body: post.body,
    createdAt: toIso(post.createdAt),
    likeCount: Number(post.likeCount || 0),
    commentCount: Number(post.commentCount || 0),
    shareCount: Number(post.shareCount || 0),
    mentions: Array.isArray(post.mentions) ? post.mentions : [],
    hashtags: Array.isArray(post.hashtags) ? post.hashtags : [],
  };
}

function mapConnectionItem(user, rel) {
  return {
    id: user.userId,
    username: user.username,
    displayName: user.displayName || user.username,
    bio: user.bio || "",
    location: user.location || "",
    isVerified: user.isVerified === true,
    isOnline: false,
    createdAt: toIso(user.createdAt),
    since: rel?.since ? toIso(rel.since) : null,
    isFollowing: rel?.isFollowing === true,
    isFollowedBy: rel?.isFollowedBy === true,
  };
}

async function loadUsersByIds(db, ids) {
  if (!ids || ids.length === 0) {
    return [];
  }
  return db.collection("users").find(
    { userId: { $in: ids } },
    {
      projection: {
        userId: 1,
        username: 1,
        displayName: 1,
        bio: 1,
        location: 1,
        isVerified: 1,
        createdAt: 1,
      },
    }
  ).toArray();
}

async function buildStats(db, userId) {
  const [postsCount, followersCount, followingCount, authoredPosts] = await Promise.all([
    db.collection("posts").countDocuments({ authorId: userId }),
    db.collection("follows").countDocuments({ followingId: userId }),
    db.collection("follows").countDocuments({ followerId: userId }),
    db.collection("posts").find(
      { authorId: userId },
      { projection: { likeCount: 1 } }
    ).toArray(),
  ]);

  const likes = authoredPosts.reduce((sum, post) => sum + Number(post.likeCount || 0), 0);

  return {
    posts: postsCount,
    followers: followersCount,
    following: followingCount,
    likes,
  };
}

async function buildProfileSummary(db, viewerUserId, targetUserId, limit) {
  const user = await db.collection("users").findOne({ userId: targetUserId });
  if (!user) {
    throw new HttpError(404, "User not found");
  }

  const [stats, posts] = await Promise.all([
    buildStats(db, targetUserId),
    db.collection("posts").find(
      { authorId: targetUserId },
      {
        sort: { createdAt: -1 },
        limit,
      }
    ).toArray(),
  ]);

  const summary = {
    user: {
      id: user.userId,
      username: user.username,
      displayName: user.displayName || user.username,
      bio: user.bio || "",
      location: user.location || "",
      website: user.website || "",
      isVerified: user.isVerified === true,
      createdAt: toIso(user.createdAt),
    },
    stats,
    posts: posts.map(mapProfilePost),
  };

  if (viewerUserId === targetUserId) {
    const likedRows = await db.collection("post_likes").find(
      { userId: targetUserId },
      {
        sort: { createdAt: -1 },
        limit,
      }
    ).toArray();

    const likedPostIds = likedRows.map((row) => row.postId);
    const likedPosts = likedPostIds.length
      ? await db.collection("posts").find(
          { postId: { $in: likedPostIds } },
          { sort: { createdAt: -1 } }
        ).toArray()
      : [];

    return {
      ...summary,
      liked: likedPosts.map(mapProfilePost),
    };
  }

  const [isFollowing, isFollowedBy] = await Promise.all([
    db.collection("follows").findOne({
      followerId: viewerUserId,
      followingId: targetUserId,
    }),
    db.collection("follows").findOne({
      followerId: targetUserId,
      followingId: viewerUserId,
    }),
  ]);

  return {
    ...summary,
    relationship: {
      isFollowing: !!isFollowing,
      isFollowedBy: !!isFollowedBy,
    },
  };
}

export default async function userService(app) {
  const db = getDb();

  app.get("/me", { preHandler: requireAuth }, async (request) => {
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
  }, async (request) => {
    try {
      const username = normalizeUsername(request.query?.username);
      ensure(isValidUsername(username), 400, "Invalid username");
      const emailLower = normalizeEmail(request.query?.email);
      const hasEmail = isValidEmail(emailLower);
      const ts = now();

      const existing = await db.collection("users").findOne(
        { usernameLower: username },
        { projection: { userId: 1 } }
      );
      if (existing) {
        return { available: false };
      }

      const reservation = await db.collection("username_reservations").findOne(
        {
          usernameLower: username,
          expiresAt: { $gt: ts },
        },
        { projection: { emailLower: 1, expiresAt: 1 } }
      );

      if (!reservation) {
        return { available: true };
      }

      if (hasEmail && reservation.emailLower === emailLower) {
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

  app.put("/me/details", { preHandler: requireAuth }, async (request) => {
    const body = request.body || {};
    const firstName = String(body.firstName || "").trim();
    const lastName = String(body.lastName || "").trim();
    const phoneCountryCode = String(body.phoneCountryCode || "").trim();
    const phoneNumber = String(body.phoneNumber || "").trim();

    ensure(firstName.length > 0 && firstName.length <= 64, 400, "Invalid first name");
    ensure(lastName.length > 0 && lastName.length <= 64, 400, "Invalid last name");

    const ts = now();
    const displayName = `${firstName} ${lastName}`.trim();

    await db.collection("users").updateOne(
      { userId: request.user.userId },
      {
        $set: {
          details: {
            firstName,
            lastName,
            phoneCountryCode,
            phoneNumber,
          },
          displayName,
          displayNameLower: displayName.toLowerCase(),
          updatedAt: ts,
        },
      }
    );

    return { success: true };
  });

  app.get("/me/account", { preHandler: requireAuth }, async (request) => {
    const user = await db.collection("users").findOne({ userId: request.user.userId });
    if (!user) {
      throw new HttpError(404, "User not found");
    }

    const details = user.details || {};
    return {
      account: {
        id: user.userId,
        email: user.email,
        username: user.username,
        displayName: user.displayName || user.username,
        firstName: details.firstName || "",
        lastName: details.lastName || "",
        phoneCountryCode: details.phoneCountryCode || "",
        phoneNumber: details.phoneNumber || "",
        bio: user.bio || "",
        location: user.location || "",
        website: user.website || "",
        isVerified: user.isVerified === true,
        emailVerifiedAt: toIso(user.emailVerifiedAt),
        createdAt: toIso(user.createdAt),
        updatedAt: toIso(user.updatedAt),
      },
    };
  });

  app.put("/me/email", { preHandler: requireAuth }, async (request) => {
    const emailLower = normalizeEmail(request.body?.email);
    ensure(isValidEmail(emailLower), 400, "Invalid email");

    const duplicate = await db.collection("users").findOne({
      emailLower,
      userId: { $ne: request.user.userId },
    });
    if (duplicate) {
      throw new HttpError(409, "Email already exists");
    }

    const ts = now();
    await db.collection("users").updateOne(
      { userId: request.user.userId },
      {
        $set: {
          email: emailLower,
          emailLower,
          isVerified: false,
          emailVerifiedAt: null,
          updatedAt: ts,
        },
      }
    );

    return {
      email: emailLower,
      isVerified: false,
      emailVerifiedAt: null,
    };
  });

  app.put("/me/handle", { preHandler: requireAuth }, async (request) => {
    const body = request.body || {};
    const update: {
      username?: string;
      usernameLower?: string;
      displayName?: string;
      displayNameLower?: string;
      bio?: string;
      location?: string;
      website?: string;
      updatedAt?: Date;
    } = {};

    if (body.username !== undefined) {
      const usernameLower = normalizeUsername(body.username);
      ensure(isValidUsername(usernameLower), 400, "Invalid username");

      const duplicate = await db.collection("users").findOne({
        usernameLower,
        userId: { $ne: request.user.userId },
      });
      if (duplicate) {
        throw new HttpError(409, "Username already exists");
      }

      update.username = usernameLower;
      update.usernameLower = usernameLower;
    }

    if (body.displayName !== undefined) {
      const displayName = String(body.displayName || "").trim();
      ensure(displayName.length > 0 && displayName.length <= 120, 400, "Invalid display name");
      update.displayName = displayName;
      update.displayNameLower = displayName.toLowerCase();
    }

    if (body.bio !== undefined) {
      update.bio = String(body.bio || "").trim().slice(0, 2000);
    }

    if (body.location !== undefined) {
      update.location = String(body.location || "").trim().slice(0, 120);
    }

    if (body.website !== undefined) {
      update.website = String(body.website || "").trim().slice(0, 240);
    }

    update.updatedAt = now();

    await db.collection("users").updateOne(
      { userId: request.user.userId },
      { $set: update }
    );

    const user = await db.collection("users").findOne({ userId: request.user.userId });
    if (!user) {
      throw new HttpError(404, "User not found");
    }
    return {
      profile: {
        id: user.userId,
        email: user.email,
        username: user.username,
        displayName: user.displayName || user.username,
        firstName: user.details?.firstName || "",
        lastName: user.details?.lastName || "",
        phoneCountryCode: user.details?.phoneCountryCode || "",
        phoneNumber: user.details?.phoneNumber || "",
        bio: user.bio || "",
        location: user.location || "",
        website: user.website || "",
        isVerified: user.isVerified === true,
        emailVerifiedAt: toIso(user.emailVerifiedAt),
        createdAt: toIso(user.createdAt),
        updatedAt: toIso(user.updatedAt),
      },
    };
  });

  app.delete("/me", { preHandler: requireAuth }, async (request) => {
    const ts = now();
    const userId = request.user.userId;

    await Promise.all([
      db.collection("users").updateOne(
        { userId },
        {
          $set: {
            deletedAt: ts,
            updatedAt: ts,
          },
        }
      ),
      db.collection("refresh_tokens").updateMany(
        { userId, revokedAt: null },
        { $set: { revokedAt: ts } }
      ),
    ]);

    return { success: true };
  });

  app.get("/search", { preHandler: requireAuth }, async (request) => {
    const query = String(request.query?.query || "").trim().toLowerCase().replace(/^@+/, "");
    if (query.length < 2 || !/^[a-z0-9_.]+$/.test(query)) {
      return { results: [] };
    }

    const limit = parseLimit(request.query?.limit, 20, 1, 25);
    const regex = new RegExp(`^${query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`);

    const rows = await db.collection("users").find(
      {
        userId: { $ne: request.user.userId },
        $or: [
          { usernameLower: { $regex: regex } },
          { displayNameLower: { $regex: regex } },
        ],
      },
      {
        projection: {
          userId: 1,
          username: 1,
          displayName: 1,
          isVerified: 1,
        },
        sort: { usernameLower: 1 },
        limit,
      }
    ).toArray();

    if (rows.length === 0) {
      return { results: [] };
    }

    const ids = rows.map((row) => row.userId);
    const [following, followedBy] = await Promise.all([
      db.collection("follows").find(
        {
          followerId: request.user.userId,
          followingId: { $in: ids },
        },
        {
          projection: { followingId: 1 },
        }
      ).toArray(),
      db.collection("follows").find(
        {
          followerId: { $in: ids },
          followingId: request.user.userId,
        },
        {
          projection: { followerId: 1 },
        }
      ).toArray(),
    ]);

    const followingSet = new Set(following.map((item) => item.followingId));
    const followedBySet = new Set(followedBy.map((item) => item.followerId));

    return {
      results: rows.map((row) => ({
        id: row.userId,
        username: row.username,
        displayName: row.displayName || row.username,
        isVerified: row.isVerified === true,
        isFollowing: followingSet.has(row.userId),
        isFollowedBy: followedBySet.has(row.userId),
      })),
    };
  });

  app.get("/me/connections", { preHandler: requireAuth }, async (request) => {
    const limit = parseLimit(request.query?.limit, 20, 1, 100);

    const [followersRows, followingRows] = await Promise.all([
      db.collection("follows").find(
        { followingId: request.user.userId },
        { projection: { followerId: 1, createdAt: 1 } }
      ).toArray(),
      db.collection("follows").find(
        { followerId: request.user.userId },
        { projection: { followingId: 1, createdAt: 1 } }
      ).toArray(),
    ]);

    const followerMap = new Map(followersRows.map((row) => [row.followerId, row]));
    const followingMap = new Map(followingRows.map((row) => [row.followingId, row]));

    const followerIds = [...followerMap.keys()];
    const followingIds = [...followingMap.keys()];

    const requestsIds = followerIds.filter((id) => !followingMap.has(id)).slice(0, limit);
    const sentIds = followingIds.filter((id) => !followerMap.has(id)).slice(0, limit);
    const friendsIds = followingIds.filter((id) => followerMap.has(id)).slice(0, limit);

    const userIds = [...new Set([...requestsIds, ...sentIds, ...friendsIds])];
    const users = await loadUsersByIds(db, userIds);
    const userMap = new Map(users.map((user) => [user.userId, user]));

    const requests = requestsIds
      .map((id) => {
        const user = userMap.get(id);
        if (!user) return null;
        return mapConnectionItem(user, {
          isFollowing: false,
          isFollowedBy: true,
          since: followerMap.get(id)?.createdAt,
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
          since: followingMap.get(id)?.createdAt,
        });
      })
      .filter(Boolean);

    const friends = friendsIds
      .map((id) => {
        const user = userMap.get(id);
        if (!user) return null;
        const sinceA = followerMap.get(id)?.createdAt;
        const sinceB = followingMap.get(id)?.createdAt;
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

  app.get("/me/profile", { preHandler: requireAuth }, async (request) => {
    const limit = parseLimit(request.query?.limit, 12, 1, 50);
    return buildProfileSummary(db, request.user.userId, request.user.userId, limit);
  });

  app.get("/:userId/profile", { preHandler: requireAuth }, async (request) => {
    const targetUserId = String(request.params.userId || "").trim();
    ensure(targetUserId.length >= 8, 400, "Invalid user");
    const limit = parseLimit(request.query?.limit, 12, 1, 50);

    await ensureNotBlocked(db, request.user.userId, targetUserId);
    return buildProfileSummary(db, request.user.userId, targetUserId, limit);
  });

  app.get("/me/settings", { preHandler: requireAuth }, async (request) => {
    const settingsDoc = await db.collection("user_settings").findOne({ userId: request.user.userId });
    return {
      settings: {
        ...DEFAULT_SETTINGS,
        ...(settingsDoc?.settings || {}),
      },
    };
  });

  app.put("/me/settings", { preHandler: requireAuth }, async (request) => {
    const incoming = request.body || {};
    const existing = await db.collection("user_settings").findOne({ userId: request.user.userId });

    const settings = {
      ...DEFAULT_SETTINGS,
      ...(existing?.settings || {}),
      ...(incoming || {}),
    };

    await db.collection("user_settings").updateOne(
      { userId: request.user.userId },
      {
        $set: {
          userId: request.user.userId,
          settings,
          updatedAt: now(),
        },
      },
      {
        upsert: true,
      }
    );

    return { settings };
  });

  app.get("/me/blocks", { preHandler: requireAuth }, async (request) => {
    const limit = parseLimit(request.query?.limit, 30, 1, 100);
    const blocks = await db.collection("user_blocks").find(
      { blockerId: request.user.userId },
      {
        sort: { createdAt: -1 },
        limit,
      }
    ).toArray();

    if (blocks.length === 0) {
      return { items: [] };
    }

    const blockedIds = blocks.map((item) => item.blockedId);
    const users = await loadUsersByIds(db, blockedIds);
    const userMap = new Map<string, any>(users.map((user) => [String(user.userId), user]));

    return {
      items: blocks
        .map((block) => {
          const user = userMap.get(block.blockedId);
          if (!user) return null;
          return {
            id: user.userId,
            username: user.username,
            displayName: user.displayName || user.username,
            isVerified: user.isVerified === true,
            blockedAt: toIso(block.createdAt),
          };
        })
        .filter(Boolean),
    };
  });

  app.post("/:targetUserId/block", { preHandler: requireAuth }, async (request) => {
    const targetUserId = String(request.params.targetUserId || "").trim();
    ensure(targetUserId.length >= 8, 400, "Invalid user");
    ensure(targetUserId !== request.user.userId, 400, "Cannot block self");
    await ensureUserExists(db, targetUserId);

    await db.collection("user_blocks").updateOne(
      {
        blockerId: request.user.userId,
        blockedId: targetUserId,
      },
      {
        $setOnInsert: {
          blockerId: request.user.userId,
          blockedId: targetUserId,
          createdAt: now(),
        },
      },
      {
        upsert: true,
      }
    );

    await db.collection("follows").deleteMany({
      $or: [
        { followerId: request.user.userId, followingId: targetUserId },
        { followerId: targetUserId, followingId: request.user.userId },
      ],
    });

    return { blocked: true };
  });

  app.delete("/:targetUserId/block", { preHandler: requireAuth }, async (request) => {
    const targetUserId = String(request.params.targetUserId || "").trim();
    ensure(targetUserId.length >= 8, 400, "Invalid user");

    await db.collection("user_blocks").deleteOne({
      blockerId: request.user.userId,
      blockedId: targetUserId,
    });

    return { blocked: false };
  });

  app.get("/me/muted-words", { preHandler: requireAuth }, async (request) => {
    const limit = parseLimit(request.query?.limit, 50, 1, 200);
    const rows = await db.collection("user_muted_words").find(
      { userId: request.user.userId },
      {
        sort: { createdAt: -1 },
        limit,
      }
    ).toArray();

    return {
      items: rows.map((row) => ({
        id: row.mutedWordId,
        phrase: row.phrase,
        createdAt: toIso(row.createdAt),
      })),
    };
  });

  app.post("/me/muted-words", { preHandler: requireAuth }, async (request) => {
    const phrase = String(request.body?.phrase || "").trim();
    ensure(phrase.length >= 2 && phrase.length <= 80, 400, "Invalid phrase");

    const phraseLower = phrase.toLowerCase();
    const existing = await db.collection("user_muted_words").findOne({
      userId: request.user.userId,
      phraseLower,
    });

    if (existing) {
      return {
        item: {
          id: existing.mutedWordId,
          phrase: existing.phrase,
          createdAt: toIso(existing.createdAt),
        },
      };
    }

    const item = {
      mutedWordId: `${Date.now()}_${Math.random().toString(36).slice(2, 10)}`,
      userId: request.user.userId,
      phrase,
      phraseLower,
      createdAt: now(),
    };

    await db.collection("user_muted_words").insertOne(item);

    return {
      item: {
        id: item.mutedWordId,
        phrase: item.phrase,
        createdAt: toIso(item.createdAt),
      },
    };
  });

  app.delete("/me/muted-words/:id", { preHandler: requireAuth }, async (request) => {
    const id = String(request.params.id || "").trim();
    ensure(id.length >= 3, 400, "Invalid id");

    const result = await db.collection("user_muted_words").deleteOne({
      userId: request.user.userId,
      mutedWordId: id,
    });

    return { removed: result.deletedCount > 0 };
  });

  app.get("/me/data-export", { preHandler: requireAuth }, async (request) => {
    const latest = await db.collection("data_exports").findOne(
      { userId: request.user.userId },
      { sort: { createdAt: -1 } }
    );

    if (!latest) {
      return { export: null };
    }

    return {
      export: {
        id: latest.exportId,
        status: latest.status,
        format: latest.format,
        payload: latest.payload || {},
        createdAt: toIso(latest.createdAt),
        completedAt: toIso(latest.completedAt),
      },
    };
  });

  app.post("/me/data-export", { preHandler: requireAuth }, async (request) => {
    const user = await db.collection("users").findOne({ userId: request.user.userId });
    if (!user) {
      throw new HttpError(404, "User not found");
    }

    const ts = now();
    const exportDoc = {
      exportId: `${Date.now()}_${Math.random().toString(36).slice(2, 10)}`,
      userId: request.user.userId,
      status: "completed",
      format: "json",
      payload: {
        user: {
          id: user.userId,
          email: user.email,
          username: user.username,
          displayName: user.displayName || user.username,
        },
      },
      createdAt: ts,
      completedAt: ts,
    };

    await db.collection("data_exports").insertOne(exportDoc);

    return {
      export: {
        id: exportDoc.exportId,
        status: exportDoc.status,
        format: exportDoc.format,
        payload: exportDoc.payload,
        createdAt: toIso(exportDoc.createdAt),
        completedAt: toIso(exportDoc.completedAt),
      },
    };
  });

  app.post("/:targetUserId/follow", { preHandler: requireAuth }, async (request) => {
    const targetUserId = String(request.params.targetUserId || "").trim();
    ensure(targetUserId.length >= 8, 400, "Invalid user");
    ensure(targetUserId !== request.user.userId, 400, "Cannot follow self");
    await ensureUserExists(db, targetUserId);
    await ensureNotBlocked(db, request.user.userId, targetUserId);

    const existing = await db.collection("follows").findOne({
      followerId: request.user.userId,
      followingId: targetUserId,
    });

    if (existing) {
      await db.collection("follows").deleteOne({ _id: existing._id });
      return { following: false };
    }

    const ts = now();
    await db.collection("follows").insertOne({
      followerId: request.user.userId,
      followingId: targetUserId,
      createdAt: ts,
    });

    await db.collection("notifications").insertOne({
      notificationId: `${Date.now()}_${Math.random().toString(36).slice(2, 10)}`,
      userId: targetUserId,
      actorUserId: request.user.userId,
      type: "follow",
      title: "New follower",
      body: "Someone started following you",
      data: {
        followerId: request.user.userId,
      },
      createdAt: ts,
      readAt: null,
    });

    return { following: true };
  });

  app.put("/:targetUserId/follow", { preHandler: requireAuth }, async (request) => {
    const targetUserId = String(request.params.targetUserId || "").trim();
    const follow = request.body?.follow === true;
    ensure(targetUserId.length >= 8, 400, "Invalid user");
    ensure(targetUserId !== request.user.userId, 400, "Cannot follow self");
    await ensureUserExists(db, targetUserId);
    await ensureNotBlocked(db, request.user.userId, targetUserId);

    if (follow) {
      const result = await db.collection("follows").updateOne(
        {
          followerId: request.user.userId,
          followingId: targetUserId,
        },
        {
          $setOnInsert: {
            followerId: request.user.userId,
            followingId: targetUserId,
            createdAt: now(),
          },
        },
        { upsert: true }
      );
      return {
        following: true,
        changed: result.upsertedCount > 0,
      };
    }

    const result = await db.collection("follows").deleteOne({
      followerId: request.user.userId,
      followingId: targetUserId,
    });

    return {
      following: false,
      changed: result.deletedCount > 0,
    };
  });

  app.delete("/:targetUserId/follower", { preHandler: requireAuth }, async (request) => {
    const targetUserId = String(request.params.targetUserId || "").trim();
    ensure(targetUserId.length >= 8, 400, "Invalid user");

    const result = await db.collection("follows").deleteOne({
      followerId: targetUserId,
      followingId: request.user.userId,
    });

    return { removed: result.deletedCount > 0 };
  });

  app.delete("/:targetUserId/connection", { preHandler: requireAuth }, async (request) => {
    const targetUserId = String(request.params.targetUserId || "").trim();
    ensure(targetUserId.length >= 8, 400, "Invalid user");

    const result = await db.collection("follows").deleteMany({
      $or: [
        { followerId: request.user.userId, followingId: targetUserId },
        { followerId: targetUserId, followingId: request.user.userId },
      ],
    });

    return { removed: result.deletedCount > 0 };
  });
}
