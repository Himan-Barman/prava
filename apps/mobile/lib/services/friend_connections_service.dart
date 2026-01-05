import '../core/network/api_client.dart';
import '../core/storage/secure_store.dart';

class FriendConnectionUser {
  FriendConnectionUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.bio,
    required this.location,
    required this.isVerified,
    required this.isOnline,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String displayName;
  final String bio;
  final String location;
  final bool isVerified;
  final bool isOnline;
  final DateTime? createdAt;

  factory FriendConnectionUser.fromJson(Map<String, dynamic> json) {
    return FriendConnectionUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName: json['displayName']?.toString() ??
          json['username']?.toString() ??
          '',
      bio: json['bio']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      isVerified: json['isVerified'] == true,
      isOnline: json['isOnline'] == true,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

class FriendConnectionItem {
  FriendConnectionItem({
    required this.user,
    required this.isFollowing,
    required this.isFollowedBy,
    required this.since,
  });

  final FriendConnectionUser user;
  final bool isFollowing;
  final bool isFollowedBy;
  final DateTime? since;

  factory FriendConnectionItem.fromJson(Map<String, dynamic> json) {
    return FriendConnectionItem(
      user: FriendConnectionUser.fromJson(json),
      isFollowing: json['isFollowing'] == true,
      isFollowedBy: json['isFollowedBy'] == true,
      since: DateTime.tryParse(json['since']?.toString() ?? ''),
    );
  }
}

class FriendConnectionsResponse {
  FriendConnectionsResponse({
    required this.requests,
    required this.sent,
    required this.friends,
  });

  final List<FriendConnectionItem> requests;
  final List<FriendConnectionItem> sent;
  final List<FriendConnectionItem> friends;

  factory FriendConnectionsResponse.fromJson(Map<String, dynamic> json) {
    List<FriendConnectionItem> parseList(dynamic value) {
      if (value is! List) return [];
      return value
          .whereType<Map<String, dynamic>>()
          .map(FriendConnectionItem.fromJson)
          .toList();
    }

    return FriendConnectionsResponse(
      requests: parseList(json['requests']),
      sent: parseList(json['sent']),
      friends: parseList(json['friends']),
    );
  }
}

class FriendConnectionsService {
  FriendConnectionsService({SecureStore? store})
      : _client = ApiClient(store ?? SecureStore());

  final ApiClient _client;

  Future<FriendConnectionsResponse> fetchConnections({
    int limit = 20,
  }) async {
    final data = await _client.get(
      '/users/me/connections',
      auth: true,
      query: {'limit': limit.toString()},
    );
    final payload =
        data is Map<String, dynamic> ? data : <String, dynamic>{};
    return FriendConnectionsResponse.fromJson(payload);
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

  Future<void> removeFollower(String userId) async {
    await _client.delete(
      '/users/$userId/follower',
      auth: true,
    );
  }

  Future<void> removeConnection(String userId) async {
    await _client.delete(
      '/users/$userId/connection',
      auth: true,
    );
  }

  Future<void> blockUser(String userId) async {
    await _client.post(
      '/users/$userId/block',
      auth: true,
    );
  }
}
