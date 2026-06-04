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
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

class ProfileStats {
  ProfileStats({
    required this.posts,
    required this.followers,
    required this.following,
    required this.likes,
  });

  final int posts;
  final int followers;
  final int following;
  final int likes;

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    return ProfileStats(
      posts: json['posts'] is int
          ? json['posts'] as int
          : int.tryParse(json['posts']?.toString() ?? '') ?? 0,
      followers: json['followers'] is int
          ? json['followers'] as int
          : int.tryParse(json['followers']?.toString() ?? '') ?? 0,
      following: json['following'] is int
          ? json['following'] as int
          : int.tryParse(json['following']?.toString() ?? '') ?? 0,
      likes: json['likes'] is int
          ? json['likes'] as int
          : int.tryParse(json['likes']?.toString() ?? '') ?? 0,
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
    required this.mentions,
    required this.hashtags,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final List<String> mentions;
  final List<String> hashtags;

  factory ProfileFeedPost.fromJson(Map<String, dynamic> json) {
    return ProfileFeedPost(
      id: json['id']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
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
      mentions: (json['mentions'] as List<dynamic>? ?? [])
          .map((m) => m.toString())
          .toList(),
      hashtags: (json['hashtags'] as List<dynamic>? ?? [])
          .map((t) => t.toString())
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
      username: json['username']?.toString() ??
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
    required this.liked,
    required this.visibility,
  });

  final ProfileUser user;
  final ProfileStats stats;
  final List<ProfileFeedPost> posts;
  final List<ProfileTagSummary> tags;
  final List<ProfileMentionSummary> mentions;
  final List<ProfileFeedPost> liked;
  final ProfileVisibility visibility;

  factory ProfileSummary.fromJson(Map<String, dynamic> json) {
    final posts = (json['posts'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ProfileFeedPost.fromJson)
        .toList();
    final liked = (json['liked'] as List<dynamic>? ?? [])
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
      user: ProfileUser.fromJson(
        json['user'] as Map<String, dynamic>? ?? {},
      ),
      stats: ProfileStats.fromJson(
        json['stats'] as Map<String, dynamic>? ?? {},
      ),
      posts: posts,
      tags: tags,
      mentions: mentions,
      liked: liked,
      visibility: ProfileVisibility.fromSummaryJson(
        json['visibility'] as Map<String, dynamic>?,
      ),
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

    final payload = data is Map<String, dynamic>
        ? data
        : <String, dynamic>{};
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
