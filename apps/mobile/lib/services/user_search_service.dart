import '../core/network/api_client.dart';
import '../core/storage/secure_store.dart';

class UserSearchResult {
  UserSearchResult({
    required this.id,
    required this.username,
    required this.displayName,
    required this.isVerified,
    required this.isFollowing,
    required this.isFollowedBy,
  });

  final String id;
  final String username;
  final String displayName;
  final bool isVerified;
  final bool isFollowing;
  final bool isFollowedBy;

  bool get isFriend => isFollowing && isFollowedBy;
  bool get isRequested => isFollowing && !isFollowedBy;
  bool get isFollowedByOnly => isFollowedBy && !isFollowing;

  String get handle => '@$username';

  UserSearchResult copyWith({
    bool? isFollowing,
    bool? isFollowedBy,
  }) {
    return UserSearchResult(
      id: id,
      username: username,
      displayName: displayName,
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
      isVerified: json['isVerified'] == true,
      isFollowing: json['isFollowing'] == true,
      isFollowedBy: json['isFollowedBy'] == true,
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
      query: {
        'query': query,
        'limit': limit.toString(),
      },
    );

    final payload = data is Map<String, dynamic>
        ? data
        : <String, dynamic>{};
    final results = payload['results'];
    if (results is! List) return [];

    return results
        .whereType<Map<String, dynamic>>()
        .map(UserSearchResult.fromJson)
        .toList();
  }

  Future<bool> toggleFollow(String userId) async {
    final data = await _client.post(
      '/users/$userId/follow',
      auth: true,
    );
    if (data is Map<String, dynamic>) {
      return data['following'] == true;
    }
    return false;
  }
}
