import '../core/network/api_client.dart';
import '../core/storage/secure_store.dart';
import 'profile_visibility.dart';

class PublicProfileUser {
  PublicProfileUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.bio,
    required this.location,
    required this.website,
    required this.avatarUrl,
    required this.coverUrl,
    required this.themeAccentColor,
    required this.profileGradient,
    required this.pinnedDetails,
    required this.category,
    required this.aiCreator,
    required this.hometown,
    required this.isVerified,
    required this.verificationType,
    required this.accountType,
    required this.onlineStatus,
    required this.lastActiveAt,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String displayName;
  final String bio;
  final String location;
  final String website;
  final String avatarUrl;
  final String coverUrl;
  final String themeAccentColor;
  final String profileGradient;
  final String pinnedDetails;
  final String category;
  final bool aiCreator;
  final String hometown;
  final bool isVerified;
  final String verificationType;
  final String accountType;
  final String onlineStatus;
  final DateTime? lastActiveAt;
  final DateTime? createdAt;

  factory PublicProfileUser.fromJson(Map<String, dynamic> json) {
    return PublicProfileUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      website: json['website']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ?? '',
      themeAccentColor: json['themeAccentColor']?.toString() ?? '',
      profileGradient: json['profileGradient']?.toString() ?? '',
      pinnedDetails: json['pinnedDetails']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      aiCreator: json['aiCreator'] == true,
      hometown: json['hometown']?.toString() ?? '',
      isVerified: json['isVerified'] == true,
      verificationType: json['verificationType']?.toString() ?? '',
      accountType: json['accountType']?.toString() ?? '',
      onlineStatus: json['onlineStatus']?.toString() ?? '',
      lastActiveAt: DateTime.tryParse(json['lastActiveAt']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

class PublicProfileStats {
  PublicProfileStats({
    required this.posts,
    required this.replies,
    required this.media,
    required this.followers,
    required this.following,
    required this.friends,
    required this.mutualFriends,
    required this.likes,
  });

  final int posts;
  final int replies;
  final int media;
  final int followers;
  final int following;
  final int friends;
  final int mutualFriends;
  final int likes;

  factory PublicProfileStats.fromJson(Map<String, dynamic> json) {
    return PublicProfileStats(
      posts: _intValue(json['posts']),
      replies: _intValue(json['replies']),
      media: _intValue(json['media']),
      followers: _intValue(json['followers']),
      following: _intValue(json['following']),
      friends: _intValue(json['friends']),
      mutualFriends: _intValue(json['mutualFriends']),
      likes: _intValue(json['likes']),
    );
  }
}

class PublicProfilePost {
  PublicProfilePost({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.readCount,
    required this.mediaUrls,
    required this.mentions,
    required this.hashtags,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int readCount;
  final List<String> mediaUrls;
  final List<String> mentions;
  final List<String> hashtags;

  factory PublicProfilePost.fromJson(Map<String, dynamic> json) {
    return PublicProfilePost(
      id: json['id']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      likeCount: json['likeCount'] is int
          ? json['likeCount'] as int
          : int.tryParse(json['likeCount']?.toString() ?? '') ?? 0,
      commentCount: json['commentCount'] is int
          ? json['commentCount'] as int
          : int.tryParse(json['commentCount']?.toString() ?? '') ?? 0,
      shareCount: json['shareCount'] is int
          ? json['shareCount'] as int
          : int.tryParse(json['shareCount']?.toString() ?? '') ?? 0,
      readCount: _intValue(json['readCount']),
      mediaUrls: (json['mediaUrls'] as List<dynamic>? ?? [])
          .map((value) => value.toString())
          .toList(),
      mentions: (json['mentions'] as List<dynamic>? ?? [])
          .map((value) => value.toString())
          .toList(),
      hashtags: (json['hashtags'] as List<dynamic>? ?? [])
          .map((value) => value.toString())
          .toList(),
    );
  }
}

class PublicProfileMiniUser {
  PublicProfileMiniUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.isVerified,
  });

  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;
  final bool isVerified;

  factory PublicProfileMiniUser.fromJson(Map<String, dynamic> json) {
    return PublicProfileMiniUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      isVerified: json['isVerified'] == true,
    );
  }
}

class PublicProfileAction {
  PublicProfileAction({
    required this.key,
    required this.label,
    required this.style,
    required this.enabled,
  });

  final String key;
  final String label;
  final String style;
  final bool enabled;

  factory PublicProfileAction.fromJson(Map<String, dynamic> json) {
    return PublicProfileAction(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      style: json['style']?.toString() ?? '',
      enabled: json['enabled'] != false,
    );
  }
}

class PublicProfileTab {
  const PublicProfileTab({
    required this.key,
    required this.label,
    required this.ownerOnly,
  });

  final String key;
  final String label;
  final bool ownerOnly;

  factory PublicProfileTab.fromJson(Map<String, dynamic> json) {
    return PublicProfileTab(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      ownerOnly: json['ownerOnly'] == true,
    );
  }
}

class PublicProfileBadge {
  PublicProfileBadge({
    required this.id,
    required this.type,
    required this.label,
    required this.icon,
  });

  final String id;
  final String type;
  final String label;
  final String icon;

  factory PublicProfileBadge.fromJson(Map<String, dynamic> json) {
    return PublicProfileBadge(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
    );
  }
}

class PublicProfileLink {
  PublicProfileLink({required this.id, required this.title, required this.url});

  final String id;
  final String title;
  final String url;

  factory PublicProfileLink.fromJson(Map<String, dynamic> json) {
    return PublicProfileLink(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }
}

class PublicProfileHighlight {
  PublicProfileHighlight({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.mediaUrls,
  });

  final String id;
  final String title;
  final String description;
  final String coverUrl;
  final List<String> mediaUrls;

  factory PublicProfileHighlight.fromJson(Map<String, dynamic> json) {
    return PublicProfileHighlight(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ?? '',
      mediaUrls: (json['mediaUrls'] as List<dynamic>? ?? [])
          .map((value) => value.toString())
          .toList(),
    );
  }
}

class PublicProfileMentionSummary {
  PublicProfileMentionSummary({
    required this.username,
    required this.postCount,
    required this.rankScore,
    required this.lastPostAt,
  });

  final String username;
  final int postCount;
  final int rankScore;
  final DateTime? lastPostAt;

  factory PublicProfileMentionSummary.fromJson(Map<String, dynamic> json) {
    return PublicProfileMentionSummary(
      username:
          json['username']?.toString() ??
          json['mention']?.toString() ??
          json['tag']?.toString() ??
          '',
      postCount: json['postCount'] is int
          ? json['postCount'] as int
          : int.tryParse(json['postCount']?.toString() ?? '') ?? 0,
      rankScore: json['rankScore'] is int
          ? json['rankScore'] as int
          : int.tryParse(json['rankScore']?.toString() ?? '') ?? 0,
      lastPostAt: DateTime.tryParse(json['lastPostAt']?.toString() ?? ''),
    );
  }
}

class PublicProfileRelationship {
  PublicProfileRelationship({
    required this.state,
    required this.isFollowing,
    required this.isFollowedBy,
    required this.isFriend,
    required this.isCloseFriend,
    required this.requestPending,
    required this.incomingRequestPending,
    required this.isBlockedByViewer,
    required this.hasBlockedViewer,
    required this.isMuted,
    required this.isRestricted,
  });

  final String state;
  final bool isFollowing;
  final bool isFollowedBy;
  final bool isFriend;
  final bool isCloseFriend;
  final bool requestPending;
  final bool incomingRequestPending;
  final bool isBlockedByViewer;
  final bool hasBlockedViewer;
  final bool isMuted;
  final bool isRestricted;

  factory PublicProfileRelationship.fromJson(Map<String, dynamic> json) {
    return PublicProfileRelationship(
      state: json['state']?.toString() ?? '',
      isFollowing: json['isFollowing'] == true,
      isFollowedBy: json['isFollowedBy'] == true,
      isFriend: json['isFriend'] == true,
      isCloseFriend: json['isCloseFriend'] == true,
      requestPending: json['requestPending'] == true,
      incomingRequestPending: json['incomingRequestPending'] == true,
      isBlockedByViewer: json['isBlockedByViewer'] == true,
      hasBlockedViewer: json['hasBlockedViewer'] == true,
      isMuted: json['isMuted'] == true,
      isRestricted: json['isRestricted'] == true,
    );
  }
}

class PublicProfileSummary {
  PublicProfileSummary({
    required this.user,
    required this.stats,
    required this.posts,
    required this.replies,
    required this.mediaPosts,
    required this.mentions,
    required this.relationship,
    required this.visibility,
    required this.profileState,
    required this.viewerRelation,
    required this.actions,
    required this.tabs,
    required this.mutualFriends,
    required this.badges,
    required this.links,
    required this.highlights,
    required this.pinnedPosts,
    required this.privacyRestrictions,
  });

  final PublicProfileUser user;
  final PublicProfileStats stats;
  final List<PublicProfilePost> posts;
  final List<PublicProfilePost> replies;
  final List<PublicProfilePost> mediaPosts;
  final List<PublicProfileMentionSummary> mentions;
  final PublicProfileRelationship relationship;
  final ProfileVisibility visibility;
  final String profileState;
  final String viewerRelation;
  final List<PublicProfileAction> actions;
  final List<PublicProfileTab> tabs;
  final List<PublicProfileMiniUser> mutualFriends;
  final List<PublicProfileBadge> badges;
  final List<PublicProfileLink> links;
  final List<PublicProfileHighlight> highlights;
  final List<PublicProfilePost> pinnedPosts;
  final List<String> privacyRestrictions;

  factory PublicProfileSummary.fromJson(Map<String, dynamic> json) {
    final posts = (json['posts'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(PublicProfilePost.fromJson)
        .toList();
    final replies = (json['replies'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(PublicProfilePost.fromJson)
        .toList();
    final mediaPosts = (json['mediaPosts'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(PublicProfilePost.fromJson)
        .toList();
    final mentions = (json['mentions'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(PublicProfileMentionSummary.fromJson)
        .where((mention) => mention.username.isNotEmpty)
        .toList();

    return PublicProfileSummary(
      user: PublicProfileUser.fromJson(
        json['user'] as Map<String, dynamic>? ?? {},
      ),
      stats: PublicProfileStats.fromJson(
        json['stats'] as Map<String, dynamic>? ?? {},
      ),
      posts: posts,
      replies: replies,
      mediaPosts: mediaPosts,
      mentions: mentions,
      relationship: PublicProfileRelationship.fromJson(
        json['relationship'] as Map<String, dynamic>? ?? {},
      ),
      visibility: ProfileVisibility.fromSummaryJson(
        json['visibility'] as Map<String, dynamic>?,
      ),
      profileState: json['profileState']?.toString() ?? 'public',
      viewerRelation: json['viewerRelation']?.toString() ?? '',
      actions: (json['actions'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PublicProfileAction.fromJson)
          .where((action) => action.key.isNotEmpty)
          .toList(),
      tabs: (json['tabs'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PublicProfileTab.fromJson)
          .where((tab) => tab.key.isNotEmpty)
          .toList(),
      mutualFriends: (json['mutualFriends'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PublicProfileMiniUser.fromJson)
          .toList(),
      badges: (json['badges'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PublicProfileBadge.fromJson)
          .toList(),
      links: (json['links'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PublicProfileLink.fromJson)
          .toList(),
      highlights: (json['highlights'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PublicProfileHighlight.fromJson)
          .toList(),
      pinnedPosts: (json['pinnedPosts'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PublicProfilePost.fromJson)
          .toList(),
      privacyRestrictions: (json['privacyRestrictions'] as List<dynamic>? ?? [])
          .map((value) => value.toString())
          .toList(),
    );
  }
}

class PublicProfileFollowResult {
  PublicProfileFollowResult({required this.following, required this.requested});

  final bool following;
  final bool requested;
}

class PublicProfileService {
  PublicProfileService({SecureStore? store})
    : _client = ApiClient(store ?? SecureStore());

  final ApiClient _client;

  Future<PublicProfileSummary> fetchProfile(
    String userId, {
    int limit = 12,
  }) async {
    final data = await _client.get(
      '/users/$userId/profile',
      auth: true,
      query: {'limit': limit.toString()},
    );

    final payload = data is Map<String, dynamic> ? data : <String, dynamic>{};
    return PublicProfileSummary.fromJson(payload);
  }

  Future<PublicProfileFollowResult> setFollow(
    String userId,
    bool follow,
  ) async {
    final data = await _client.put(
      '/users/$userId/follow',
      auth: true,
      body: {'follow': follow},
    );
    if (data is Map<String, dynamic>) {
      return PublicProfileFollowResult(
        following: data['following'] == true,
        requested: data['requested'] == true,
      );
    }
    return PublicProfileFollowResult(following: follow, requested: false);
  }

  Future<void> setBlock(String userId, bool blocked) async {
    if (blocked) {
      await _client.post('/users/$userId/block', auth: true);
    } else {
      await _client.delete('/users/$userId/block', auth: true);
    }
  }

  Future<void> setMute(String userId, bool muted) async {
    if (muted) {
      await _client.post('/users/$userId/mute', auth: true);
    } else {
      await _client.delete('/users/$userId/mute', auth: true);
    }
  }

  Future<void> setRestrict(String userId, bool restricted) async {
    if (restricted) {
      await _client.put(
        '/users/$userId/restrict',
        auth: true,
        body: {'restricted': true},
      );
    } else {
      await _client.delete('/users/$userId/restrict', auth: true);
    }
  }

  Future<void> setCloseFriend(String userId, bool closeFriend) async {
    if (closeFriend) {
      await _client.put(
        '/users/$userId/close-friend',
        auth: true,
        body: {'closeFriend': true},
      );
    } else {
      await _client.delete('/users/$userId/close-friend', auth: true);
    }
  }

  Future<void> removeFollower(String userId) async {
    await _client.delete('/users/$userId/follower', auth: true);
  }

  Future<void> removeConnection(String userId) async {
    await _client.delete('/users/$userId/connection', auth: true);
  }

  Future<void> reportProfile(
    String userId, {
    String reason = 'other',
    String details = '',
  }) async {
    await _client.post(
      '/users/$userId/report',
      auth: true,
      body: {'reason': reason, 'details': details},
    );
  }
}

int _intValue(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
