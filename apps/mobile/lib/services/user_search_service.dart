import '../core/network/api_client.dart';
import '../core/storage/secure_store.dart';

class UserSearchResult {
  UserSearchResult({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.isVerified,
    required this.isFollowing,
    required this.isFollowedBy,
  });

  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;
  final bool isVerified;
  final bool isFollowing;
  final bool isFollowedBy;

  bool get isFriend => isFollowing && isFollowedBy;
  bool get isRequested => isFollowing && !isFollowedBy;
  bool get isFollowedByOnly => isFollowedBy && !isFollowing;

  String get handle => '@$username';

  UserSearchResult copyWith({bool? isFollowing, bool? isFollowedBy}) {
    return UserSearchResult(
      id: id,
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
      isVerified: isVerified,
      isFollowing: isFollowing ?? this.isFollowing,
      isFollowedBy: isFollowedBy ?? this.isFollowedBy,
    );
  }

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    final username = json['username']?.toString() ?? '';
    return UserSearchResult(
      id: json['id']?.toString() ?? '',
      username: username,
      displayName: json['displayName']?.toString() ?? username,
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      isVerified: json['isVerified'] == true,
      isFollowing: json['isFollowing'] == true,
      isFollowedBy: json['isFollowedBy'] == true,
    );
  }
}

class SmartHashtagResult {
  SmartHashtagResult({required this.tag, required this.postCount});

  final String tag;
  final int postCount;

  factory SmartHashtagResult.fromJson(Map<String, dynamic> json) {
    return SmartHashtagResult(
      tag: json['tag']?.toString() ?? '',
      postCount: json['postCount'] is int
          ? json['postCount'] as int
          : int.tryParse(json['postCount']?.toString() ?? '') ?? 0,
    );
  }
}

class SmartPostAuthor {
  SmartPostAuthor({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
  });

  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;

  factory SmartPostAuthor.fromJson(Map<String, dynamic> json) {
    return SmartPostAuthor(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName:
          json['displayName']?.toString() ?? json['username']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
    );
  }
}

class SmartPostResult {
  SmartPostResult({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.hashtags,
    required this.author,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final List<String> hashtags;
  final SmartPostAuthor author;

  factory SmartPostResult.fromJson(Map<String, dynamic> json) {
    return SmartPostResult(
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
      hashtags: (json['hashtags'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      author: SmartPostAuthor.fromJson(
        json['author'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class SmartSearchResult {
  SmartSearchResult({
    required this.accounts,
    required this.hashtags,
    required this.posts,
  });

  final List<UserSearchResult> accounts;
  final List<SmartHashtagResult> hashtags;
  final List<SmartPostResult> posts;

  bool get isEmpty => accounts.isEmpty && hashtags.isEmpty && posts.isEmpty;

  factory SmartSearchResult.empty() {
    return SmartSearchResult(
      accounts: <UserSearchResult>[],
      hashtags: <SmartHashtagResult>[],
      posts: <SmartPostResult>[],
    );
  }

  factory SmartSearchResult.fromJson(Map<String, dynamic> json) {
    return SmartSearchResult(
      accounts: (json['accounts'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(UserSearchResult.fromJson)
          .toList(),
      hashtags: (json['hashtags'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(SmartHashtagResult.fromJson)
          .where((item) => item.tag.isNotEmpty)
          .toList(),
      posts: (json['posts'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(SmartPostResult.fromJson)
          .where((item) => item.id.isNotEmpty)
          .toList(),
    );
  }
}

class UserSearchService {
  UserSearchService({SecureStore? store})
    : _client = ApiClient(store ?? SecureStore());

  final ApiClient _client;

  Future<List<UserSearchResult>> searchUsers(
    String query, {
    int limit = 20,
  }) async {
    final data = await _client.get(
      '/users/search',
      auth: true,
      query: {'query': query, 'limit': limit.toString()},
    );

    final payload = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final results = payload['results'];
    if (results is! List) return [];

    return results
        .whereType<Map<String, dynamic>>()
        .map(UserSearchResult.fromJson)
        .toList();
  }

  Future<SmartSearchResult> smartSearch(String query, {int limit = 8}) async {
    final data = await _client.get(
      '/users/smart-search',
      auth: true,
      query: {'query': query, 'limit': limit.toString()},
    );

    final payload = data is Map<String, dynamic> ? data : <String, dynamic>{};
    return SmartSearchResult.fromJson(payload);
  }

  Future<bool> toggleFollow(String userId) async {
    final data = await _client.post('/users/$userId/follow', auth: true);
    if (data is Map<String, dynamic>) {
      return data['following'] == true;
    }
    return false;
  }

  Future<bool> setFollow(String userId, bool follow) async {
    final data = await _client.put(
      '/users/$userId/follow',
      auth: true,
      body: {'follow': follow},
    );
    if (data is Map<String, dynamic>) {
      return data['following'] == true;
    }
    return follow;
  }
}
