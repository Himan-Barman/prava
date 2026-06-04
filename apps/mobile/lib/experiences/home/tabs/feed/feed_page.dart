import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../../ui-system/colors.dart';
import '../../../../ui-system/typography.dart';
import '../../../../ui-system/feedback/prava_toast.dart';
import '../../../../ui-system/feedback/toast_type.dart';
import '../../../../ui-system/skeleton/feed_skeleton.dart';
import '../../../../services/feed_service.dart';
import '../../../../services/feed_realtime.dart';
import '../../../../services/chat_service.dart';
import '../../../../services/local_time_service.dart';
import '../../../../services/platform_bridge_service.dart';
import '../../../../core/storage/secure_store.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final FeedService _feedService = FeedService();
  final FeedRealtime _realtime = FeedRealtime();
  final ChatService _chatService = ChatService();
  final LocalTimeService _time = const LocalTimeService();
  final PlatformBridgeService _platform = PlatformBridgeService();
  final SecureStore _store = SecureStore();

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _composerController = TextEditingController();

  final Set<String> _pendingLikes = <String>{};
  final Set<String> _pendingFollows = <String>{};

  List<FeedPost> _posts = <FeedPost>[];
  List<FeedTag> _tags = <FeedTag>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _loadingTags = false;
  bool _posting = false;
  bool _hasMore = true;
  int _segmentIndex = 0;
  String? _userId;
  String? _selectedTag;

  static const int _pageSize = 20;
  String _currentFeedMode() =>
      _segmentIndex == 1 ? 'following' : 'for-you';

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
    _composerController.dispose();
    _realtime.disconnect();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    _userId = await _store.getUserId();
    await Future.wait([
      _loadFeed(showSkeleton: true),
      _loadTags(),
    ]);
    await _realtime.connect(_handleRealtimeEvent);
  }

  Future<void> _switchSegment(int value) async {
    if (value == _segmentIndex) return;

    HapticFeedback.selectionClick();
    if (mounted) {
      setState(() {
        _segmentIndex = value;
        _posts = [];
        _hasMore = true;
      });
    }

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    await _loadFeed(showSkeleton: true);
  }

  Future<void> _loadFeed({bool showSkeleton = false}) async {
    if (showSkeleton && mounted) {
      setState(() => _loading = true);
    }

    try {
      final data = await _feedService.listFeed(
        limit: _pageSize,
        mode: _currentFeedMode(),
        tag: _selectedTag,
      );
      if (!mounted) return;

      setState(() {
        _posts = data;
        _hasMore = data.length >= _pageSize;
        _loading = false;
      });
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
      final results = await Future.wait([
        _feedService.listFeed(
          limit: _pageSize,
          mode: _currentFeedMode(),
          tag: _selectedTag,
        ),
        _feedService.listTags(limit: 16),
      ]);
      if (!mounted) return;

      setState(() {
        final posts = results[0] as List<FeedPost>;
        _posts = posts;
        _tags = results[1] as List<FeedTag>;
        _hasMore = posts.length >= _pageSize;
      });
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
      final before = _posts.last.createdAt;
      final data = await _feedService.listFeed(
        before: before,
        limit: _pageSize,
        mode: _currentFeedMode(),
        tag: _selectedTag,
      );

      if (!mounted) return;

      setState(() {
        _posts = [..._posts, ...data];
        _hasMore = data.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadTags() async {
    if (_loadingTags) return;
    setState(() => _loadingTags = true);
    try {
      final tags = await _feedService.listTags(limit: 16);
      if (!mounted) return;
      setState(() {
        _tags = tags;
        _loadingTags = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingTags = false);
    }
  }

  Future<void> _selectTag(String? tag) async {
    final normalized = tag?.trim().replaceFirst('#', '');
    if (_selectedTag == normalized) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedTag = normalized == null || normalized.isEmpty
          ? null
          : normalized;
      _posts = <FeedPost>[];
      _hasMore = true;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    await _loadFeed(showSkeleton: true);
  }

  Future<void> _createPost() async {
    if (_posting) return;

    final body = _composerController.text.trim();
    final words = _wordCount(body);
    if (body.isEmpty) {
      PravaToast.show(
        context,
        message: 'Write something before posting',
        type: PravaToastType.warning,
      );
      return;
    }
    if (words > 200) {
      PravaToast.show(
        context,
        message: 'Posts must stay under 200 words',
        type: PravaToastType.warning,
      );
      return;
    }

    HapticFeedback.selectionClick();
    setState(() => _posting = true);

    try {
      final post = await _feedService.createPost(body);
      if (!mounted) return;

      setState(() {
        final selectedTag = _selectedTag;
        if (selectedTag == null || post.hashtags.contains(selectedTag)) {
          _posts = [post, ..._posts];
        }
        _composerController.clear();
        _posting = false;
      });
      unawaited(_loadTags());
    } catch (_) {
      if (!mounted) return;
      setState(() => _posting = false);
      PravaToast.show(
        context,
        message: 'Post failed. Try again.',
        type: PravaToastType.error,
      );
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
    if (_segmentIndex == 1) return;
    final post = FeedPost.fromJson(payload);
    final selectedTag = _selectedTag;
    if (selectedTag != null && !post.hashtags.contains(selectedTag)) {
      return;
    }
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
        if (result['likeCount'] is int) {
          post.likeCount = result['likeCount'] as int;
        }
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
            setState(() {
              post.shareCount = count;
            });
          },
        );
      },
    );
  }

  TextSpan _buildPostSpan(
    String text,
    TextStyle base,
    TextStyle highlight,
  ) {
    final regex =
        RegExp(r'(@[a-zA-Z0-9_]{2,32}|#[a-zA-Z0-9_]{2,32})');
    final spans = <TextSpan>[];
    var start = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, match.start),
            style: base,
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: highlight,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;
    final surface =
        isDark ? PravaColors.darkBgSurface : PravaColors.lightBgSurface;

    final visiblePosts = _posts;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: CupertinoSlidingSegmentedControl<int>(
            groupValue: _segmentIndex,
            backgroundColor: surface,
            thumbColor: PravaColors.accentPrimary,
            children: {
              0: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'For you',
                  style: PravaTypography.label.copyWith(
                    color: _segmentIndex == 0 ? Colors.white : secondary,
                  ),
                ),
              ),
              1: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Following',
                  style: PravaTypography.label.copyWith(
                    color: _segmentIndex == 1 ? Colors.white : secondary,
                  ),
                ),
              ),
            },
            onValueChanged: (value) {
              if (value == null) return;
              _switchSegment(value);
            },
          ),
        ),
        _TagRail(
          tags: _tags,
          selectedTag: _selectedTag,
          loading: _loadingTags,
          onSelect: (tag) {
            _selectTag(tag);
          },
        ),
        Expanded(
          child: _loading
              ? const FeedSkeleton()
              : RefreshIndicator(
                  onRefresh: _refreshFeed,
                  color: PravaColors.accentPrimary,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _ComposerCard(
                          controller: _composerController,
                          onPost: _createPost,
                          isPosting: _posting,
                          wordCount: _wordCount,
                        ),
                      ),
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
                                    style: PravaTypography.bodyLarge.copyWith(
                                      color: primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Be the first to share something premium.',
                                    textAlign: TextAlign.center,
                                    style: PravaTypography.body.copyWith(
                                      color: secondary,
                                    ),
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
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                              child: _PostCard(
                                post: post,
                                isDark: isDark,
                                primary: primary,
                                secondary: secondary,
                                onLike: () => _toggleLike(post),
                                onComment: () => _openComments(post),
                                onShare: () => _openShare(post),
                                onFollow: () => _toggleFollow(post),
                                showFollow: post.author.id != _userId,
                                pendingFollow:
                                    _pendingFollows.contains(post.author.id),
                                timeAgo: _formatTimeAgo(post.createdAt),
                                bodySpan: _buildPostSpan(
                                  post.body,
                                  PravaTypography.body.copyWith(
                                    color: primary,
                                  ),
                                  PravaTypography.body.copyWith(
                                    color: PravaColors.accentPrimary,
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
                          child: const Padding(
                            padding: EdgeInsets.only(bottom: 24, top: 8),
                            child: Center(
                              child: CupertinoActivityIndicator(
                                color: PravaColors.accentPrimary,
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
    );
  }
}

class _TagRail extends StatelessWidget {
  const _TagRail({
    required this.tags,
    required this.selectedTag,
    required this.loading,
    required this.onSelect,
  });

  final List<FeedTag> tags;
  final String? selectedTag;
  final bool loading;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border =
        isDark ? PravaColors.darkBorderSubtle : PravaColors.lightBorderSubtle;
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;

    if (loading && tags.isEmpty) {
      return const SizedBox(height: 38);
    }

    final visibleTags = tags.take(12).toList();
    if (visibleTags.isEmpty && selectedTag == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        itemCount: visibleTags.length + (selectedTag == null ? 0 : 1),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (selectedTag != null && index == 0) {
            return _TagChip(
              label: '#$selectedTag',
              selected: true,
              count: null,
              border: border,
              secondary: secondary,
              onTap: () => onSelect(null),
            );
          }
          final tag = visibleTags[index - (selectedTag == null ? 0 : 1)];
          return _TagChip(
            label: '#${tag.tag}',
            selected: tag.tag == selectedTag,
            count: tag.postCount,
            border: border,
            secondary: secondary,
            onTap: () => onSelect(tag.tag),
          );
        },
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    required this.count,
    required this.border,
    required this.secondary,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final int? count;
  final Color border;
  final Color secondary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? PravaColors.accentPrimary.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? PravaColors.accentPrimary : border,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: PravaTypography.caption.copyWith(
                color: selected ? PravaColors.accentPrimary : secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text(
                count.toString(),
                style: PravaTypography.caption.copyWith(color: secondary),
              ),
            ],
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(
                CupertinoIcons.xmark,
                size: 12,
                color: PravaColors.accentPrimary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComposerCard extends StatelessWidget {
  const _ComposerCard({
    required this.controller,
    required this.onPost,
    required this.isPosting,
    required this.wordCount,
  });

  final TextEditingController controller;
  final VoidCallback onPost;
  final bool isPosting;
  final int Function(String value) wordCount;

  void _insertToken(String token) {
    HapticFeedback.selectionClick();
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final updated = text.replaceRange(start, end, token);
    controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        isDark ? PravaColors.darkBgSurface : PravaColors.lightBgSurface;
    final border =
        isDark ? PravaColors.darkBorderSubtle : PravaColors.lightBorderSubtle;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: PravaColors.accentPrimary.withValues(alpha: 0.16),
                child: const Icon(
                  CupertinoIcons.person_fill,
                  color: PravaColors.accentPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 2,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  style: PravaTypography.body.copyWith(color: primary),
                  decoration: InputDecoration(
                    hintText: 'Share something premium... ',
                    hintStyle: PravaTypography.body.copyWith(color: secondary),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ComposerIcon(
                        icon: CupertinoIcons.at,
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
                valueListenable: controller,
                builder: (context, value, child) {
                  final text = value.text.trim();
                  final count = wordCount(text);
                  final tooLong = count > 200 || text.length > 1600;
                  final canPost = text.isNotEmpty && !tooLong;
                  return Row(
                    children: [
                      Text(
                        '$count/200',
                        style: PravaTypography.caption.copyWith(
                          color: tooLong
                              ? PravaColors.error
                              : secondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        color: canPost
                            ? PravaColors.accentPrimary
                            : PravaColors.accentPrimary.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(18),
                        onPressed: isPosting || !canPost ? null : onPost,
                        child: isPosting
                            ? const CupertinoActivityIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                'Post',
                                style: PravaTypography.button.copyWith(
                                  color: Colors.white,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: PravaColors.accentPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: PravaTypography.caption.copyWith(
                color: PravaColors.accentPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onFollow,
    required this.showFollow,
    required this.pendingFollow,
    required this.timeAgo,
    required this.bodySpan,
  });

  final FeedPost post;
  final bool isDark;
  final Color primary;
  final Color secondary;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onFollow;
  final bool showFollow;
  final bool pendingFollow;
  final String timeAgo;
  final TextSpan bodySpan;

  @override
  Widget build(BuildContext context) {
    final surface =
        isDark ? PravaColors.darkBgSurface : PravaColors.lightBgSurface;
    final border =
        isDark ? PravaColors.darkBorderSubtle : PravaColors.lightBorderSubtle;

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
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      PravaColors.accentPrimary.withValues(alpha: 0.16),
                  backgroundImage: post.author.avatarUrl.trim().isNotEmpty
                      ? NetworkImage(post.author.avatarUrl.trim())
                      : null,
                  child: post.author.avatarUrl.trim().isNotEmpty
                      ? null
                      : Text(
                          post.author.displayName.isNotEmpty
                              ? post.author.displayName[0].toUpperCase()
                              : '@',
                          style: PravaTypography.h3.copyWith(
                            color: PravaColors.accentPrimary,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
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
                              style: PravaTypography.body.copyWith(
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
                if (showFollow)
                  _FollowButton(
                    following: post.followed,
                    pending: pendingFollow,
                    onTap: onFollow,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            RichText(
              text: bodySpan,
              textWidthBasis: TextWidthBasis.parent,
            ),
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
                  onTap: onLike,
                ),
                _ActionButton(
                  icon: CupertinoIcons.chat_bubble_2,
                  label: post.commentCount.toString(),
                  active: false,
                  onTap: onComment,
                ),
                _ActionButton(
                  icon: CupertinoIcons.arrowshape_turn_up_right,
                  label: post.shareCount.toString(),
                  active: false,
                  onTap: onShare,
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
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? PravaColors.accentPrimary : Colors.grey;

    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          AnimatedScale(
            scale: active ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 180),
            child: Icon(
              icon,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: PravaTypography.caption.copyWith(color: color),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border =
        isDark ? PravaColors.darkBorderSubtle : PravaColors.lightBorderSubtle;

    return GestureDetector(
      onTap: pending ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: following
              ? Colors.transparent
              : PravaColors.accentPrimary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: following ? border : Colors.transparent,
          ),
        ),
        child: pending
            ? CupertinoActivityIndicator(
                color:
                    following ? PravaColors.accentPrimary : Colors.white,
              )
            : Text(
                following ? 'Following' : 'Follow',
                style: PravaTypography.caption.copyWith(
                  color: following ? border : Colors.white,
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
  });

  final FeedPost post;
  final FeedService feedService;
  final VoidCallback onCommentAdded;

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final TextEditingController _controller = TextEditingController();
  final List<FeedComment> _comments = <FeedComment>[];

  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
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
      final comment =
          await widget.feedService.addComment(widget.post.id, body);
      if (!mounted) return;

      setState(() {
        _comments.add(comment);
        _controller.clear();
        _sending = false;
      });

      widget.onCommentAdded();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        isDark ? PravaColors.darkBgElevated : PravaColors.lightBgElevated;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
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
                style: PravaTypography.h3.copyWith(color: primary),
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No comments yet',
                style: PravaTypography.body.copyWith(color: secondary),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _comments.length,
                itemBuilder: (context, index) {
                  final comment = _comments[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              PravaColors.accentPrimary.withValues(alpha: 0.16),
                          child: Text(
                            comment.author.displayName.isNotEmpty
                                ? comment.author.displayName[0].toUpperCase()
                                : '@',
                            style: PravaTypography.caption.copyWith(
                              color: PravaColors.accentPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comment.author.displayName.isNotEmpty
                                    ? comment.author.displayName
                                    : comment.author.username,
                                style: PravaTypography.caption.copyWith(
                                  color: primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                comment.body,
                                style: PravaTypography.body.copyWith(
                                  color: primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 3,
                  style: PravaTypography.body.copyWith(color: primary),
                  decoration: InputDecoration(
                    hintText: 'Add a comment',
                    hintStyle: PravaTypography.body.copyWith(color: secondary),
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.black12,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              CupertinoButton(
                padding: const EdgeInsets.all(12),
                color: PravaColors.accentPrimary,
                borderRadius: BorderRadius.circular(16),
                onPressed: _sending ? null : _sendComment,
                child: _sending
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : const Icon(
                        CupertinoIcons.arrow_up_circle_fill,
                        color: Colors.white,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        isDark ? PravaColors.darkBgElevated : PravaColors.lightBgElevated;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;

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
                style: PravaTypography.h3.copyWith(color: primary),
              ),
              const Spacer(),
              const Icon(
                CupertinoIcons.paperplane_fill,
                color: PravaColors.accentPrimary,
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
                color: isDark ? Colors.white10 : Colors.black12,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.square_arrow_up,
                    color: PravaColors.accentPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Share with another app',
                      style: PravaTypography.body.copyWith(
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
                style: PravaTypography.body.copyWith(color: secondary),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _conversations.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
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
                        color: isDark
                            ? Colors.white10
                            : Colors.black12,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                PravaColors.accentPrimary.withValues(alpha: 0.16),
                            child: Text(
                              convo.title.isNotEmpty
                                  ? convo.title[0].toUpperCase()
                                  : 'C',
                              style: PravaTypography.caption.copyWith(
                                color: PravaColors.accentPrimary,
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
                                  style: PravaTypography.body.copyWith(
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
