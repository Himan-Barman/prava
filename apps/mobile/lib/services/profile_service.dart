import '../core/network/api_client.dart';
import '../core/storage/secure_store.dart';
import 'profile_visibility.dart';

class ProfileUser {
  ProfileUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.bio,
    required this.location,
    required this.website,
    required this.avatarUrl,
    required this.coverUrl,
    required this.pinnedDetails,
    required this.category,
    required this.aiCreator,
    required this.hometown,
    required this.phoneCountryCode,
    required this.phoneNumber,
    required this.isVerified,
    required this.verificationType,
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
  final String pinnedDetails;
  final String category;
  final bool aiCreator;
  final String hometown;
  final String phoneCountryCode;
  final String phoneNumber;
  final bool isVerified;
  final String verificationType;
  final DateTime? createdAt;

  factory ProfileUser.fromJson(Map<String, dynamic> json) {
    return ProfileUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      website: json['website']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ?? '',
      pinnedDetails: json['pinnedDetails']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      aiCreator: json['aiCreator'] == true,
      hometown: json['hometown']?.toString() ?? '',
      phoneCountryCode: json['phoneCountryCode']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      isVerified: json['isVerified'] == true,
      verificationType: json['verificationType']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

class ProfileStats {
  ProfileStats({
    required this.posts,
    required this.replies,
    required this.media,
    required this.followers,
    required this.following,
    required this.friends,
    required this.mutualFriends,
    required this.closeFriends,
    required this.likes,
    required this.saved,
    required this.drafts,
    required this.archive,
    required this.hiddenPosts,
  });

  final int posts;
  final int replies;
  final int media;
  final int followers;
  final int following;
  final int friends;
  final int mutualFriends;
  final int closeFriends;
  final int likes;
  final int saved;
  final int drafts;
  final int archive;
  final int hiddenPosts;

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    return ProfileStats(
      posts: _intValue(json['posts']),
      replies: _intValue(json['replies']),
      media: _intValue(json['media']),
      followers: _intValue(json['followers']),
      following: _intValue(json['following']),
      friends: _intValue(json['friends']),
      mutualFriends: _intValue(json['mutualFriends']),
      closeFriends: _intValue(json['closeFriends']),
      likes: _intValue(json['likes']),
      saved: _intValue(json['saved']),
      drafts: _intValue(json['drafts']),
      archive: _intValue(json['archive']),
      hiddenPosts: _intValue(json['hiddenPosts']),
    );
  }
}

class ProfileFeedPost {
  ProfileFeedPost({
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

  factory ProfileFeedPost.fromJson(Map<String, dynamic> json) {
    return ProfileFeedPost(
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
          .map((m) => m.toString())
          .toList(),
      hashtags: (json['hashtags'] as List<dynamic>? ?? [])
          .map((t) => t.toString())
          .toList(),
    );
  }
}

class ProfileOwnerShortcut {
  ProfileOwnerShortcut({
    required this.key,
    required this.label,
    required this.count,
  });

  final String key;
  final String label;
  final int count;

  factory ProfileOwnerShortcut.fromJson(Map<String, dynamic> json) {
    return ProfileOwnerShortcut(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      count: _intValue(json['count']),
    );
  }
}

class ProfileOwnerTools {
  ProfileOwnerTools({
    required this.completionScore,
    required this.accountHealthLabel,
    required this.accountRisk,
    required this.verified,
    required this.privateAccount,
    required this.profileViews,
    required this.postReach,
    required this.newFollowers,
    required this.engagement,
    required this.totalPosts,
    required this.totalLikes,
    required this.totalComments,
    required this.totalShares,
    required this.totalReads,
    required this.shortcuts,
    required this.previewModes,
  });

  final int completionScore;
  final String accountHealthLabel;
  final String accountRisk;
  final bool verified;
  final bool privateAccount;
  final int profileViews;
  final int postReach;
  final int newFollowers;
  final int engagement;
  final int totalPosts;
  final int totalLikes;
  final int totalComments;
  final int totalShares;
  final int totalReads;
  final List<ProfileOwnerShortcut> shortcuts;
  final List<String> previewModes;

  factory ProfileOwnerTools.fromJson(Map<String, dynamic>? json) {
    final data = json ?? {};
    final completion = data['completion'] is Map
        ? Map<String, dynamic>.from(data['completion'] as Map)
        : <String, dynamic>{};
    final accountHealth = data['accountHealth'] is Map
        ? Map<String, dynamic>.from(data['accountHealth'] as Map)
        : <String, dynamic>{};
    final verification = data['verification'] is Map
        ? Map<String, dynamic>.from(data['verification'] as Map)
        : <String, dynamic>{};
    final privacy = data['privacyCheckup'] is Map
        ? Map<String, dynamic>.from(data['privacyCheckup'] as Map)
        : <String, dynamic>{};
    final analytics = data['analytics'] is Map
        ? Map<String, dynamic>.from(data['analytics'] as Map)
        : <String, dynamic>{};
    return ProfileOwnerTools(
      completionScore: _intValue(completion['score']),
      accountHealthLabel: accountHealth['label']?.toString() ?? 'Good standing',
      accountRisk: accountHealth['risk']?.toString() ?? 'low',
      verified: verification['verified'] == true,
      privateAccount: privacy['privateAccount'] == true,
      profileViews: _intValue(analytics['profileViews']),
      postReach: _intValue(analytics['postReach']),
      newFollowers: _intValue(analytics['newFollowers']),
      engagement: _intValue(analytics['engagement']),
      totalPosts: _intValue(analytics['totalPosts']),
      totalLikes: _intValue(analytics['totalLikes']),
      totalComments: _intValue(analytics['totalComments']),
      totalShares: _intValue(analytics['totalShares']),
      totalReads: _intValue(analytics['totalReads']),
      shortcuts: (data['shortcuts'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ProfileOwnerShortcut.fromJson)
          .toList(),
      previewModes: (data['previewModes'] as List<dynamic>? ?? [])
          .map((value) => value.toString())
          .toList(),
    );
  }
}

class ProfileTagSummary {
  ProfileTagSummary({
    required this.tag,
    required this.postCount,
    required this.rankScore,
    required this.lastPostAt,
  });

  final String tag;
  final int postCount;
  final int rankScore;
  final DateTime? lastPostAt;

  factory ProfileTagSummary.fromJson(Map<String, dynamic> json) {
    return ProfileTagSummary(
      tag: json['tag']?.toString() ?? '',
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

class ProfileMentionSummary {
  ProfileMentionSummary({
    required this.username,
    required this.postCount,
    required this.rankScore,
    required this.lastPostAt,
  });

  final String username;
  final int postCount;
  final int rankScore;
  final DateTime? lastPostAt;

  factory ProfileMentionSummary.fromJson(Map<String, dynamic> json) {
    return ProfileMentionSummary(
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

class ProfileSummary {
  ProfileSummary({
    required this.user,
    required this.stats,
    required this.posts,
    required this.tags,
    required this.mentions,
    required this.mentionedPosts,
    required this.liked,
    required this.visibility,
    required this.ownerTools,
    required this.profileState,
    required this.viewerRelation,
  });

  final ProfileUser user;
  final ProfileStats stats;
  final List<ProfileFeedPost> posts;
  final List<ProfileTagSummary> tags;
  final List<ProfileMentionSummary> mentions;
  final List<ProfileFeedPost> mentionedPosts;
  final List<ProfileFeedPost> liked;
  final ProfileVisibility visibility;
  final ProfileOwnerTools ownerTools;
  final String profileState;
  final String viewerRelation;

  factory ProfileSummary.fromJson(Map<String, dynamic> json) {
    final posts = (json['posts'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ProfileFeedPost.fromJson)
        .toList();
    final liked = (json['liked'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ProfileFeedPost.fromJson)
        .toList();
    final mentionedPosts = (json['mentionedPosts'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ProfileFeedPost.fromJson)
        .toList();
    final tags = (json['tags'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ProfileTagSummary.fromJson)
        .where((tag) => tag.tag.isNotEmpty)
        .toList();
    final mentions = (json['mentions'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ProfileMentionSummary.fromJson)
        .where((mention) => mention.username.isNotEmpty)
        .toList();

    return ProfileSummary(
      user: ProfileUser.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
      stats: ProfileStats.fromJson(
        json['stats'] as Map<String, dynamic>? ?? {},
      ),
      posts: posts,
      tags: tags,
      mentions: mentions,
      mentionedPosts: mentionedPosts,
      liked: liked,
      visibility: ProfileVisibility.fromSummaryJson(
        json['visibility'] as Map<String, dynamic>?,
      ),
      ownerTools: ProfileOwnerTools.fromJson(
        json['ownerTools'] as Map<String, dynamic>?,
      ),
      profileState: json['profileState']?.toString() ?? 'public',
      viewerRelation: json['viewerRelation']?.toString() ?? '',
    );
  }
}

class ProfileService {
  ProfileService({SecureStore? store})
    : _client = ApiClient(store ?? SecureStore());

  final ApiClient _client;

  Future<ProfileSummary> fetchMyProfile({int limit = 12}) async {
    final data = await _client.get(
      '/users/me/profile',
      auth: true,
      query: {'limit': limit.toString()},
    );

    final payload = data is Map<String, dynamic> ? data : <String, dynamic>{};
    return ProfileSummary.fromJson(payload);
  }

  Future<ProfileSummary> fetchProfilePreview(
    String mode, {
    int limit = 12,
  }) async {
    final data = await _client.get(
      '/users/me/profile/preview',
      auth: true,
      query: {'as': mode, 'limit': limit.toString()},
    );

    final payload = data is Map<String, dynamic> ? data : <String, dynamic>{};
    return ProfileSummary.fromJson(payload);
  }

  Future<ProfileVisibility> fetchProfileVisibility() async {
    final data = await _client.get('/users/me/settings', auth: true);
    final payload = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final settings = payload['settings'];
    return ProfileVisibility.fromSettingsJson(
      settings is Map<String, dynamic> ? settings : payload,
    );
  }

  Future<ProfileVisibility> saveProfileVisibility(
    ProfileVisibility visibility,
  ) async {
    final data = await _client.put(
      '/users/me/settings',
      auth: true,
      body: visibility.toSettingsJson(),
    );
    final payload = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final settings = payload['settings'];
    return ProfileVisibility.fromSettingsJson(
      settings is Map<String, dynamic> ? settings : payload,
    );
  }
}

int _intValue(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
