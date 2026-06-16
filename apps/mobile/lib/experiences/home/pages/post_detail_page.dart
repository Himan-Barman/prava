import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/feed_service.dart';
import '../../../ui-system/background.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';
import '../../../ui-system/typography.dart';

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({
    super.key,
    required this.postId,
    this.highlightCommentId,
  });

  final String postId;
  final String? highlightCommentId;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final FeedService _feedService = FeedService();

  FeedPost? _post;
  List<FeedComment> _comments = <FeedComment>[];
  bool _loading = true;
  bool _pendingLike = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final post = await _feedService.fetchPost(widget.postId);
      final comments = await _feedService.listComments(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = post;
        _comments = comments;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      PravaToast.show(
        context,
        message: 'Unable to open post',
        type: PravaToastType.error,
      );
    }
  }

  Future<void> _toggleLike() async {
    final post = _post;
    if (post == null || _pendingLike) return;

    HapticFeedback.selectionClick();
    final previousLiked = post.liked;
    final previousCount = post.likeCount;

    setState(() {
      _pendingLike = true;
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
        _pendingLike = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        post.liked = previousLiked;
        post.likeCount = previousCount;
        _pendingLike = false;
      });
      PravaToast.show(
        context,
        message: 'Could not update like',
        type: PravaToastType.error,
      );
    }
  }

  int _readInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tokens = context.pravaColors;
    final primary = tokens.textPrimary;
    final secondary = tokens.textSecondary;
    final border = tokens.borderSubtle;

    return Scaffold(
      body: Stack(
        children: [
          PravaBackground(isDark: isDark),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                  child: Text(
                    'Post',
                    style: PravaTypography.titleLarge.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CupertinoActivityIndicator(radius: 12),
                        )
                      : _post == null
                      ? _PostMissingState(
                          primary: primary,
                          secondary: secondary,
                        )
                      : RefreshIndicator(
                          color: tokens.brandPrimary,
                          onRefresh: _load,
                          child: ListView(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                            children: [
                              _PostDetailCard(
                                post: _post!,
                                primary: primary,
                                secondary: secondary,
                                border: border,
                                timeAgo: _formatTimeAgo(_post!.createdAt),
                                pendingLike: _pendingLike,
                                onLike: _toggleLike,
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Comments',
                                style: PravaTypography.titleSmall.copyWith(
                                  color: primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_comments.isEmpty)
                                _CommentEmptyState(secondary: secondary)
                              else
                                ..._comments.map(
                                  (comment) => _CommentPreview(
                                    comment: comment,
                                    primary: primary,
                                    secondary: secondary,
                                    border: border,
                                    timeAgo: _formatTimeAgo(comment.createdAt),
                                    highlighted:
                                        widget.highlightCommentId == comment.id,
                                  ),
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

class _PostDetailCard extends StatelessWidget {
  const _PostDetailCard({
    required this.post,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.timeAgo,
    required this.pendingLike,
    required this.onLike,
  });

  final FeedPost post;
  final Color primary;
  final Color secondary;
  final Color border;
  final String timeAgo;
  final bool pendingLike;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final surface = tokens.backgroundSurface;
    final body = post.body.trim().isEmpty ? 'Text post' : post.body.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _FeedAvatar(author: post.author, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author.displayName.isNotEmpty
                          ? post.author.displayName
                          : post.author.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PravaTypography.bodyMedium.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '@${post.author.username} - $timeAgo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PravaTypography.caption.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style: PravaTypography.bodyLarge.copyWith(
              color: primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _DetailAction(
                icon: post.liked
                    ? CupertinoIcons.heart_fill
                    : CupertinoIcons.heart,
                label: post.likeCount.toString(),
                active: post.liked,
                pending: pendingLike,
                onTap: onLike,
              ),
              _DetailAction(
                icon: CupertinoIcons.chat_bubble_2,
                label: post.commentCount.toString(),
                active: false,
                pending: false,
                onTap: () {},
              ),
              _DetailAction(
                icon: CupertinoIcons.arrowshape_turn_up_right,
                label: post.shareCount.toString(),
                active: false,
                pending: false,
                onTap: () {},
              ),
              _DetailAction(
                icon: CupertinoIcons.eye,
                label: post.readCount.toString(),
                active: false,
                pending: false,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailAction extends StatelessWidget {
  const _DetailAction({
    required this.icon,
    required this.label,
    required this.active,
    required this.pending,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final color = active ? tokens.socialLikeActive : tokens.iconSecondary;
    return CupertinoButton(
      minimumSize: const Size(38, 38),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      onPressed: pending ? null : onTap,
      child: Row(
        children: [
          pending
              ? const CupertinoActivityIndicator(radius: 8)
              : Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: PravaTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentPreview extends StatelessWidget {
  const _CommentPreview({
    required this.comment,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.timeAgo,
    required this.highlighted,
  });

  final FeedComment comment;
  final Color primary;
  final Color secondary;
  final Color border;
  final String timeAgo;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final fill = highlighted ? tokens.brandContainer : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: highlighted ? tokens.brandPrimary : border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FeedAvatar(author: comment.author, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '@${comment.author.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PravaTypography.caption.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo,
                      style: PravaTypography.caption.copyWith(color: secondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.body,
                  style: PravaTypography.bodyMedium.copyWith(color: primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedAvatar extends StatelessWidget {
  const _FeedAvatar({required this.author, required this.size});

  final FeedAuthor author;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pravaColors;
    final avatarUrl = author.avatarUrl.trim();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: tokens.brandContainer,
      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
      child: avatarUrl.isNotEmpty
          ? null
          : Text(
              author.username.isNotEmpty
                  ? author.username.substring(0, 1).toUpperCase()
                  : '@',
              style: PravaTypography.bodyMedium.copyWith(
                color: tokens.brandContent,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class _CommentEmptyState extends StatelessWidget {
  const _CommentEmptyState({required this.secondary});

  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          'No comments yet',
          style: PravaTypography.bodyMedium.copyWith(color: secondary),
        ),
      ),
    );
  }
}

class _PostMissingState extends StatelessWidget {
  const _PostMissingState({required this.primary, required this.secondary});

  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.doc_text_search, size: 42, color: secondary),
            const SizedBox(height: 12),
            Text(
              'Post unavailable',
              style: PravaTypography.titleSmall.copyWith(
                color: primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
