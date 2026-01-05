import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/storage/secure_store.dart';

class FeedAuthor {
  FeedAuthor({
    required this.id,
    required this.username,
    required this.displayName,
  });

  final String id;
  final String username;
  final String displayName;

  factory FeedAuthor.fromJson(Map<String, dynamic> json) {
    return FeedAuthor(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
    );
  }
}

class FeedPost {
  FeedPost({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.liked,
    required this.followed,
    required this.mentions,
    required this.hashtags,
    required this.author,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  int likeCount;
  int commentCount;
  int shareCount;
  bool liked;
  bool followed;
  final List<String> mentions;
  final List<String> hashtags;
  final FeedAuthor author;

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    return FeedPost(
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
      liked: json['liked'] == true,
      followed: json['followed'] == true,
      mentions: (json['mentions'] as List<dynamic>? ?? [])
          .map((m) => m.toString())
          .toList(),
      hashtags: (json['hashtags'] as List<dynamic>? ?? [])
          .map((t) => t.toString())
          .toList(),
      author: FeedAuthor.fromJson(
        json['author'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class FeedComment {
  FeedComment({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.author,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final FeedAuthor author;

  factory FeedComment.fromJson(Map<String, dynamic> json) {
    return FeedComment(
      id: json['id']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      author: FeedAuthor.fromJson(
        json['author'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class FeedService {
  FeedService({SecureStore? store})
      : _client = ApiClient(store ?? SecureStore());

  final ApiClient _client;

  Future<List<FeedPost>> listFeed({
    DateTime? before,
    int limit = 20,
    String mode = 'for-you',
  }) async {
    final query = <String, String>{
      'limit': limit.toString(),
      'mode': mode,
    };
    if (before != null) {
      query['before'] = before.toUtc().toIso8601String();
    }

    final data = await _client.get('/feed', auth: true, query: query);
    if (data is! List) return [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(FeedPost.fromJson)
        .toList();
  }

  Future<FeedPost> createPost(String body) async {
    final data = await _client.post('/feed', auth: true, body: {
      'body': body,
    });
    return FeedPost.fromJson(data);
  }

  Future<Map<String, dynamic>> toggleLike(String postId) async {
    final data = await _client.post('/feed/$postId/like', auth: true);
    return data;
  }

  Future<Map<String, dynamic>> sharePost(String postId) async {
    final data = await _client.post('/feed/$postId/share', auth: true);
    return data;
  }

  Future<List<FeedComment>> listComments(String postId) async {
    final data =
        await _client.get('/feed/$postId/comments', auth: true);
    if (data is! List) return [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(FeedComment.fromJson)
        .toList();
  }

  Future<FeedComment> addComment(String postId, String body) async {
    final data = await _client.post(
      '/feed/$postId/comments',
      auth: true,
      body: {'body': body},
    );

    final comment = data['comment'] as Map<String, dynamic>? ?? {};
    return FeedComment.fromJson(comment);
  }

  Future<bool> toggleFollow(String userId) async {
    final data = await _client.post('/users/$userId/follow', auth: true);
    if (data['following'] is bool) return data['following'] as bool;
    throw ApiException(500, 'Invalid follow response');
  }
}
