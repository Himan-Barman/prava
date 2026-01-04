import '../core/network/api_client.dart';
import '../core/storage/secure_store.dart';

class ProfileUser {
  ProfileUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.bio,
    required this.location,
    required this.website,
    required this.isVerified,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String displayName;
  final String bio;
  final String location;
  final String website;
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

class ProfileSummary {
  ProfileSummary({
    required this.user,
    required this.stats,
    required this.posts,
    required this.liked,
  });

  final ProfileUser user;
  final ProfileStats stats;
  final List<ProfileFeedPost> posts;
  final List<ProfileFeedPost> liked;

  factory ProfileSummary.fromJson(Map<String, dynamic> json) {
    final posts = (json['posts'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ProfileFeedPost.fromJson)
        .toList();
    final liked = (json['liked'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ProfileFeedPost.fromJson)
        .toList();

    return ProfileSummary(
      user: ProfileUser.fromJson(
        json['user'] as Map<String, dynamic>? ?? {},
      ),
      stats: ProfileStats.fromJson(
        json['stats'] as Map<String, dynamic>? ?? {},
      ),
      posts: posts,
      liked: liked,
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
}
