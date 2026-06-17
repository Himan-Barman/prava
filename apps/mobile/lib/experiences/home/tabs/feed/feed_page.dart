import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../../navigation/prava_navigator.dart';
import '../../../../ui-system/background.dart';
import '../../../../ui-system/colors.dart';
import '../../../../ui-system/components/prava_input.dart';
import '../../../../ui-system/typography.dart';
import '../../../../ui-system/feedback/prava_toast.dart';
import '../../../../ui-system/feedback/toast_type.dart';
import '../../../../ui-system/skeleton/feed_skeleton.dart';
import '../../../../services/feed_service.dart';
import '../../../../services/feed_realtime.dart';
import '../../../../services/chat_service.dart';
import '../../../../services/account_service.dart';
import '../../../../services/user_search_service.dart';
import '../../../../services/local_time_service.dart';
import '../../../../services/platform_bridge_service.dart';
import '../../../../core/storage/secure_store.dart';
import '../profile/public_profile_page.dart';

class _FeedModeOption {
  const _FeedModeOption({
    required this.label,
    required this.mode,
    required this.icon,
    this.lens,
  });

  final String label;
  final String mode;
  final IconData icon;
  final String? lens;
}

typedef _CreatePostCallback =
    Future<FeedPost?> Function({
      required String body,
      required String visibility,
      required String sensitiveLabel,
    });

class FeedPage extends StatefulWidget {
  const FeedPage({super.key, this.onChromeVisibilityChanged});

  final ValueChanged<bool>? onChromeVisibilityChanged;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final FeedService _feedService = FeedService();
  final FeedRealtime _realtime = FeedRealtime();
  final ChatService _chatService = ChatService();
  final AccountService _accountService = AccountService();
  final UserSearchService _userSearchService = UserSearchService();
  final LocalTimeService _time = const LocalTimeService();
  final PlatformBridgeService _platform = PlatformBridgeService();
  final SecureStore _store = SecureStore();

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _composerController = TextEditingController();

  final Set<String> _pendingLikes = <String>{};
  final Set<String> _pendingFollows = <String>{};
  final Set<String> _recordedImpressions = <String>{};

  List<FeedPost> _posts = <FeedPost>[];
  List<FeedTopic> _topics = <FeedTopic>[];
  List<FeedInterest> _interests = <FeedInterest>[];
  List<CustomFeed> _customFeeds = <CustomFeed>[];
  AccountInfo? _composerAccount;
  FeedPreferences? _preferences;
  bool _loading = true;
  bool _loadingMore = false;
  bool _posting = false;
  bool _studioLoading = false;
  bool _hasMore = true;
  int _modeIndex = 0;
  String? _userId;
  bool _feedControlsVisible = true;
  double _lastScrollOffset = 0;
  String? _nextCursor;
  String? _feedSessionId =
      'mobile-feed-${DateTime.now().microsecondsSinceEpoch}';

  static const int _pageSize = 20;
  static const List<_FeedModeOption> _modeOptions = [
    _FeedModeOption(
      label: 'For you',
      mode: 'for-you',
      icon: CupertinoIcons.sparkles,
      lens: 'balanced',
    ),
    _FeedModeOption(
      label: 'Following',
      mode: 'following',
      icon: CupertinoIcons.person_2_fill,
    ),
    _FeedModeOption(
      label: 'Friends',
      mode: 'friends',
      icon: CupertinoIcons.person_3_fill,
      lens: 'friends_first',
    ),
    _FeedModeOption(
      label: 'Latest',
      mode: 'latest',
      icon: CupertinoIcons.clock_fill,
      lens: 'latest',
    ),
    _FeedModeOption(
      label: 'Explore',
      mode: 'explore',
      icon: CupertinoIcons.compass_fill,
      lens: 'discover',
    ),
    _FeedModeOption(
      label: 'Talks',
      mode: 'conversations',
      icon: CupertinoIcons.chat_bubble_2_fill,
      lens: 'conversations',
    ),
    _FeedModeOption(
      label: 'Catch up',
      mode: 'catch-up',
      icon: CupertinoIcons.tray_full_fill,
    ),
  ];

  _FeedModeOption get _currentMode => _modeOptions[_modeIndex];
  String _currentFeedMode() => _currentMode.mode;
  String? _currentLens() => _preferences?.lens ?? _currentMode.lens;

  FeedAuthor? get _composerAuthor {
    for (final post in _posts) {
      if (post.author.id == _userId) return post.author;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    widget.onChromeVisibilityChanged?.call(true);
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _composerController.dispose();
    _realtime.disconnect();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    _userId = await _store.getUserId();
    unawaited(_loadComposerAccount());
    unawaited(_loadFeedStudio());
    await _loadFeed(showSkeleton: true);
    await _realtime.connect(_handleRealtimeEvent);
  }

  Future<void> _loadComposerAccount() async {
    try {
      final account = await _accountService.fetchAccountInfo();
      if (!mounted) return;
      setState(() => _composerAccount = account);
    } catch (_) {
      // The composer can still work with an initial avatar fallback.
    }
  }

  Future<void> _switchMode(int value) async {
    if (value == _modeIndex || value < 0 || value >= _modeOptions.length) {
      return;
    }

    HapticFeedback.selectionClick();
    _setFeedChromeVisible(true);
    if (mounted) {
      setState(() {
        _modeIndex = value;
        _posts = [];
        _hasMore = true;
        _nextCursor = null;
        _feedSessionId =
            'mobile-feed-${DateTime.now().microsecondsSinceEpoch}-$value';
        _recordedImpressions.clear();
      });
    }

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    await _loadFeed(showSkeleton: true);
  }

  Future<void> _loadFeedStudio() async {
    if (_studioLoading) return;
    _studioLoading = true;
    try {
      final results = await Future.wait<dynamic>([
        _feedService.getPreferences(),
        _feedService.listTopics(limit: 32),
        _feedService.listInterests(),
        _feedService.listCustomFeeds(),
      ]);
      if (!mounted) return;
      setState(() {
        _preferences = results[0] as FeedPreferences;
        _topics = results[1] as List<FeedTopic>;
        _interests = results[2] as List<FeedInterest>;
        _customFeeds = results[3] as List<CustomFeed>;
      });
    } catch (_) {
      // Feed Studio data is optional for rendering the primary feed.
    } finally {
      _studioLoading = false;
    }
  }

  Future<void> _loadFeed({bool showSkeleton = false}) async {
    if (showSkeleton && mounted) {
      setState(() => _loading = true);
    }

    try {
      final page = await _feedService.listFeedPage(
        limit: _pageSize,
        mode: _currentFeedMode(),
        lens: _currentLens(),
        sessionId: _feedSessionId,
      );
      final data = page['items'] as List<FeedPost>? ?? <FeedPost>[];
      if (!mounted) return;

      setState(() {
        _posts = data;
        _nextCursor = page['nextCursor']?.toString();
        _feedSessionId = page['sessionId']?.toString() ?? _feedSessionId;
        _hasMore = _nextCursor != null && _nextCursor!.isNotEmpty;
        _loading = false;
      });
      _recordPostImpressions(data);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      PravaToast.show(
        context,
        message: 'Failed to load feed',
        type: PravaToastType.error,
      );
    }
  }

  Future<void> _refreshFeed() async {
    try {
      final page = await _feedService.listFeedPage(
        limit: _pageSize,
        mode: _currentFeedMode(),
        lens: _currentLens(),
        sessionId:
            'mobile-feed-${DateTime.now().microsecondsSinceEpoch}-refresh',
      );
      final posts = page['items'] as List<FeedPost>? ?? <FeedPost>[];
      if (!mounted) return;

      setState(() {
        _posts = posts;
        _nextCursor = page['nextCursor']?.toString();
        _feedSessionId = page['sessionId']?.toString() ?? _feedSessionId;
        _hasMore = _nextCursor != null && _nextCursor!.isNotEmpty;
        _recordedImpressions.clear();
      });
      _recordPostImpressions(posts);
    } catch (_) {
      if (!mounted) return;
      PravaToast.show(
        context,
        message: 'Feed refresh failed',
        type: PravaToastType.error,
      );
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final pixels = position.pixels;
    final delta = pixels - _lastScrollOffset;

    if (pixels <= 8) {
      _setFeedChromeVisible(true);
    } else if (delta > 3) {
      _setFeedChromeVisible(false);
    } else if (delta < -3) {
      _setFeedChromeVisible(true);
    }
    _lastScrollOffset = pixels;

    if (!_hasMore || _loadingMore || _loading) return;
    if (position.pixels >= position.maxScrollExtent - 320) {
      _loadMore();
    }
  }

  void _setFeedChromeVisible(bool visible) {
    if (_feedControlsVisible == visible) return;
    if (mounted) {
      setState(() => _feedControlsVisible = visible);
    } else {
      _feedControlsVisible = visible;
    }
    widget.onChromeVisibilityChanged?.call(visible);
  }

  void _recordPostImpressions(List<FeedPost> posts) {
    final fresh = <FeedPost>[];
    for (final post in posts) {
      if (post.id.isEmpty || _recordedImpressions.contains(post.id)) continue;
      _recordedImpressions.add(post.id);
      fresh.add(post);
    }
    if (fresh.isEmpty) return;

    unawaited(() async {
      try {
        await _feedService.recordEvents(
          fresh
              .map(
                (post) => <String, dynamic>{
                  'type': 'impression',
                  'postId': post.id,
                  'source': _currentFeedMode(),
                  'sessionId': _feedSessionId,
                  'metadata': <String, dynamic>{
                    'reason': post.recommendationReason,
                  },
                },
              )
              .toList(),
        );
      } catch (_) {
        // Feed rendering should not fail because analytics ingestion is unavailable.
      }
    }());
  }

  Future<void> _loadMore() async {
    if (_posts.isEmpty || _loadingMore || _nextCursor == null) return;

    setState(() => _loadingMore = true);

    try {
      final page = await _feedService.listFeedPage(
        cursor: _nextCursor,
        limit: _pageSize,
        mode: _currentFeedMode(),
        lens: _currentLens(),
        sessionId: _feedSessionId,
      );
      final data = page['items'] as List<FeedPost>? ?? <FeedPost>[];

      if (!mounted) return;

      final existing = _posts.map((post) => post.id).toSet();
      final fresh = data
          .where((post) => post.id.isNotEmpty && !existing.contains(post.id))
          .toList();
      setState(() {
        _posts = [..._posts, ...fresh];
        _nextCursor = page['nextCursor']?.toString();
        _feedSessionId = page['sessionId']?.toString() ?? _feedSessionId;
        _hasMore = _nextCursor != null && _nextCursor!.isNotEmpty;
        _loadingMore = false;
      });
      _recordPostImpressions(fresh);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<FeedPost?> _createPost({
    required String body,
    required String visibility,
    required String sensitiveLabel,
  }) async {
    if (_posting) return null;

    final trimmedBody = body.trim();
    final words = _wordCount(body);
    if (trimmedBody.isEmpty) {
      PravaToast.show(
        context,
        message: 'Write something before posting',
        type: PravaToastType.warning,
      );
      return null;
    }
    if (words > 200) {
      PravaToast.show(
        context,
        message: 'Posts must stay under 200 words',
        type: PravaToastType.warning,
      );
      return null;
    }

    HapticFeedback.selectionClick();
    setState(() => _posting = true);

    try {
      final post = await _feedService.createPost(
        trimmedBody,
        visibility: visibility,
        sensitiveLabel: sensitiveLabel,
      );
      if (!mounted) return null;

      setState(() {
        _posts = [post, ..._posts];
        _posting = false;
      });
      return post;
    } catch (_) {
      if (!mounted) return null;
      setState(() => _posting = false);
      PravaToast.show(
        context,
        message: 'Post failed. Try again.',
        type: PravaToastType.error,
      );
      return null;
    }
  }

  int _wordCount(String value) {
    return value.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  void _handleRealtimeEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString();
    final payload = event['payload'];
    if (payload is! Map<String, dynamic> || type == null) return;

    switch (type) {
      case 'FEED_POST':
        _applyPostEvent(payload);
        break;
      case 'FEED_LIKE':
        _applyLikeEvent(payload);
        break;
      case 'FEED_COMMENT':
        _applyCommentEvent(payload);
        break;
      case 'FEED_SHARE':
        _applyShareEvent(payload);
        break;
      default:
        break;
    }
  }

  void _applyPostEvent(Map<String, dynamic> payload) {
    if (_currentFeedMode() != 'for-you') return;
    final post = FeedPost.fromJson(payload);
    if (_posts.any((item) => item.id == post.id)) return;
    if (_posts.any(
      (item) => item.author.id == post.author.id && item.followed,
    )) {
      post.followed = true;
    }

    if (mounted) {
      setState(() {
        _posts = [post, ..._posts];
      });
    }
  }

  void _applyLikeEvent(Map<String, dynamic> payload) {
    final postId = payload['postId']?.toString();
    if (postId == null || postId.isEmpty) return;

    final likeCount = payload['likeCount'];
    final liked = payload['liked'] == true;
    final userId = payload['userId']?.toString();

    for (final post in _posts) {
      if (post.id == postId) {
        if (likeCount is int) {
          post.likeCount = likeCount;
        }
        if (userId != null && userId == _userId) {
          post.liked = liked;
        }
        break;
      }
    }

    if (mounted) setState(() {});
  }

  void _syncFollowState(String authorId, bool followed) {
    for (final post in _posts) {
      if (post.author.id == authorId) {
        post.followed = followed;
      }
    }
  }

  void _applyCommentEvent(Map<String, dynamic> payload) {
    final postId = payload['postId']?.toString();
    if (postId == null || postId.isEmpty) return;

    final commentCount = payload['commentCount'];
    for (final post in _posts) {
      if (post.id == postId) {
        if (commentCount is int) {
          post.commentCount = commentCount;
        }
        break;
      }
    }

    if (mounted) setState(() {});
  }

  void _applyShareEvent(Map<String, dynamic> payload) {
    final postId = payload['postId']?.toString();
    if (postId == null || postId.isEmpty) return;

    final shareCount = payload['shareCount'];
    for (final post in _posts) {
      if (post.id == postId) {
        if (shareCount is int) {
          post.shareCount = shareCount;
        }
        break;
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _toggleLike(FeedPost post) async {
    if (_pendingLikes.contains(post.id)) return;

    HapticFeedback.selectionClick();
    _pendingLikes.add(post.id);

    final previousLiked = post.liked;
    final previousCount = post.likeCount;

    setState(() {
      post.liked = !post.liked;
      post.likeCount = post.liked ? post.likeCount + 1 : post.likeCount - 1;
      if (post.likeCount < 0) post.likeCount = 0;
    });

    try {
      final result = await _feedService.toggleLike(post.id);
      if (!mounted) return;

      setState(() {
        post.liked = result['liked'] == true;
        post.likeCount = _readInt(result['likeCount'], post.likeCount);
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        post.liked = previousLiked;
        post.likeCount = previousCount;
      });

      PravaToast.show(
        context,
        message: 'Could not update like',
        type: PravaToastType.error,
      );
    } finally {
      _pendingLikes.remove(post.id);
    }
  }

  Future<void> _toggleFollow(FeedPost post) async {
    if (_pendingFollows.contains(post.author.id)) return;

    HapticFeedback.selectionClick();
    _pendingFollows.add(post.author.id);

    final previous = post.followed;
    final next = !previous;
    setState(() {
      _syncFollowState(post.author.id, next);
    });

    try {
      final following = await _feedService.toggleFollow(post.author.id);
      if (!mounted) return;
      setState(() {
        _syncFollowState(post.author.id, following);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _syncFollowState(post.author.id, previous);
      });

      PravaToast.show(
        context,
        message: 'Could not update follow',
        type: PravaToastType.error,
      );
    } finally {
      _pendingFollows.remove(post.author.id);
    }
  }

  void _openComments(FeedPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CommentSheet(
          post: post,
          feedService: _feedService,
          onCommentAdded: () {
            setState(() {
              post.commentCount += 1;
            });
          },
          onAuthorTap: (author) {
            Navigator.of(context).pop();
            _openPublicProfile(author);
          },
        );
      },
    );
  }

  void _openComposer() {
    _setFeedChromeVisible(true);
    Navigator.of(context, rootNavigator: true)
        .push<FeedPost>(
          PravaNavigator.route(
            _PostComposerPage(
              controller: _composerController,
              account: _composerAccount,
              author: _composerAuthor,
              feedService: _feedService,
              userSearchService: _userSearchService,
              wordCount: _wordCount,
              onCreate: _createPost,
            ),
            fullscreenDialog: true,
          ),
        )
        .then((post) {
          if (post != null) {
            _composerController.clear();
          }
        });
  }

  void _openPublicProfile(FeedAuthor author) {
    if (author.id.isEmpty || author.id == _userId) return;
    HapticFeedback.selectionClick();
    Navigator.of(context, rootNavigator: true).push(
      PravaNavigator.route(
        PublicProfilePage(userId: author.id, initialIsFollowing: false),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _openMentionProfile(String username) async {
    final handle = username.trim().replaceFirst('@', '').toLowerCase();
    if (handle.length < 2) return;

    HapticFeedback.selectionClick();
    try {
      final results = await _userSearchService.searchUsers(
        handle,
        limit: 8,
        includeSelf: true,
      );
      UserSearchResult? user;
      for (final item in results) {
        if (item.username.toLowerCase() == handle) {
          user = item;
          break;
        }
      }
      if (!mounted || user == null || user.id.isEmpty) {
        return;
      }
      Navigator.of(context, rootNavigator: true).push(
        PravaNavigator.route(
          PublicProfilePage(
            userId: user.id,
            initialIsFollowing: user.isFollowing,
            initialIsFollowedBy: user.isFollowedBy,
          ),
          fullscreenDialog: true,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      PravaToast.show(
        context,
        message: 'Unable to open profile',
        type: PravaToastType.error,
      );
    }
  }

  void _openHashtagFeed(String tag) {
    final normalized = tag.trim().replaceFirst('#', '');
    if (normalized.isEmpty) return;
    HapticFeedback.selectionClick();
    _setFeedChromeVisible(true);
    Navigator.of(context, rootNavigator: true).push(
      PravaNavigator.route(
        HashtagFeedPage(tag: normalized),
        fullscreenDialog: true,
      ),
    );
  }

  int _readInt(dynamic value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  void _openShare(FeedPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ShareSheet(
          post: post,
          feedService: _feedService,
          chatService: _chatService,
          platform: _platform,
          onShareUpdated: (count) {
            setState(() {
              post.shareCount = count;
            });
          },
        );
      },
    );
  }

  void _openPostControls(FeedPost post) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _PostControlsSheet(
          post: post,
          feedService: _feedService,
          onPostRemoved: () {
            if (!mounted) return;
            setState(() => _posts.removeWhere((item) => item.id == post.id));
          },
          onFeedbackSaved: () {
            if (!mounted) return;
            PravaToast.show(
              context,
              message: 'Feed preference updated',
              type: PravaToastType.success,
            );
          },
        );
      },
    );
  }

  Future<void> _openFeedStudio() async {
    HapticFeedback.selectionClick();
    await _loadFeedStudio();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _FeedStudioSheet(
          feedService: _feedService,
          preferences: _preferences,
          topics: _topics,
          interests: _interests,
          customFeeds: _customFeeds,
          onPreferencesChanged: (preferences) {
            if (!mounted) return;
            setState(() => _preferences = preferences);
            unawaited(_refreshFeed());
          },
          onTopicsChanged: () async {
            await _loadFeedStudio();
            if (mounted) setState(() {});
          },
          onOpenTopic: _openHashtagFeed,
          onOpenCustomFeed: _openCustomFeed,
          onReset: () async {
            await _feedService.resetPersonalization();
            await _loadFeedStudio();
            if (!mounted) return;
            await _refreshFeed();
          },
        );
      },
    );
  }

  void _openCustomFeed(CustomFeed feed) {
    if (feed.id.isEmpty) return;
    HapticFeedback.selectionClick();
    Navigator.of(context, rootNavigator: true).push(
      PravaNavigator.route(
        HashtagFeedPage(tag: feed.name, mode: 'custom', customFeedId: feed.id),
        fullscreenDialog: true,
      ),
    );
  }

  TextSpan _buildPostSpan(String text, TextStyle base, TextStyle highlight) {
    final regex = RegExp(r'(@[a-zA-Z0-9_.]{2,32}|#[a-zA-Z0-9_]{2,32})');
    final spans = <TextSpan>[];
    var start = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > start) {
        spans.add(
          TextSpan(text: text.substring(start, match.start), style: base),
        );
      }
      final token = match.group(0) ?? '';
      spans.add(
        TextSpan(
          text: token,
          style: highlight,
          recognizer: token.startsWith('#')
              ? (TapGestureRecognizer()
                  ..onTap = () => _openHashtagFeed(token.substring(1)))
              : (TapGestureRecognizer()
                  ..onTap = () =>
                      unawaited(_openMentionProfile(token.substring(1)))),
        ),
      );
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: base));
    }

    return TextSpan(children: spans, style: base);
  }

  String _formatTimeAgo(DateTime createdAt) {
    return _time.shortRelative(createdAt);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final primary = tokens.textPrimary;
    final secondary = tokens.textSecondary;

    final visiblePosts = _posts;

    return Stack(
      children: [
        Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: ClipRect(
                child: Align(
                  heightFactor: _feedControlsVisible ? 1 : 0,
                  alignment: Alignment.topCenter,
                  child: AnimatedOpacity(
                    opacity: _feedControlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 120),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: _FeedModeRail(
                              modes: _modeOptions,
                              activeIndex: _modeIndex,
                              onChanged: _switchMode,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _FeedStudioButton(onTap: _openFeedStudio),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const FeedSkeleton()
                  : RefreshIndicator(
                      onRefresh: _refreshFeed,
                      color: tokens.brandPrimary,
                      child: CustomScrollView(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        slivers: [
                          if (visiblePosts.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        CupertinoIcons.sparkles,
                                        color: secondary,
                                        size: 32,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No posts yet',
                                        style: PravaTypography.bodyLarge
                                            .copyWith(
                                              color: primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Be the first to share something premium.',
                                        textAlign: TextAlign.center,
                                        style: PravaTypography.bodyMedium
                                            .copyWith(color: secondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverList.builder(
                              itemCount: visiblePosts.length,
                              itemBuilder: (context, index) {
                                final post = visiblePosts[index];
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    6,
                                    16,
                                    12,
                                  ),
                                  child: _PostCard(
                                    post: post,
                                    primary: primary,
                                    secondary: secondary,
                                    onLike: () => _toggleLike(post),
                                    onComment: () => _openComments(post),
                                    onShare: () => _openShare(post),
                                    onMore: () => _openPostControls(post),
                                    onFollow: () => _toggleFollow(post),
                                    onAuthorTap: () =>
                                        _openPublicProfile(post.author),
                                    showFollow: post.author.id != _userId,
                                    pendingFollow: _pendingFollows.contains(
                                      post.author.id,
                                    ),
                                    timeAgo: _formatTimeAgo(post.createdAt),
                                    bodySpan: _buildPostSpan(
                                      post.body,
                                      PravaTypography.bodyMedium.copyWith(
                                        color: primary,
                                      ),
                                      PravaTypography.bodyMedium.copyWith(
                                        color: tokens.linkDefault,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          SliverToBoxAdapter(
                            child: AnimatedOpacity(
                              opacity: _loadingMore ? 1 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 96,
                                  top: 8,
                                ),
                                child: Center(
                                  child: CupertinoActivityIndicator(
                                    color: tokens.brandPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
        Positioned(
          right: 18,
          bottom: 18,
          child: IgnorePointer(
            ignoring: !_feedControlsVisible,
            child: AnimatedOpacity(
              opacity: _feedControlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              child: AnimatedScale(
                scale: _feedControlsVisible ? 1 : 0.86,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                child: _ComposeFab(onTap: _openComposer),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedModeRail extends StatelessWidget {
  const _FeedModeRail({
    required this.modes,
    required this.activeIndex,
    required this.onChanged,
  });

  final List<_FeedModeOption> modes;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: modes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final mode = modes[index];
          final active = index == activeIndex;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: active
                    ? tokens.brandPrimary
                    : tokens.backgroundSurfaceSubtle,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: active
                      ? Colors.transparent
                      : tokens.borderSubtle.withValues(alpha: 0.8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    mode.icon,
                    size: 17,
                    color: active ? tokens.textInverse : tokens.iconSecondary,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    mode.label,
                    style: PravaTypography.caption.copyWith(
                      color: active ? tokens.textInverse : tokens.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeedStudioButton extends StatelessWidget {
  const _FeedStudioButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return CupertinoButton(
      minimumSize: const Size(42, 42),
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: tokens.backgroundSurfaceSubtle,
          shape: BoxShape.circle,
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Icon(
          CupertinoIcons.slider_horizontal_3,
          size: 20,
          color: tokens.iconPrimary,
        ),
      ),
    );
  }
}

class HashtagFeedPage extends StatefulWidget {
  const HashtagFeedPage({
    super.key,
    required this.tag,
    this.mode = 'topics',
    this.customFeedId,
  });

  final String tag;
  final String mode;
  final String? customFeedId;

  @override
  State<HashtagFeedPage> createState() => _HashtagFeedPageState();
}

class _HashtagFeedPageState extends State<HashtagFeedPage> {
  final FeedService _feedService = FeedService();
  final ChatService _chatService = ChatService();
  final UserSearchService _userSearchService = UserSearchService();
  final LocalTimeService _time = const LocalTimeService();
  final PlatformBridgeService _platform = PlatformBridgeService();
  final SecureStore _store = SecureStore();
  final ScrollController _scrollController = ScrollController();

  final Set<String> _pendingLikes = <String>{};
  final Set<String> _pendingFollows = <String>{};

  List<FeedPost> _posts = <FeedPost>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _nextCursor;
  String? _sessionId =
      'mobile-feed-topic-${DateTime.now().microsecondsSinceEpoch}';
  String? _userId;

  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    _userId = await _store.getUserId();
    await _loadFeed(showSkeleton: true);
  }

  Future<void> _loadFeed({bool showSkeleton = false}) async {
    if (showSkeleton && mounted) setState(() => _loading = true);
    try {
      final page = await _feedService.listFeedPage(
        limit: _pageSize,
        mode: widget.mode,
        topic: widget.mode == 'custom' ? null : widget.tag,
        customFeedId: widget.customFeedId,
        sessionId: _sessionId,
      );
      final data = page['items'] as List<FeedPost>? ?? <FeedPost>[];
      if (!mounted) return;
      setState(() {
        _posts = data;
        _nextCursor = page['nextCursor']?.toString();
        _sessionId = page['sessionId']?.toString() ?? _sessionId;
        _hasMore = _nextCursor != null && _nextCursor!.isNotEmpty;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      PravaToast.show(
        context,
        message: 'Unable to load hashtag posts',
        type: PravaToastType.error,
      );
    }
  }

  Future<void> _refresh() async {
    await _loadFeed(showSkeleton: false);
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_posts.isEmpty || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _feedService.listFeedPage(
        cursor: _nextCursor,
        limit: _pageSize,
        mode: widget.mode,
        topic: widget.mode == 'custom' ? null : widget.tag,
        customFeedId: widget.customFeedId,
        sessionId: _sessionId,
      );
      final data = page['items'] as List<FeedPost>? ?? <FeedPost>[];
      if (!mounted) return;
      final existing = _posts.map((post) => post.id).toSet();
      final fresh = data
          .where((post) => post.id.isNotEmpty && !existing.contains(post.id))
          .toList();
      setState(() {
        _posts = [..._posts, ...fresh];
        _nextCursor = page['nextCursor']?.toString();
        _sessionId = page['sessionId']?.toString() ?? _sessionId;
        _hasMore = _nextCursor != null && _nextCursor!.isNotEmpty;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _toggleLike(FeedPost post) async {
    if (_pendingLikes.contains(post.id)) return;
    HapticFeedback.selectionClick();
    _pendingLikes.add(post.id);
    final previousLiked = post.liked;
    final previousCount = post.likeCount;

    setState(() {
      post.liked = !post.liked;
      post.likeCount += post.liked ? 1 : -1;
      if (post.likeCount < 0) post.likeCount = 0;
    });

    try {
      final result = await _feedService.toggleLike(post.id);
      if (!mounted) return;
      setState(() {
        post.liked = result['liked'] == true;
        post.likeCount = _readInt(result['likeCount'], post.likeCount);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        post.liked = previousLiked;
        post.likeCount = previousCount;
      });
      PravaToast.show(
        context,
        message: 'Could not update like',
        type: PravaToastType.error,
      );
    } finally {
      _pendingLikes.remove(post.id);
    }
  }

  Future<void> _toggleFollow(FeedPost post) async {
    if (_pendingFollows.contains(post.author.id)) return;
    HapticFeedback.selectionClick();
    _pendingFollows.add(post.author.id);
    final previous = post.followed;
    final next = !previous;
    setState(() => _syncFollowState(post.author.id, next));

    try {
      final following = await _feedService.toggleFollow(post.author.id);
      if (!mounted) return;
      setState(() => _syncFollowState(post.author.id, following));
    } catch (_) {
      if (!mounted) return;
      setState(() => _syncFollowState(post.author.id, previous));
    } finally {
      _pendingFollows.remove(post.author.id);
    }
  }

  void _syncFollowState(String authorId, bool followed) {
    for (final post in _posts) {
      if (post.author.id == authorId) post.followed = followed;
    }
  }

  void _openComments(FeedPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CommentSheet(
          post: post,
          feedService: _feedService,
          onCommentAdded: () {
            setState(() => post.commentCount += 1);
          },
          onAuthorTap: (author) {
            Navigator.of(context).pop();
            _openPublicProfile(author);
          },
        );
      },
    );
  }

  void _openShare(FeedPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ShareSheet(
          post: post,
          feedService: _feedService,
          chatService: _chatService,
          platform: _platform,
          onShareUpdated: (count) {
            setState(() => post.shareCount = count);
          },
        );
      },
    );
  }

  void _openPostControls(FeedPost post) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _PostControlsSheet(
          post: post,
          feedService: _feedService,
          onPostRemoved: () {
            if (!mounted) return;
            setState(() => _posts.removeWhere((item) => item.id == post.id));
          },
          onFeedbackSaved: () {
            if (!mounted) return;
            PravaToast.show(
              context,
              message: 'Feed preference updated',
              type: PravaToastType.success,
            );
          },
        );
      },
    );
  }

  void _openPublicProfile(FeedAuthor author) {
    if (author.id.isEmpty || author.id == _userId) return;
    HapticFeedback.selectionClick();
    Navigator.of(context, rootNavigator: true).push(
      PravaNavigator.route(
        PublicProfilePage(userId: author.id),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _openMentionProfile(String username) async {
    final handle = username.trim().replaceFirst('@', '').toLowerCase();
    if (handle.length < 2) return;

    HapticFeedback.selectionClick();
    try {
      final results = await _userSearchService.searchUsers(
        handle,
        limit: 8,
        includeSelf: true,
      );
      UserSearchResult? user;
      for (final item in results) {
        if (item.username.toLowerCase() == handle) {
          user = item;
          break;
        }
      }
      if (!mounted || user == null || user.id.isEmpty) {
        return;
      }
      Navigator.of(context, rootNavigator: true).push(
        PravaNavigator.route(
          PublicProfilePage(
            userId: user.id,
            initialIsFollowing: user.isFollowing,
            initialIsFollowedBy: user.isFollowedBy,
          ),
          fullscreenDialog: true,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      PravaToast.show(
        context,
        message: 'Unable to open profile',
        type: PravaToastType.error,
      );
    }
  }

  void _openHashtagFeed(String tag) {
    final normalized = tag.trim().replaceFirst('#', '');
    if (normalized.isEmpty || normalized == widget.tag) return;
    HapticFeedback.selectionClick();
    Navigator.of(context, rootNavigator: true).push(
      PravaNavigator.route(
        HashtagFeedPage(tag: normalized),
        fullscreenDialog: true,
      ),
    );
  }

  TextSpan _buildPostSpan(String text, TextStyle base, TextStyle highlight) {
    final regex = RegExp(r'(@[a-zA-Z0-9_.]{2,32}|#[a-zA-Z0-9_]{2,32})');
    final spans = <TextSpan>[];
    var start = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      final token = match.group(0) ?? '';
      spans.add(
        TextSpan(
          text: token,
          style: highlight,
          recognizer: token.startsWith('#')
              ? (TapGestureRecognizer()
                  ..onTap = () => _openHashtagFeed(token.substring(1)))
              : (TapGestureRecognizer()
                  ..onTap = () =>
                      unawaited(_openMentionProfile(token.substring(1)))),
        ),
      );
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return TextSpan(children: spans, style: base);
  }

  String _formatTimeAgo(DateTime createdAt) {
    return _time.shortRelative(createdAt);
  }

  int _readInt(dynamic value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final primary = tokens.textPrimary;
    final secondary = tokens.textSecondary;
    final background = tokens.backgroundCanvas;
    final border = tokens.borderSubtle;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      CupertinoIcons.chevron_left,
                      color: tokens.iconPrimary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.mode == 'custom'
                              ? widget.tag
                              : '#${widget.tag}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PravaTypography.titleLarge.copyWith(
                            color: primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          widget.mode == 'custom'
                              ? 'Saved feed'
                              : 'Recent posts with strongest engagement',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PravaTypography.caption.copyWith(
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: border),
            Expanded(
              child: _loading
                  ? const FeedSkeleton()
                  : RefreshIndicator(
                      color: tokens.brandPrimary,
                      onRefresh: _refresh,
                      child: CustomScrollView(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        slivers: [
                          if (_posts.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Text(
                                  widget.mode == 'custom'
                                      ? 'No posts in this feed yet'
                                      : 'No posts for this topic yet',
                                  style: PravaTypography.bodyMedium.copyWith(
                                    color: secondary,
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverList.builder(
                              itemCount: _posts.length,
                              itemBuilder: (context, index) {
                                final post = _posts[index];
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    10,
                                    16,
                                    4,
                                  ),
                                  child: _PostCard(
                                    post: post,
                                    primary: primary,
                                    secondary: secondary,
                                    onLike: () => _toggleLike(post),
                                    onComment: () => _openComments(post),
                                    onShare: () => _openShare(post),
                                    onMore: () => _openPostControls(post),
                                    onFollow: () => _toggleFollow(post),
                                    onAuthorTap: () =>
                                        _openPublicProfile(post.author),
                                    showFollow: post.author.id != _userId,
                                    pendingFollow: _pendingFollows.contains(
                                      post.author.id,
                                    ),
                                    timeAgo: _formatTimeAgo(post.createdAt),
                                    bodySpan: _buildPostSpan(
                                      post.body,
                                      PravaTypography.bodyMedium.copyWith(
                                        color: primary,
                                      ),
                                      PravaTypography.bodyMedium.copyWith(
                                        color: tokens.linkDefault,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          SliverToBoxAdapter(
                            child: AnimatedOpacity(
                              opacity: _loadingMore ? 1 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 22,
                                ),
                                child: Center(
                                  child: CupertinoActivityIndicator(
                                    color: tokens.brandPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostComposerPage extends StatefulWidget {
  const _PostComposerPage({
    required this.controller,
    required this.account,
    required this.author,
    required this.feedService,
    required this.userSearchService,
    required this.wordCount,
    required this.onCreate,
  });

  final TextEditingController controller;
  final AccountInfo? account;
  final FeedAuthor? author;
  final FeedService feedService;
  final UserSearchService userSearchService;
  final int Function(String value) wordCount;
  final _CreatePostCallback onCreate;

  @override
  State<_PostComposerPage> createState() => _PostComposerPageState();
}

class _PostComposerPageState extends State<_PostComposerPage> {
  String _visibility = 'public';
  bool _sensitive = false;
  bool _posting = false;

  String get _visibilityLabel {
    switch (_visibility) {
      case 'followers':
        return 'Followers';
      case 'friends':
        return 'Friends';
      case 'private':
        return 'Only me';
      default:
        return 'Public';
    }
  }

  IconData get _visibilityIcon {
    switch (_visibility) {
      case 'followers':
        return CupertinoIcons.person_2_fill;
      case 'friends':
        return CupertinoIcons.person_3_fill;
      case 'private':
        return CupertinoIcons.lock_fill;
      default:
        return CupertinoIcons.globe;
    }
  }

  Future<void> _submit() async {
    if (_posting) return;
    setState(() => _posting = true);
    final post = await widget.onCreate(
      body: widget.controller.text,
      visibility: _visibility,
      sensitiveLabel: _sensitive ? 'sensitive' : '',
    );
    if (!mounted) return;
    setState(() => _posting = false);
    if (post != null) {
      Navigator.of(context).pop(post);
    }
  }

  Future<void> _clearDraft() async {
    if (widget.controller.text.trim().isEmpty) return;
    final shouldClear = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final tokens = dialogContext.pravaColors;
        return CupertinoAlertDialog(
          title: const Text('Clear draft?'),
          content: const Text('This removes the text you have written.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: PravaTypography.bodyMedium.copyWith(
                  color: tokens.textPrimary,
                ),
              ),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
    if (shouldClear == true) {
      widget.controller.clear();
      HapticFeedback.selectionClick();
    }
  }

  void _openSettings() {
    final tokens = context.pravaColors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void selectVisibility(String value) {
              setState(() => _visibility = value);
              setSheetState(() {});
              HapticFeedback.selectionClick();
            }

            void toggleSensitive(bool value) {
              setState(() => _sensitive = value);
              setSheetState(() {});
              HapticFeedback.selectionClick();
            }

            return SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                decoration: BoxDecoration(
                  color: tokens.backgroundSurface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: tokens.borderSubtle),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.shadowMedium,
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: tokens.borderStrong,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Text(
                      'Post settings',
                      style: PravaTypography.titleLarge.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose who can see this post before publishing.',
                      style: PravaTypography.bodySmall.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _ComposerSettingOption(
                      icon: CupertinoIcons.globe,
                      title: 'Public',
                      subtitle: 'Anyone on Prava can view it',
                      selected: _visibility == 'public',
                      onTap: () => selectVisibility('public'),
                    ),
                    _ComposerSettingOption(
                      icon: CupertinoIcons.person_2_fill,
                      title: 'Followers',
                      subtitle: 'Only your followers can view it',
                      selected: _visibility == 'followers',
                      onTap: () => selectVisibility('followers'),
                    ),
                    _ComposerSettingOption(
                      icon: CupertinoIcons.person_3_fill,
                      title: 'Friends',
                      subtitle: 'Only mutual friends can view it',
                      selected: _visibility == 'friends',
                      onTap: () => selectVisibility('friends'),
                    ),
                    _ComposerSettingOption(
                      icon: CupertinoIcons.lock_fill,
                      title: 'Only me',
                      subtitle: 'Keep it private on your profile',
                      selected: _visibility == 'private',
                      onTap: () => selectVisibility('private'),
                    ),
                    const SizedBox(height: 10),
                    _ComposerSettingSwitch(
                      icon: CupertinoIcons.exclamationmark_triangle_fill,
                      title: 'Sensitive content',
                      subtitle: 'Label this post for safer feeds',
                      value: _sensitive,
                      onChanged: toggleSensitive,
                    ),
                    const SizedBox(height: 8),
                    _ComposerSettingAction(
                      icon: CupertinoIcons.trash_fill,
                      title: 'Clear draft',
                      destructive: true,
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await _clearDraft();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: tokens.backgroundCanvas,
      body: Stack(
        children: [
          PravaBackground(isDark: isDark),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 12, 8),
                  child: Row(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size.square(42),
                        onPressed: _posting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Icon(
                          CupertinoIcons.xmark,
                          color: tokens.iconPrimary,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Create post',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PravaTypography.displaySmall.copyWith(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size.square(44),
                        onPressed: _openSettings,
                        child: Icon(
                          CupertinoIcons.ellipsis,
                          color: tokens.iconPrimary,
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      18,
                      6,
                      18,
                      24 + (bottomInset > 0 ? 8 : 0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ComposerAuthorHeader(
                          account: widget.account,
                          author: widget.author,
                          visibilityIcon: _visibilityIcon,
                          visibilityLabel: _visibilityLabel,
                          sensitive: _sensitive,
                          onSettingsTap: _openSettings,
                        ),
                        const SizedBox(height: 18),
                        _ComposerCard(
                          controller: widget.controller,
                          feedService: widget.feedService,
                          userSearchService: widget.userSearchService,
                          onPost: _submit,
                          isPosting: _posting,
                          wordCount: widget.wordCount,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerAuthorHeader extends StatelessWidget {
  const _ComposerAuthorHeader({
    required this.account,
    required this.author,
    required this.visibilityIcon,
    required this.visibilityLabel,
    required this.sensitive,
    required this.onSettingsTap,
  });

  final AccountInfo? account;
  final FeedAuthor? author;
  final IconData visibilityIcon;
  final String visibilityLabel;
  final bool sensitive;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final name =
        (account?.displayName.isNotEmpty == true
                ? account!.displayName
                : author?.displayName.isNotEmpty == true
                ? author!.displayName
                : account?.username.isNotEmpty == true
                ? account!.username
                : author?.username ?? 'You')
            .trim();
    final username =
        (account?.username.isNotEmpty == true
                ? account!.username
                : author?.username ?? '')
            .trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ComposerAvatar(account: account, author: author),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'You' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PravaTypography.titleMedium.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                username.isEmpty ? 'New post' : '@$username',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PravaTypography.bodySmall.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _ComposerSettingPill(
          icon: visibilityIcon,
          label: sensitive ? '$visibilityLabel - Sensitive' : visibilityLabel,
          onTap: onSettingsTap,
        ),
      ],
    );
  }
}

class _ComposerSettingPill extends StatelessWidget {
  const _ComposerSettingPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: tokens.backgroundSurfaceRaised,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: tokens.brandContent),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PravaTypography.caption.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerSettingOption extends StatelessWidget {
  const _ComposerSettingOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            _ComposerSettingIcon(icon: icon, selected: selected),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: PravaTypography.bodyMedium.copyWith(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: PravaTypography.caption.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                CupertinoIcons.check_mark_circled_solid,
                color: tokens.brandPrimary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

class _ComposerSettingSwitch extends StatelessWidget {
  const _ComposerSettingSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _ComposerSettingIcon(icon: icon, selected: value),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: PravaTypography.bodyMedium.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: PravaTypography.caption.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: tokens.brandPrimary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ComposerSettingAction extends StatelessWidget {
  const _ComposerSettingAction({
    required this.icon,
    required this.title,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final color = destructive ? tokens.statusError : tokens.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            _ComposerSettingIcon(icon: icon, selected: false, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: PravaTypography.bodyMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerSettingIcon extends StatelessWidget {
  const _ComposerSettingIcon({
    required this.icon,
    required this.selected,
    this.color,
  });

  final IconData icon;
  final bool selected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final iconColor =
        color ?? (selected ? tokens.brandContent : tokens.iconSecondary);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: selected
            ? tokens.brandContainer
            : tokens.backgroundSurfaceSubtle,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 18, color: iconColor),
    );
  }
}

class _ComposerCard extends StatefulWidget {
  const _ComposerCard({
    required this.controller,
    required this.feedService,
    required this.userSearchService,
    required this.onPost,
    required this.isPosting,
    required this.wordCount,
  });

  final TextEditingController controller;
  final FeedService feedService;
  final UserSearchService userSearchService;
  final VoidCallback onPost;
  final bool isPosting;
  final int Function(String value) wordCount;

  @override
  State<_ComposerCard> createState() => _ComposerCardState();
}

class _ComposerCardState extends State<_ComposerCard> {
  Timer? _suggestionTimer;
  _ComposerToken? _activeToken;
  List<UserSearchResult> _mentionSuggestions = <UserSearchResult>[];
  List<SmartHashtagResult> _hashtagSuggestions = <SmartHashtagResult>[];
  bool _suggesting = false;
  int _suggestionRequest = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChanged);
    _handleTextChanged();
  }

  @override
  void didUpdateWidget(covariant _ComposerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChanged);
      widget.controller.addListener(_handleTextChanged);
      _handleTextChanged();
    }
  }

  @override
  void dispose() {
    _suggestionTimer?.cancel();
    widget.controller.removeListener(_handleTextChanged);
    super.dispose();
  }

  void _handleTextChanged() {
    final token = _activeComposerToken(widget.controller.value);
    _suggestionTimer?.cancel();

    if (token == null) {
      _suggestionRequest++;
      if (mounted) {
        setState(() {
          _activeToken = null;
          _mentionSuggestions = <UserSearchResult>[];
          _hashtagSuggestions = <SmartHashtagResult>[];
          _suggesting = false;
        });
      }
      return;
    }

    setState(() {
      _activeToken = token;
      _mentionSuggestions = <UserSearchResult>[];
      _hashtagSuggestions = <SmartHashtagResult>[];
      _suggesting = true;
    });

    final request = ++_suggestionRequest;
    _suggestionTimer = Timer(
      const Duration(milliseconds: 80),
      () => unawaited(_loadSuggestions(token, request)),
    );
  }

  _ComposerToken? _activeComposerToken(TextEditingValue value) {
    final text = value.text;
    final cursor = value.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) return null;

    final beforeCursor = text.substring(0, cursor);
    final match = RegExp(
      r'(^|\s)([@#])([a-zA-Z0-9_.]*)$',
    ).firstMatch(beforeCursor);
    if (match == null) return null;

    final symbol = match.group(2) ?? '';
    final query = match.group(3) ?? '';
    if (symbol.isEmpty) return null;
    if (symbol == '#' && query.contains('.')) return null;

    final leading = match.group(1)?.length ?? 0;
    return _ComposerToken(
      symbol: symbol,
      query: query,
      start: match.start + leading,
      end: cursor,
    );
  }

  Future<void> _loadSuggestions(_ComposerToken token, int request) async {
    try {
      if (token.symbol == '@') {
        final users = await widget.userSearchService.searchUsers(
          token.query,
          limit: 6,
          includeSelf: true,
        );
        if (!mounted || request != _suggestionRequest) return;
        setState(() {
          _mentionSuggestions = users;
          _hashtagSuggestions = <SmartHashtagResult>[];
          _suggesting = false;
        });
        return;
      }

      final tags = token.query.length < 2
          ? (await widget.feedService.listTags(limit: 6))
                .map(
                  (tag) => SmartHashtagResult(
                    tag: tag.tag,
                    postCount: tag.postCount,
                  ),
                )
                .toList()
          : (await widget.userSearchService.smartSearch(
              '#${token.query}',
              limit: 6,
            )).hashtags;
      if (!mounted || request != _suggestionRequest) return;
      setState(() {
        _hashtagSuggestions = tags;
        _mentionSuggestions = <UserSearchResult>[];
        _suggesting = false;
      });
    } catch (_) {
      if (!mounted || request != _suggestionRequest) return;
      setState(() {
        _mentionSuggestions = <UserSearchResult>[];
        _hashtagSuggestions = <SmartHashtagResult>[];
        _suggesting = false;
      });
    }
  }

  void _insertToken(String token) {
    HapticFeedback.selectionClick();
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final needsSpaceBefore =
        start > 0 && !RegExp(r'\s').hasMatch(text[start - 1]);
    final insertion = '${needsSpaceBefore ? ' ' : ''}$token';

    final updated = text.replaceRange(start, end, insertion);
    widget.controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + insertion.length),
    );
  }

  void _insertSuggestion(String token) {
    final activeToken = _activeToken;
    if (activeToken == null) return;

    HapticFeedback.selectionClick();
    final text = widget.controller.text;
    final replacement = '$token ';
    final updated = text.replaceRange(
      activeToken.start,
      activeToken.end,
      replacement,
    );
    widget.controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(
        offset: activeToken.start + replacement.length,
      ),
    );
    _suggestionRequest++;
    setState(() {
      _activeToken = null;
      _mentionSuggestions = <UserSearchResult>[];
      _hashtagSuggestions = <SmartHashtagResult>[];
      _suggesting = false;
    });
  }

  Widget _buildSuggestions(Color primary, Color secondary, Color border) {
    final tokens = context.pravaColors;
    final token = _activeToken;
    if (token == null) return const SizedBox.shrink();
    final showMentions = token.symbol == '@' && _mentionSuggestions.isNotEmpty;
    final showHashtags = token.symbol == '#' && _hashtagSuggestions.isNotEmpty;
    if (!_suggesting && !showMentions && !showHashtags) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(top: 12),
      constraints: const BoxConstraints(maxHeight: 156),
      decoration: BoxDecoration(
        color: tokens.brandContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: _suggesting
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: CupertinoActivityIndicator(color: tokens.brandPrimary),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: showMentions
                  ? _mentionSuggestions.length
                  : _hashtagSuggestions.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: border.withValues(alpha: 0.55)),
              itemBuilder: (context, index) {
                if (showMentions) {
                  final user = _mentionSuggestions[index];
                  return _MentionSuggestionTile(
                    user: user,
                    primary: primary,
                    secondary: secondary,
                    onTap: () => _insertSuggestion('@${user.username}'),
                  );
                }

                final tag = _hashtagSuggestions[index];
                return _HashtagSuggestionTile(
                  tag: tag,
                  primary: primary,
                  secondary: secondary,
                  onTap: () => _insertSuggestion('#${tag.tag}'),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final surface = tokens.backgroundSurface;
    final border = tokens.borderSubtle;
    final primary = tokens.textPrimary;
    final secondary = tokens.textSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: tokens.shadowMedium,
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 260,
            child: PravaInput(
              controller: widget.controller,
              hint: 'Share something with Prava...',
              fieldType: PravaInputFieldType.post,
              variant: PravaInputVariant.borderless,
              size: PravaInputSize.medium,
              expands: true,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              textAlignVertical: TextAlignVertical.top,
              scrollPhysics: const BouncingScrollPhysics(),
            ),
          ),
          _buildSuggestions(primary, secondary, border),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ComposerIcon(
                        icon: CupertinoIcons.person_crop_circle_badge_plus,
                        label: 'Mention',
                        onTap: () => _insertToken('@'),
                      ),
                      const SizedBox(width: 8),
                      _ComposerIcon(
                        icon: CupertinoIcons.number,
                        label: 'Hashtag',
                        onTap: () => _insertToken('#'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (context, value, child) {
                  final text = value.text.trim();
                  final count = widget.wordCount(text);
                  final tooLong = count > 200 || text.length > 1600;
                  final canPost = text.isNotEmpty && !tooLong;
                  return Row(
                    children: [
                      Text(
                        '$count/200',
                        style: PravaTypography.caption.copyWith(
                          color: tooLong ? tokens.statusError : secondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 11,
                        ),
                        color: canPost
                            ? tokens.brandPrimary
                            : tokens.backgroundPressed,
                        borderRadius: BorderRadius.circular(20),
                        onPressed: widget.isPosting || !canPost
                            ? null
                            : widget.onPost,
                        child: widget.isPosting
                            ? CupertinoActivityIndicator(
                                color: tokens.textInverse,
                              )
                            : Text(
                                'Post',
                                style: PravaTypography.buttonMedium.copyWith(
                                  color: canPost
                                      ? tokens.textInverse
                                      : tokens.textDisabled,
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComposerToken {
  const _ComposerToken({
    required this.symbol,
    required this.query,
    required this.start,
    required this.end,
  });

  final String symbol;
  final String query;
  final int start;
  final int end;
}

class _ComposerAvatar extends StatelessWidget {
  const _ComposerAvatar({required this.account, required this.author});

  final AccountInfo? account;
  final FeedAuthor? author;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final avatarUrl =
        (account?.avatarUrl.trim().isNotEmpty == true
                ? account!.avatarUrl
                : author?.avatarUrl ?? '')
            .trim();
    final name =
        (account?.displayName.isNotEmpty == true
                ? account!.displayName
                : author?.displayName.isNotEmpty == true
                ? author!.displayName
                : account?.username.isNotEmpty == true
                ? account!.username
                : author?.username ?? '')
            .trim();

    return SizedBox(
      width: 44,
      height: 44,
      child: ClipOval(
        child: avatarUrl.isNotEmpty
            ? Image.network(avatarUrl, fit: BoxFit.cover)
            : Container(
                color: tokens.brandContainer,
                child: Center(
                  child: Text(
                    name.isEmpty ? 'P' : name[0].toUpperCase(),
                    style: PravaTypography.titleSmall.copyWith(
                      color: tokens.brandContent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _MentionSuggestionTile extends StatelessWidget {
  const _MentionSuggestionTile({
    required this.user,
    required this.primary,
    required this.secondary,
    required this.onTap,
  });

  final UserSearchResult user;
  final Color primary;
  final Color secondary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final name = user.displayName.isNotEmpty ? user.displayName : user.username;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: ClipOval(
                child: user.avatarUrl.trim().isNotEmpty
                    ? Image.network(user.avatarUrl.trim(), fit: BoxFit.cover)
                    : Container(
                        color: tokens.brandContainer,
                        child: Center(
                          child: Text(
                            name.isEmpty ? 'P' : name[0].toUpperCase(),
                            style: PravaTypography.caption.copyWith(
                              color: tokens.brandContent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PravaTypography.bodyMedium.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${user.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PravaTypography.caption.copyWith(color: secondary),
                  ),
                ],
              ),
            ),
            if (user.isVerified)
              Icon(
                CupertinoIcons.check_mark_circled_solid,
                color: tokens.brandPrimary,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}

class _HashtagSuggestionTile extends StatelessWidget {
  const _HashtagSuggestionTile({
    required this.tag,
    required this.primary,
    required this.secondary,
    required this.onTap,
  });

  final SmartHashtagResult tag;
  final Color primary;
  final Color secondary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tokens.brandContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.number,
                color: tokens.brandContent,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '#${tag.tag}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PravaTypography.bodyMedium.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              tag.postCount.toString(),
              style: PravaTypography.caption.copyWith(
                color: secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerIcon extends StatelessWidget {
  const _ComposerIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: tokens.backgroundSurfaceSubtle,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: tokens.brandContent),
            const SizedBox(width: 6),
            Text(
              label,
              style: PravaTypography.caption.copyWith(
                color: tokens.brandContent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposeFab extends StatelessWidget {
  const _ComposeFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tokens.brandPrimary,
          ),
          child: Icon(
            Icons.edit_note_rounded,
            color: tokens.textInverse,
            size: 34,
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.primary,
    required this.secondary,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onMore,
    required this.onFollow,
    required this.onAuthorTap,
    required this.showFollow,
    required this.pendingFollow,
    required this.timeAgo,
    required this.bodySpan,
  });

  final FeedPost post;
  final Color primary;
  final Color secondary;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onMore;
  final VoidCallback onFollow;
  final VoidCallback onAuthorTap;
  final bool showFollow;
  final bool pendingFollow;
  final String timeAgo;
  final TextSpan bodySpan;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final surface = tokens.backgroundSurface;
    final border = tokens.borderSubtle;

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onAuthorTap,
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: tokens.brandContainer,
                    backgroundImage: post.author.avatarUrl.trim().isNotEmpty
                        ? NetworkImage(post.author.avatarUrl.trim())
                        : null,
                    child: post.author.avatarUrl.trim().isNotEmpty
                        ? null
                        : Text(
                            post.author.displayName.isNotEmpty
                                ? post.author.displayName[0].toUpperCase()
                                : '@',
                            style: PravaTypography.titleSmall.copyWith(
                              color: tokens.brandContent,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onAuthorTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                post.author.displayName.isNotEmpty
                                    ? post.author.displayName
                                    : post.author.username,
                                style: PravaTypography.bodyMedium.copyWith(
                                  color: primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${post.author.username} - $timeAgo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PravaTypography.caption.copyWith(
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (showFollow)
                  _FollowButton(
                    following: post.followed,
                    pending: pendingFollow,
                    onTap: onFollow,
                  ),
                CupertinoButton(
                  minimumSize: const Size(34, 34),
                  padding: const EdgeInsets.only(left: 6),
                  onPressed: onMore,
                  child: Icon(
                    CupertinoIcons.ellipsis,
                    color: tokens.iconSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
            if ((post.recommendationExplanation ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              _RecommendationPill(text: post.recommendationExplanation!),
            ],
            const SizedBox(height: 12),
            RichText(text: bodySpan, textWidthBasis: TextWidthBasis.parent),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ActionButton(
                  icon: post.liked
                      ? CupertinoIcons.heart_fill
                      : CupertinoIcons.heart,
                  label: post.likeCount.toString(),
                  active: post.liked,
                  activeColor: tokens.socialLikeActive,
                  onTap: onLike,
                ),
                _ActionButton(
                  icon: CupertinoIcons.chat_bubble_2,
                  label: post.commentCount.toString(),
                  active: false,
                  activeColor: tokens.brandContent,
                  onTap: onComment,
                ),
                _ActionButton(
                  icon: CupertinoIcons.arrowshape_turn_up_right,
                  label: post.shareCount.toString(),
                  active: false,
                  activeColor: tokens.brandContent,
                  onTap: onShare,
                ),
                _ActionButton(
                  icon: CupertinoIcons.eye,
                  label: post.readCount.toString(),
                  active: false,
                  activeColor: tokens.brandContent,
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final color = active ? activeColor : tokens.iconSecondary;

    return CupertinoButton(
      minimumSize: const Size(40, 40),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onPressed: onTap,
      child: Row(
        children: [
          AnimatedScale(
            scale: active ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 180),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: PravaTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationPill extends StatelessWidget {
  const _RecommendationPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.brandContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.sparkles, size: 13, color: tokens.brandContent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PravaTypography.caption.copyWith(
                color: tokens.brandContent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.following,
    required this.pending,
    required this.onTap,
  });

  final bool following;
  final bool pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final border = tokens.borderSubtle;

    return GestureDetector(
      onTap: pending ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: following ? Colors.transparent : tokens.brandPrimary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: following ? border : Colors.transparent),
        ),
        child: pending
            ? CupertinoActivityIndicator(
                color: following ? tokens.brandPrimary : tokens.textInverse,
              )
            : Text(
                following ? 'Following' : 'Follow',
                style: PravaTypography.caption.copyWith(
                  color: following ? tokens.textTertiary : tokens.textInverse,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class _CommentSheet extends StatefulWidget {
  const _CommentSheet({
    required this.post,
    required this.feedService,
    required this.onCommentAdded,
    required this.onAuthorTap,
  });

  final FeedPost post;
  final FeedService feedService;
  final VoidCallback onCommentAdded;
  final ValueChanged<FeedAuthor> onAuthorTap;

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<FeedComment> _comments = <FeedComment>[];
  final Set<String> _pendingCommentLikes = <String>{};

  bool _loading = true;
  bool _sending = false;
  FeedComment? _replyingTo;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final data = await widget.feedService.listComments(widget.post.id);
      if (!mounted) return;
      setState(() {
        _comments
          ..clear()
          ..addAll(data);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _sendComment() async {
    if (_sending) return;

    final body = _controller.text.trim();
    if (body.isEmpty) return;

    HapticFeedback.selectionClick();
    setState(() => _sending = true);

    try {
      final parent = _replyingTo;
      final comment = await widget.feedService.addComment(
        widget.post.id,
        body,
        parentCommentId: parent?.id,
      );
      if (!mounted) return;

      setState(() {
        _comments.add(comment);
        if (parent != null) {
          parent.replyCount += 1;
        }
        _replyingTo = null;
        _controller.clear();
        _sending = false;
      });

      widget.onCommentAdded();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
    }
  }

  Future<void> _toggleCommentLike(FeedComment comment) async {
    if (_pendingCommentLikes.contains(comment.id)) return;

    HapticFeedback.selectionClick();
    _pendingCommentLikes.add(comment.id);
    final previousLiked = comment.liked;
    final previousCount = comment.likeCount;

    setState(() {
      comment.liked = !comment.liked;
      comment.likeCount += comment.liked ? 1 : -1;
      if (comment.likeCount < 0) comment.likeCount = 0;
    });

    try {
      final result = await widget.feedService.toggleCommentLike(
        widget.post.id,
        comment.id,
      );
      if (!mounted) return;
      setState(() {
        comment.liked = result['liked'] == true;
        comment.likeCount = _readInt(result['likeCount'], comment.likeCount);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        comment.liked = previousLiked;
        comment.likeCount = previousCount;
      });
    } finally {
      _pendingCommentLikes.remove(comment.id);
    }
  }

  int _readInt(dynamic value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  void _startReply(FeedComment comment) {
    HapticFeedback.selectionClick();
    setState(() => _replyingTo = comment);
    _focusNode.requestFocus();
  }

  String _formatTimeAgo(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final weeks = diff.inDays ~/ 7;
    if (weeks < 5) return '${weeks}w';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$month/$day/${value.year}';
  }

  List<Widget> _buildCommentTree({
    required Color primary,
    required Color secondary,
  }) {
    final replies = <String, List<FeedComment>>{};
    final roots = <FeedComment>[];
    final byId = <String, FeedComment>{
      for (final comment in _comments) comment.id: comment,
    };

    for (final comment in _comments) {
      final parentId = comment.parentCommentId;
      if (parentId == null || parentId.isEmpty) {
        roots.add(comment);
      } else {
        var rootId = parentId;
        var parent = byId[rootId];
        while (parent?.parentCommentId != null &&
            parent!.parentCommentId!.isNotEmpty) {
          rootId = parent.parentCommentId!;
          parent = byId[rootId];
        }
        replies.putIfAbsent(rootId, () => <FeedComment>[]).add(comment);
      }
    }

    roots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final bucket in replies.values) {
      bucket.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    List<Widget> branch(FeedComment comment) {
      final children = replies[comment.id] ?? <FeedComment>[];
      return [
        _CommentTile(
          comment: comment,
          depth: 0,
          replyToAuthor: null,
          primary: primary,
          secondary: secondary,
          timeAgo: _formatTimeAgo(comment.createdAt),
          onAuthorTap: () => widget.onAuthorTap(comment.author),
          onMentionTap: widget.onAuthorTap,
          onLike: () => _toggleCommentLike(comment),
          onReply: () => _startReply(comment),
        ),
        for (final child in children)
          _CommentTile(
            comment: child,
            depth: 1,
            replyToAuthor: byId[child.parentCommentId]?.author,
            primary: primary,
            secondary: secondary,
            timeAgo: _formatTimeAgo(child.createdAt),
            onAuthorTap: () => widget.onAuthorTap(child.author),
            onMentionTap: widget.onAuthorTap,
            onLike: () => _toggleCommentLike(child),
            onReply: () => _startReply(child),
          ),
      ];
    }

    return [for (final root in roots) ...branch(root)];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final surface = tokens.backgroundSurfaceRaised;
    final primary = tokens.textPrimary;
    final secondary = tokens.textSecondary;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: secondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Comments',
                    style: PravaTypography.titleSmall.copyWith(color: primary),
                  ),
                  const Spacer(),
                  Text(
                    '@${widget.post.author.username}',
                    style: PravaTypography.caption.copyWith(color: secondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CupertinoActivityIndicator(),
                )
              else if (_comments.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'No comments yet',
                      style: PravaTypography.bodyMedium.copyWith(
                        color: secondary,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 4),
                    children: _buildCommentTree(
                      primary: primary,
                      secondary: secondary,
                    ),
                  ),
                ),
              if (_replyingTo != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.brandContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Replying to @${_replyingTo!.author.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PravaTypography.caption.copyWith(
                            color: tokens.brandContent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _replyingTo = null),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            CupertinoIcons.xmark,
                            size: 14,
                            color: tokens.brandContent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PravaInput(
                      controller: _controller,
                      hint: _replyingTo == null
                          ? 'Add a comment'
                          : 'Write a reply',
                      focusNode: _focusNode,
                      fieldType: PravaInputFieldType.comment,
                      variant: PravaInputVariant.comment,
                      size: PravaInputSize.small,
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 10),
                  CupertinoButton(
                    padding: const EdgeInsets.all(12),
                    color: tokens.brandPrimary,
                    borderRadius: BorderRadius.circular(16),
                    onPressed: _sending ? null : _sendComment,
                    child: _sending
                        ? CupertinoActivityIndicator(color: tokens.textInverse)
                        : Icon(
                            CupertinoIcons.arrow_up_circle_fill,
                            color: tokens.textInverse,
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.depth,
    required this.replyToAuthor,
    required this.primary,
    required this.secondary,
    required this.timeAgo,
    required this.onAuthorTap,
    required this.onMentionTap,
    required this.onLike,
    required this.onReply,
  });

  final FeedComment comment;
  final int depth;
  final FeedAuthor? replyToAuthor;
  final Color primary;
  final Color secondary;
  final String timeAgo;
  final VoidCallback onAuthorTap;
  final ValueChanged<FeedAuthor> onMentionTap;
  final VoidCallback onLike;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final indent = depth > 2 ? 56.0 : depth * 24.0;
    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAuthorTap,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: tokens.brandContainer,
              backgroundImage: comment.author.avatarUrl.trim().isNotEmpty
                  ? NetworkImage(comment.author.avatarUrl.trim())
                  : null,
              child: comment.author.avatarUrl.trim().isNotEmpty
                  ? null
                  : Text(
                      comment.author.username.isNotEmpty
                          ? comment.author.username[0].toUpperCase()
                          : '@',
                      style: PravaTypography.caption.copyWith(
                        color: tokens.brandContent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onAuthorTap,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          '@${comment.author.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PravaTypography.caption.copyWith(
                            color: primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeAgo,
                        style: PravaTypography.caption.copyWith(
                          color: secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                _CommentBody(
                  body: comment.body,
                  primary: primary,
                  replyToAuthor: replyToAuthor,
                  onMentionTap: onMentionTap,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onLike,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          right: 14,
                          top: 4,
                          bottom: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              comment.liked
                                  ? CupertinoIcons.heart_fill
                                  : CupertinoIcons.heart,
                              size: 15,
                              color: comment.liked
                                  ? tokens.socialLikeActive
                                  : secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              comment.likeCount.toString(),
                              style: PravaTypography.caption.copyWith(
                                color: comment.liked
                                    ? tokens.socialLikeActive
                                    : secondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onReply,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Text(
                          'Reply',
                          style: PravaTypography.caption.copyWith(
                            color: secondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentBody extends StatefulWidget {
  const _CommentBody({
    required this.body,
    required this.primary,
    required this.replyToAuthor,
    required this.onMentionTap,
  });

  final String body;
  final Color primary;
  final FeedAuthor? replyToAuthor;
  final ValueChanged<FeedAuthor> onMentionTap;

  @override
  State<_CommentBody> createState() => _CommentBodyState();
}

class _CommentBodyState extends State<_CommentBody> {
  TapGestureRecognizer? _mentionRecognizer;

  @override
  void initState() {
    super.initState();
    _syncRecognizer();
  }

  @override
  void didUpdateWidget(covariant _CommentBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.replyToAuthor?.id != widget.replyToAuthor?.id) {
      _syncRecognizer();
    }
  }

  @override
  void dispose() {
    _mentionRecognizer?.dispose();
    super.dispose();
  }

  void _syncRecognizer() {
    _mentionRecognizer?.dispose();
    final author = widget.replyToAuthor;
    _mentionRecognizer = author == null
        ? null
        : (TapGestureRecognizer()..onTap = () => widget.onMentionTap(author));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final author = widget.replyToAuthor;
    final body = widget.body.trim();
    if (author == null) {
      return Text(
        body,
        style: PravaTypography.bodyMedium.copyWith(color: widget.primary),
      );
    }

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '@${author.username} ',
            recognizer: _mentionRecognizer,
            style: PravaTypography.bodyMedium.copyWith(
              color: tokens.linkDefault,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(
            text: body,
            style: PravaTypography.bodyMedium.copyWith(color: widget.primary),
          ),
        ],
      ),
    );
  }
}

class _PostControlsSheet extends StatefulWidget {
  const _PostControlsSheet({
    required this.post,
    required this.feedService,
    required this.onPostRemoved,
    required this.onFeedbackSaved,
  });

  final FeedPost post;
  final FeedService feedService;
  final VoidCallback onPostRemoved;
  final VoidCallback onFeedbackSaved;

  @override
  State<_PostControlsSheet> createState() => _PostControlsSheetState();
}

class _PostControlsSheetState extends State<_PostControlsSheet> {
  FeedExplanation? _explanation;
  bool _loadingWhy = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadWhy();
  }

  Future<void> _loadWhy() async {
    try {
      final explanation = await widget.feedService.explainPost(widget.post.id);
      if (!mounted) return;
      setState(() {
        _explanation = explanation;
        _loadingWhy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingWhy = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_saving) return;
    HapticFeedback.selectionClick();
    setState(() => _saving = true);
    try {
      await action();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      PravaToast.show(
        context,
        message: 'Could not update feed',
        type: PravaToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final primary = tokens.textPrimary;
    final secondary = tokens.textSecondary;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.84,
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: tokens.backgroundSurfaceRaised,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: secondary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Feed controls',
              style: PravaTypography.titleSmall.copyWith(
                color: primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tokens.backgroundSurfaceSubtle,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _loadingWhy
                  ? const Center(child: CupertinoActivityIndicator())
                  : Row(
                      children: [
                        Icon(
                          CupertinoIcons.sparkles,
                          color: tokens.brandContent,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _explanation?.explanation ??
                                widget.post.recommendationExplanation ??
                                'Recommended for you',
                            style: PravaTypography.bodyMedium.copyWith(
                              color: primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            _FeedActionRow(
              icon: CupertinoIcons.hand_thumbsup_fill,
              title: 'Show more like this',
              onTap: () => _run(() async {
                await widget.feedService.showMore(widget.post.id);
                widget.onFeedbackSaved();
              }),
            ),
            _FeedActionRow(
              icon: CupertinoIcons.hand_thumbsdown_fill,
              title: 'Show fewer like this',
              onTap: () => _run(() async {
                await widget.feedService.showFewer(widget.post.id);
                widget.onFeedbackSaved();
              }),
            ),
            _FeedActionRow(
              icon: CupertinoIcons.eye_slash_fill,
              title: 'Not interested',
              onTap: () => _run(() async {
                await widget.feedService.markNotInterested(widget.post.id);
                widget.onPostRemoved();
              }),
            ),
            _FeedActionRow(
              icon: CupertinoIcons.xmark_circle_fill,
              title: 'Hide this post',
              destructive: true,
              onTap: () => _run(() async {
                await widget.feedService.hidePost(widget.post.id);
                widget.onPostRemoved();
              }),
            ),
            if (_saving)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Center(child: CupertinoActivityIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeedActionRow extends StatelessWidget {
  const _FeedActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final color = destructive ? tokens.statusError : tokens.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: PravaTypography.bodyMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedStudioSheet extends StatefulWidget {
  const _FeedStudioSheet({
    required this.feedService,
    required this.preferences,
    required this.topics,
    required this.interests,
    required this.customFeeds,
    required this.onPreferencesChanged,
    required this.onTopicsChanged,
    required this.onOpenTopic,
    required this.onOpenCustomFeed,
    required this.onReset,
  });

  final FeedService feedService;
  final FeedPreferences? preferences;
  final List<FeedTopic> topics;
  final List<FeedInterest> interests;
  final List<CustomFeed> customFeeds;
  final ValueChanged<FeedPreferences> onPreferencesChanged;
  final Future<void> Function() onTopicsChanged;
  final ValueChanged<String> onOpenTopic;
  final ValueChanged<CustomFeed> onOpenCustomFeed;
  final Future<void> Function() onReset;

  @override
  State<_FeedStudioSheet> createState() => _FeedStudioSheetState();
}

class _FeedStudioSheetState extends State<_FeedStudioSheet> {
  late FeedPreferences _preferences =
      widget.preferences ??
      FeedPreferences(
        lens: 'balanced',
        discoveryIntensity: 0.22,
        friendPriority: 0.35,
        latestPriority: 0.15,
        reduceReposts: false,
        reduceSensitiveContent: true,
        preferredLanguages: const <String>[],
        mutedKeywords: const <String>[],
      );
  final TextEditingController _customName = TextEditingController();
  String? _customTopic;
  bool _saving = false;

  static const _lenses = <MapEntry<String, String>>[
    MapEntry('balanced', 'Balanced'),
    MapEntry('latest', 'Latest'),
    MapEntry('deep_reads', 'Deep reads'),
    MapEntry('conversations', 'Talks'),
    MapEntry('friends_first', 'Friends'),
    MapEntry('discover', 'Discover'),
    MapEntry('professional', 'Pro'),
  ];

  @override
  void dispose() {
    _customName.dispose();
    super.dispose();
  }

  Future<void> _savePreferences(Map<String, dynamic> patch) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final updated = await widget.feedService.updatePreferences(patch);
      if (!mounted) return;
      setState(() {
        _preferences = updated;
        _saving = false;
      });
      widget.onPreferencesChanged(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  Future<void> _toggleTopic(FeedTopic topic) async {
    await widget.feedService.followTopic(topic.topic, !topic.followed);
    await widget.onTopicsChanged();
    if (mounted) setState(() {});
  }

  Future<void> _muteTopic(FeedTopic topic) async {
    await widget.feedService.snoozeTopic(topic.topic);
    await widget.onTopicsChanged();
    if (mounted) setState(() {});
  }

  Future<void> _saveCustomFeed() async {
    final name = _customName.text.trim();
    final topic =
        _customTopic ??
        (widget.topics.isNotEmpty ? widget.topics.first.topic : '');
    if (name.isEmpty || topic.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.feedService.saveCustomFeed(
        name: name,
        includeTopics: [topic],
      );
      _customName.clear();
      await widget.onTopicsChanged();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final primary = tokens.textPrimary;
    final secondary = tokens.textSecondary;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        decoration: BoxDecoration(
          color: tokens.backgroundSurfaceRaised,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: secondary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Feed Studio',
                  style: PravaTypography.titleSmall.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (_saving) const CupertinoActivityIndicator(),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  _StudioSection(
                    title: 'Lens',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final lens in _lenses)
                          _StudioChip(
                            label: lens.value,
                            active: _preferences.lens == lens.key,
                            onTap: () => _savePreferences({'lens': lens.key}),
                          ),
                      ],
                    ),
                  ),
                  _StudioSlider(
                    label: 'Discovery',
                    value: _preferences.discoveryIntensity,
                    onChanged: (value) =>
                        _savePreferences({'discoveryIntensity': value}),
                  ),
                  _StudioSlider(
                    label: 'Friends priority',
                    value: _preferences.friendPriority,
                    onChanged: (value) =>
                        _savePreferences({'friendPriority': value}),
                  ),
                  _StudioSlider(
                    label: 'Latest priority',
                    value: _preferences.latestPriority,
                    onChanged: (value) =>
                        _savePreferences({'latestPriority': value}),
                  ),
                  _StudioSwitch(
                    label: 'Reduce reposts',
                    value: _preferences.reduceReposts,
                    onChanged: (value) =>
                        _savePreferences({'reduceReposts': value}),
                  ),
                  _StudioSwitch(
                    label: 'Reduce sensitive content',
                    value: _preferences.reduceSensitiveContent,
                    onChanged: (value) =>
                        _savePreferences({'reduceSensitiveContent': value}),
                  ),
                  _StudioSection(
                    title: 'Topics',
                    child: Column(
                      children: [
                        for (final topic in widget.topics.take(8))
                          _TopicControlRow(
                            topic: topic,
                            onOpen: () => widget.onOpenTopic(topic.topic),
                            onFollow: () => _toggleTopic(topic),
                            onSnooze: () => _muteTopic(topic),
                          ),
                      ],
                    ),
                  ),
                  if (widget.interests.isNotEmpty)
                    _StudioSection(
                      title: 'Your interests',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final interest in widget.interests.take(10))
                            _StudioChip(
                              label: '#${interest.topic}',
                              active: interest.score > 0,
                              onTap: () => widget.onOpenTopic(interest.topic),
                            ),
                        ],
                      ),
                    ),
                  _StudioSection(
                    title: 'Custom feeds',
                    child: Column(
                      children: [
                        for (final feed in widget.customFeeds.take(5))
                          _CustomFeedRow(
                            feed: feed,
                            onOpen: () => widget.onOpenCustomFeed(feed),
                          ),
                        const SizedBox(height: 8),
                        PravaInput(
                          controller: _customName,
                          hint: 'New feed name',
                          fieldType: PravaInputFieldType.name,
                          variant: PravaInputVariant.settings,
                          prefixIcon: const Icon(CupertinoIcons.square_list),
                          showClearButton: true,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final topic in widget.topics.take(6))
                              _StudioChip(
                                label: '#${topic.topic}',
                                active: _customTopic == topic.topic,
                                onTap: () =>
                                    setState(() => _customTopic = topic.topic),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          color: tokens.brandPrimary,
                          borderRadius: BorderRadius.circular(16),
                          onPressed: _saving ? null : _saveCustomFeed,
                          child: Text(
                            'Save custom feed',
                            style: PravaTypography.buttonMedium.copyWith(
                              color: tokens.textInverse,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    onPressed: _saving
                        ? null
                        : () async {
                            setState(() => _saving = true);
                            try {
                              await widget.onReset();
                              if (context.mounted) Navigator.of(context).pop();
                            } finally {
                              if (mounted) setState(() => _saving = false);
                            }
                          },
                    child: Text(
                      'Reset personalization',
                      style: PravaTypography.bodyMedium.copyWith(
                        color: tokens.statusError,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioSection extends StatelessWidget {
  const _StudioSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: PravaTypography.caption.copyWith(
              color: tokens.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _StudioChip extends StatelessWidget {
  const _StudioChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? tokens.brandPrimary : tokens.backgroundSurfaceSubtle,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: PravaTypography.caption.copyWith(
            color: active ? tokens.textInverse : tokens.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StudioSlider extends StatelessWidget {
  const _StudioSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: PravaTypography.caption.copyWith(
                color: tokens.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: CupertinoSlider(
              value: value.clamp(0, 1),
              onChanged: onChanged,
              activeColor: tokens.brandPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioSwitch extends StatelessWidget {
  const _StudioSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: PravaTypography.bodyMedium.copyWith(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: tokens.brandPrimary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TopicControlRow extends StatelessWidget {
  const _TopicControlRow({
    required this.topic,
    required this.onOpen,
    required this.onFollow,
    required this.onSnooze,
  });

  final FeedTopic topic;
  final VoidCallback onOpen;
  final VoidCallback onFollow;
  final VoidCallback onSnooze;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onOpen,
              child: Text(
                '#${topic.topic}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PravaTypography.bodyMedium.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          CupertinoButton(
            minimumSize: const Size(32, 32),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: onFollow,
            child: Text(
              topic.followed ? 'Following' : 'Follow',
              style: PravaTypography.caption.copyWith(
                color: tokens.brandContent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          CupertinoButton(
            minimumSize: const Size(32, 32),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            onPressed: onSnooze,
            child: Icon(
              CupertinoIcons.moon_zzz_fill,
              color: tokens.iconSecondary,
              size: 17,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomFeedRow extends StatelessWidget {
  const _CustomFeedRow({required this.feed, required this.onOpen});

  final CustomFeed feed;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.rectangle_stack_fill,
              color: tokens.brandContent,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                feed.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PravaTypography.bodyMedium.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({
    required this.post,
    required this.feedService,
    required this.chatService,
    required this.platform,
    required this.onShareUpdated,
  });

  final FeedPost post;
  final FeedService feedService;
  final ChatService chatService;
  final PlatformBridgeService platform;
  final ValueChanged<int> onShareUpdated;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final List<ConversationSummary> _conversations = <ConversationSummary>[];
  bool _loading = true;
  bool _sending = false;

  String get _shareText =>
      'Post from @${widget.post.author.username}: ${widget.post.body}';

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final data = await widget.chatService.listConversations();
      if (!mounted) return;
      setState(() {
        _conversations
          ..clear()
          ..addAll(data);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _shareToConversation(ConversationSummary convo) async {
    if (_sending) return;

    setState(() => _sending = true);

    try {
      await widget.chatService.sendMessage(
        conversationId: convo.id,
        body: _shareText,
      );

      final response = await widget.feedService.sharePost(widget.post.id);
      if (!mounted) return;

      if (response['shareCount'] is int) {
        widget.onShareUpdated(response['shareCount'] as int);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _shareOutsideApp() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await widget.platform.shareText(_shareText);
      final response = await widget.feedService.sharePost(widget.post.id);
      if (!mounted) return;
      if (response['shareCount'] is int) {
        widget.onShareUpdated(response['shareCount'] as int);
      }
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      PravaToast.show(
        context,
        message: 'Share failed',
        type: PravaToastType.error,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final surface = tokens.backgroundSurfaceRaised;
    final primary = tokens.textPrimary;
    final secondary = tokens.textSecondary;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: secondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Share post',
                  style: PravaTypography.titleSmall.copyWith(color: primary),
                ),
                const Spacer(),
                Icon(
                  CupertinoIcons.paperplane_fill,
                  color: tokens.brandContent,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _sending ? null : _shareOutsideApp,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.backgroundSurfaceSubtle,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.square_arrow_up,
                      color: tokens.brandContent,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Share with another app',
                        style: PravaTypography.bodyMedium.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      CupertinoIcons.chevron_right,
                      color: secondary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Chats',
                style: PravaTypography.caption.copyWith(
                  color: secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CupertinoActivityIndicator(),
              )
            else if (_conversations.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No chats available yet',
                  style: PravaTypography.bodyMedium.copyWith(color: secondary),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _conversations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final convo = _conversations[index];
                    return InkWell(
                      onTap: _sending
                          ? null
                          : () => _shareToConversation(convo),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tokens.backgroundSurfaceSubtle,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: tokens.brandContainer,
                              child: Text(
                                convo.title.isNotEmpty
                                    ? convo.title[0].toUpperCase()
                                    : 'C',
                                style: PravaTypography.caption.copyWith(
                                  color: tokens.brandContent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    convo.title,
                                    style: PravaTypography.bodyMedium.copyWith(
                                      color: primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    convo.lastMessageBody,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: PravaTypography.caption.copyWith(
                                      color: secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              CupertinoIcons.chevron_right,
                              color: secondary,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            if (_sending)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: CupertinoActivityIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
