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

class FeedTopic {
  FeedTopic({
    required this.topic,
    required this.name,
    required this.category,
    required this.language,
    required this.postCount,
    required this.velocityScore,
    required this.followed,
    required this.muted,
  });

  final String topic;
  final String name;
  final String category;
  final String language;
  final int postCount;
  final double velocityScore;
  final bool followed;
  final bool muted;

  factory FeedTopic.fromJson(Map<String, dynamic> json) {
    return FeedTopic(
      topic: json['topic']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      language: json['language']?.toString() ?? '',
      postCount: _readInt(json['postCount']),
      velocityScore: _readDouble(json['velocityScore']),
      followed: json['followed'] == true,
      muted: json['muted'] == true,
    );
  }
}

class FeedPreferences {
  FeedPreferences({
    required this.lens,
    required this.discoveryIntensity,
    required this.friendPriority,
    required this.latestPriority,
    required this.reduceReposts,
    required this.reduceSensitiveContent,
    required this.preferredLanguages,
    required this.mutedKeywords,
  });

  final String lens;
  final double discoveryIntensity;
  final double friendPriority;
  final double latestPriority;
  final bool reduceReposts;
  final bool reduceSensitiveContent;
  final List<String> preferredLanguages;
  final List<String> mutedKeywords;

  factory FeedPreferences.fromJson(Map<String, dynamic> json) {
    return FeedPreferences(
      lens: json['lens']?.toString() ?? 'balanced',
      discoveryIntensity: _readDouble(json['discoveryIntensity'], 0.22),
      friendPriority: _readDouble(json['friendPriority'], 0.35),
      latestPriority: _readDouble(json['latestPriority'], 0.15),
      reduceReposts: json['reduceReposts'] == true,
      reduceSensitiveContent: json['reduceSensitiveContent'] != false,
      preferredLanguages: (json['preferredLanguages'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      mutedKeywords: (json['mutedKeywords'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
    );
  }
}

class FeedInterest {
  FeedInterest({
    required this.topic,
    required this.score,
    required this.followed,
    required this.muted,
  });

  final String topic;
  final double score;
  final bool followed;
  final bool muted;

  factory FeedInterest.fromJson(Map<String, dynamic> json) {
    return FeedInterest(
      topic: json['topic']?.toString() ?? '',
      score: _readDouble(json['score']),
      followed: json['followed'] == true,
      muted: json['muted'] == true,
    );
  }
}

class CustomFeed {
  CustomFeed({
    required this.id,
    required this.name,
    required this.definition,
    required this.isPublic,
  });

  final String id;
  final String name;
  final Map<String, dynamic> definition;
  final bool isPublic;

  factory CustomFeed.fromJson(Map<String, dynamic> json) {
    return CustomFeed(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      definition: json['definition'] is Map<String, dynamic>
          ? json['definition'] as Map<String, dynamic>
          : <String, dynamic>{},
      isPublic: json['isPublic'] == true,
    );
  }
}

class FeedExplanation {
  FeedExplanation({
    required this.postId,
    required this.reasonCode,
    required this.explanation,
    required this.feedSource,
    required this.topicMatch,
  });

  final String postId;
  final String reasonCode;
  final String explanation;
  final String feedSource;
  final String? topicMatch;

  factory FeedExplanation.fromJson(Map<String, dynamic> json) {
    return FeedExplanation(
      postId: json['postId']?.toString() ?? '',
      reasonCode: json['reasonCode']?.toString() ?? '',
      explanation: json['explanation']?.toString() ?? '',
      feedSource: json['feedSource']?.toString() ?? '',
      topicMatch: () {
        final value = json['topicMatch']?.toString().trim() ?? '';
        return value.isEmpty ? null : value;
      }(),
    );
  }
}

class FeedPageResult {
  FeedPageResult({
    required this.items,
    required this.nextCursor,
    required this.sessionId,
    required this.metrics,
  });

  final List<FeedPost> items;
  final String? nextCursor;
  final String? sessionId;
  final Map<String, dynamic> metrics;
}

int _readInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _readDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

class FeedPost {
  FeedPost({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.readCount,
    required this.rankScore,
    required this.recommendationReason,
    required this.recommendationExplanation,
    required this.recommendationMetadata,
    required this.recommendationReasons,
    required this.candidateSources,
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
  int readCount;
  int rankScore;
  final String? recommendationReason;
  final String? recommendationExplanation;
  final Map<String, dynamic> recommendationMetadata;
  final List<String> recommendationReasons;
  final List<String> candidateSources;
  bool liked;
  bool followed;
  final List<String> mentions;
  final List<String> hashtags;
  final FeedAuthor author;

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    final rawRecommendationReason = (json['recommendationReason'] ?? '')
        .toString()
        .trim();
    final recommendationReason = rawRecommendationReason.isEmpty
        ? null
        : rawRecommendationReason;

    return FeedPost(
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
      readCount: json['readCount'] is int
          ? json['readCount'] as int
          : int.tryParse(json['readCount']?.toString() ?? '') ?? 0,
      rankScore: json['rankScore'] is int
          ? json['rankScore'] as int
          : int.tryParse(json['rankScore']?.toString() ?? '') ?? 0,
      recommendationReason: recommendationReason,
      recommendationExplanation:
          (json['recommendationExplanation']?.toString().trim().isNotEmpty ??
              false)
          ? json['recommendationExplanation'].toString()
          : null,
      recommendationMetadata:
          json['recommendationMetadata'] is Map<String, dynamic>
          ? json['recommendationMetadata'] as Map<String, dynamic>
          : <String, dynamic>{},
      recommendationReasons:
          (json['recommendationReasons'] as List<dynamic>? ?? [])
              .map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList(),
      candidateSources: (json['candidateSources'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
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
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
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
    String? sessionId,
  }) async {
    final query = <String, String>{'limit': limit.toString(), 'mode': mode};
    if (before != null) {
      query['before'] = before.toUtc().toIso8601String();
    }
    if (tag != null && tag.trim().isNotEmpty) {
      query['tag'] = tag.trim().replaceFirst('#', '');
    }
    if (sessionId != null && sessionId.trim().isNotEmpty) {
      query['sessionId'] = sessionId.trim();
    }

    final data = await _client.get('/feed', auth: true, query: query);
    if (data is! List) return [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(FeedPost.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> listFeedPage({
    String? cursor,
    DateTime? before,
    int limit = 20,
    String mode = 'for-you',
    String? lens,
    String? topic,
    String? customFeedId,
    String? scope,
    String? sessionId,
  }) async {
    final normalizedMode = _normalizeFeedMode(mode);
    final query = <String, String>{'limit': limit.toString()};
    if (cursor != null && cursor.trim().isNotEmpty) {
      query['cursor'] = cursor.trim();
    }
    if (before != null) {
      query['before'] = before.toUtc().toIso8601String();
    }
    if (sessionId != null && sessionId.trim().isNotEmpty) {
      query['sessionId'] = sessionId.trim();
    }
    if (lens != null && lens.trim().isNotEmpty) {
      query['lens'] = lens.trim();
    }
    if (scope != null && scope.trim().isNotEmpty) {
      query['scope'] = scope.trim();
    }

    final path = switch (normalizedMode) {
      'topics' => '/feed/topic/${Uri.encodeComponent((topic ?? '').trim())}',
      'custom' =>
        '/feed/custom/${Uri.encodeComponent((customFeedId ?? '').trim())}',
      _ => '/feed/$normalizedMode',
    };

    final data = await _client.get(path, auth: true, query: query);
    if (data is! Map<String, dynamic>) {
      return <String, dynamic>{
        'items': <FeedPost>[],
        'nextCursor': null,
        'sessionId': null,
      };
    }

    final items = (data['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(FeedPost.fromJson)
        .toList();

    return <String, dynamic>{
      'items': items,
      'nextCursor': data['nextCursor']?.toString(),
      'sessionId': data['sessionId']?.toString(),
      'metrics': data['metrics'],
    };
  }

  String _normalizeFeedMode(String mode) {
    switch (mode) {
      case 'following':
      case 'friends':
      case 'latest':
      case 'explore':
      case 'conversations':
      case 'catch-up':
      case 'topics':
      case 'custom':
        return mode;
      default:
        return 'for-you';
    }
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

  Future<List<FeedTopic>> listTopics({int limit = 40}) async {
    final data = await _client.get(
      '/feed/topics',
      auth: true,
      query: {'limit': limit.toString()},
    );
    final items = data is Map<String, dynamic>
        ? data['items'] as List<dynamic>? ?? []
        : <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(FeedTopic.fromJson)
        .where((topic) => topic.topic.isNotEmpty)
        .toList();
  }

  Future<FeedPreferences> getPreferences() async {
    final data = await _client.get('/feed/preferences', auth: true);
    final preferences = data is Map<String, dynamic>
        ? data['preferences'] as Map<String, dynamic>? ?? data
        : <String, dynamic>{};
    return FeedPreferences.fromJson(preferences);
  }

  Future<FeedPreferences> updatePreferences(Map<String, dynamic> patch) async {
    final data = await _client.patch(
      '/feed/preferences',
      auth: true,
      body: patch,
    );
    final preferences = data is Map<String, dynamic>
        ? data['preferences'] as Map<String, dynamic>? ?? data
        : <String, dynamic>{};
    return FeedPreferences.fromJson(preferences);
  }

  Future<List<FeedInterest>> listInterests() async {
    final data = await _client.get('/feed/interests', auth: true);
    final items = data is Map<String, dynamic>
        ? data['items'] as List<dynamic>? ?? []
        : <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(FeedInterest.fromJson)
        .where((item) => item.topic.isNotEmpty)
        .toList();
  }

  Future<List<CustomFeed>> listCustomFeeds() async {
    final data = await _client.get('/feed/custom-feeds', auth: true);
    final items = data is Map<String, dynamic>
        ? data['items'] as List<dynamic>? ?? []
        : <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(CustomFeed.fromJson)
        .where((feed) => feed.id.isNotEmpty)
        .toList();
  }

  Future<CustomFeed> saveCustomFeed({
    required String name,
    required List<String> includeTopics,
    bool latestOnly = false,
    bool friendsOnly = false,
  }) async {
    final data = await _client.post(
      '/feed/custom-feeds',
      auth: true,
      body: <String, dynamic>{
        'name': name,
        'includeTopics': includeTopics,
        'latestOnly': latestOnly,
        'friendsOnly': friendsOnly,
      },
    );
    return CustomFeed.fromJson(
      data is Map<String, dynamic> ? data : <String, dynamic>{},
    );
  }

  Future<void> deleteCustomFeed(String feedId) async {
    await _client.delete('/feed/custom-feeds/$feedId', auth: true);
  }

  Future<Map<String, dynamic>> followTopic(String topic, bool follow) async {
    final path = '/feed/topics/${Uri.encodeComponent(topic)}/follow';
    final data = follow
        ? await _client.post(path, auth: true)
        : await _client.delete(path, auth: true);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> muteTopic(String topic, bool mute) async {
    final path = '/feed/topics/${Uri.encodeComponent(topic)}/mute';
    final data = mute
        ? await _client.post(path, auth: true)
        : await _client.delete(path, auth: true);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> snoozeTopic(String topic, {int days = 7}) async {
    final data = await _client.post(
      '/feed/topics/${Uri.encodeComponent(topic)}/snooze',
      auth: true,
      body: {'days': days},
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> resetPersonalization() async {
    final data = await _client.post('/feed/preferences/reset', auth: true);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> clearServedHistory() async {
    final data = await _client.post('/feed/history/clear', auth: true);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<FeedExplanation> explainPost(String postId) async {
    final data = await _client.get('/feed/$postId/why', auth: true);
    return FeedExplanation.fromJson(
      data is Map<String, dynamic> ? data : <String, dynamic>{},
    );
  }

  Future<FeedPost> createPost(String body) async {
    final data = await _client.post('/feed', auth: true, body: {'body': body});
    return FeedPost.fromJson(data);
  }

  Future<FeedPost> fetchPost(String postId) async {
    final data = await _client.get('/feed/$postId', auth: true);
    return FeedPost.fromJson(
      data is Map<String, dynamic> ? data : <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> toggleLike(String postId) async {
    final data = await _client.post('/feed/$postId/like', auth: true);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> sharePost(String postId) async {
    final data = await _client.post('/feed/$postId/share', auth: true);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> recordEvents(
    List<Map<String, dynamic>> events,
  ) async {
    final data = await _client.post(
      '/feed/events',
      auth: true,
      body: {'events': events},
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> hidePost(
    String postId, {
    String reason = 'hidden',
  }) async {
    final data = await _client.post(
      '/feed/$postId/hide',
      auth: true,
      body: {'reason': reason},
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> markNotInterested(
    String postId, {
    String reason = 'not_interested',
  }) async {
    final data = await _client.post(
      '/feed/$postId/not-interested',
      auth: true,
      body: {'reason': reason},
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> showMore(String postId) async {
    final data = await _client.post('/feed/$postId/show-more', auth: true);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> showFewer(String postId) async {
    final data = await _client.post('/feed/$postId/show-fewer', auth: true);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
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
