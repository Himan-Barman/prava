import '../core/network/api_client.dart';
import '../core/storage/secure_store.dart';

class BlockedUser {
  BlockedUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.isVerified,
    required this.blockedAt,
  });

  final String id;
  final String username;
  final String displayName;
  final bool isVerified;
  final DateTime? blockedAt;

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      isVerified: json['isVerified'] == true,
      blockedAt:
          DateTime.tryParse(json['blockedAt']?.toString() ?? ''),
    );
  }
}

class MutedWord {
  MutedWord({
    required this.id,
    required this.phrase,
    required this.createdAt,
  });

  final String id;
  final String phrase;
  final DateTime? createdAt;

  factory MutedWord.fromJson(Map<String, dynamic> json) {
    return MutedWord(
      id: json['id']?.toString() ?? '',
      phrase: json['phrase']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

class PrivacyService {
  PrivacyService({SecureStore? store})
      : _client = ApiClient(store ?? SecureStore());

  final ApiClient _client;

  Future<List<BlockedUser>> fetchBlocked({int limit = 30}) async {
    final data = await _client.get(
      '/users/me/blocks',
      auth: true,
      query: {'limit': limit.toString()},
    );
    if (data is! Map<String, dynamic>) return [];
    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(BlockedUser.fromJson)
        .toList();
  }

  Future<void> blockUser(String userId) async {
    await _client.post('/users/$userId/block', auth: true);
  }

  Future<void> unblockUser(String userId) async {
    await _client.delete('/users/$userId/block', auth: true);
  }

  Future<List<MutedWord>> fetchMutedWords({int limit = 50}) async {
    final data = await _client.get(
      '/users/me/muted-words',
      auth: true,
      query: {'limit': limit.toString()},
    );
    if (data is! Map<String, dynamic>) return [];
    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(MutedWord.fromJson)
        .toList();
  }

  Future<MutedWord?> addMutedWord(String phrase) async {
    final data = await _client.post(
      '/users/me/muted-words',
      auth: true,
      body: {'phrase': phrase},
    );
    if (data is Map<String, dynamic>) {
      final item = data['item'];
      if (item is Map<String, dynamic>) {
        return MutedWord.fromJson(item);
      }
    }
    return null;
  }

  Future<void> removeMutedWord(String id) async {
    await _client.delete('/users/me/muted-words/$id', auth: true);
  }
}
