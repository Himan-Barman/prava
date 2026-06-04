import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/storage/secure_store.dart';

class FeedAuthor {
  FeedAuthor({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
  });

  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;

  factory FeedAuthor.fromJson(Map<String, dynamic> json) {
    return FeedAuthor(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
    );
  }
}

class FeedTag {
  FeedTag({
    required this.tag,
    required this.postCount,
    required this.rankScore,
    required this.lastPostAt,
  });

  final String tag;
  final int postCount;
  final int rankScore;
  final DateTime? lastPostAt;

  factory FeedTag.fromJson(Map<String, dynamic> json) {
    return FeedTag(
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

class FeedPost {
  FeedPost({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.rankScore,
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
  int rankScore;
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
      rankScore: json['rankScore'] is int
          ? json['rankScore'] as int
          : int.tryParse(json['rankScore']?.toString() ?? '') ?? 0,
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
    required this.postId,
    required this.parentCommentId,
    required this.body,
    required this.createdAt,
    required this.likeCount,
    required this.replyCount,
    required this.liked,
    required this.author,
  });

  final String id;
  final String postId;
  final String? parentCommentId;
  final String body;
  final DateTime createdAt;
  int likeCount;
  int replyCount;
  bool liked;
  final FeedAuthor author;

  factory FeedComment.fromJson(Map<String, dynamic> json) {
    return FeedComment(
      id: json['id']?.toString() ?? '',
      postId: json['postId']?.toString() ?? '',
      parentCommentId: () {
        final value = json['parentCommentId']?.toString().trim() ?? '';
        return value.isEmpty ? null : value;
      }(),
      body: json['body']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      likeCount: json['likeCount'] is int
          ? json['likeCount'] as int
          : int.tryParse(json['likeCount']?.toString() ?? '') ?? 0,
      replyCount: json['replyCount'] is int
          ? json['replyCount'] as int
          : int.tryParse(json['replyCount']?.toString() ?? '') ?? 0,
      liked: json['liked'] == true,
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
    String? tag,
  }) async {
    final query = <String, String>{
      'limit': limit.toString(),
      'mode': mode,
    };
    if (before != null) {
      query['before'] = before.toUtc().toIso8601String();
    }
    if (tag != null && tag.trim().isNotEmpty) {
      query['tag'] = tag.trim().replaceFirst('#', '');
    }

    final data = await _client.get('/feed', auth: true, query: query);
    if (data is! List) return [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(FeedPost.fromJson)
        .toList();
  }

  Future<List<FeedTag>> listTags({int limit = 16}) async {
    final data = await _client.get(
      '/feed/tags',
      auth: true,
      query: {'limit': limit.toString()},
    );
    if (data is! List) return [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(FeedTag.fromJson)
        .where((tag) => tag.tag.isNotEmpty)
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

  Future<List<FeedComment>> listComments(
    String postId, {
    int limit = 100,
  }) async {
    final data = await _client.get(
      '/feed/$postId/comments',
      auth: true,
      query: {'limit': limit.toString()},
    );
    if (data is! List) return [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(FeedComment.fromJson)
        .toList();
  }

  Future<FeedComment> addComment(
    String postId,
    String body, {
    String? parentCommentId,
  }) async {
    final data = await _client.post(
      '/feed/$postId/comments',
      auth: true,
      body: {
        'body': body,
        if (parentCommentId != null && parentCommentId.trim().isNotEmpty)
          'parentCommentId': parentCommentId.trim(),
      },
    );

    final comment = data['comment'] as Map<String, dynamic>? ?? {};
    return FeedComment.fromJson(comment);
  }

  Future<Map<String, dynamic>> toggleCommentLike(
    String postId,
    String commentId,
  ) async {
    final data = await _client.post(
      '/feed/$postId/comments/$commentId/like',
      auth: true,
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<bool> toggleFollow(String userId) async {
    final data = await _client.post('/users/$userId/follow', auth: true);
    if (data['following'] is bool) return data['following'] as bool;
    throw ApiException(500, 'Invalid follow response');
  }
}
