import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../services/friend_connections_service.dart';
import '../../../../ui-system/background.dart';
import '../../../../ui-system/colors.dart';
import '../../../../ui-system/feedback/prava_toast.dart';
import '../../../../ui-system/feedback/toast_type.dart';
import '../../../../ui-system/typography.dart';

enum ProfileConnectionKind { followers, following }

typedef ProfileConnectionOpenProfile =
    void Function(BuildContext context, FriendConnectionItem item);

class ProfilePostContentItem {
  const ProfilePostContentItem({
    required this.body,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.mentions,
    required this.hashtags,
  });

  final String body;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final List<String> mentions;
  final List<String> hashtags;
}

class ProfilePostListPage extends StatelessWidget {
  const ProfilePostListPage({
    super.key,
    required this.title,
    required this.posts,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  final String title;
  final List<ProfilePostContentItem> posts;
  final String emptyTitle;
  final String emptySubtitle;

  String _formatCount(int value) {
    if (value >= 1000000) {
      final short = (value / 1000000).toStringAsFixed(
        value % 1000000 == 0 ? 0 : 1,
      );
      return '${short}M';
    }
    if (value >= 1000) {
      final short = (value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1);
      return '${short}K';
    }
    return value.toString();
  }

  String _formatRelativeTime(DateTime value) {
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
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;
    final border = isDark
        ? PravaColors.darkBorderSubtle
        : PravaColors.lightBorderSubtle;

    return Scaffold(
      body: Stack(
        children: [
          PravaBackground(isDark: isDark),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileContentHeader(title: title, primary: primary),
                Expanded(
                  child: posts.isEmpty
                      ? _ProfileContentEmptyState(
                          icon: CupertinoIcons.text_bubble,
                          title: emptyTitle,
                          subtitle: emptySubtitle,
                          primary: primary,
                          secondary: secondary,
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                          itemBuilder: (context, index) {
                            final post = posts[index];
                            return _ProfileContentPostRow(
                              post: post,
                              timestamp: _formatRelativeTime(post.createdAt),
                              primary: primary,
                              secondary: secondary,
                              border: border,
                              formatCount: _formatCount,
                            );
                          },
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 0),
                          itemCount: posts.length,
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

class ProfileConnectionsPage extends StatefulWidget {
  const ProfileConnectionsPage({
    super.key,
    required this.userId,
    required this.kind,
    required this.title,
    required this.onOpenProfile,
  });

  final String userId;
  final ProfileConnectionKind kind;
  final String title;
  final ProfileConnectionOpenProfile onOpenProfile;

  @override
  State<ProfileConnectionsPage> createState() => _ProfileConnectionsPageState();
}

class _ProfileConnectionsPageState extends State<ProfileConnectionsPage> {
  final FriendConnectionsService _service = FriendConnectionsService();

  bool _loading = true;
  bool _visible = true;
  List<FriendConnectionItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _type {
    return switch (widget.kind) {
      ProfileConnectionKind.followers => 'followers',
      ProfileConnectionKind.following => 'following',
    };
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _service.fetchProfileConnectionList(
        userId: widget.userId,
        type: _type,
        limit: 100,
      );
      if (!mounted) return;
      setState(() {
        _visible = response.visible;
        _items = response.items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      PravaToast.show(
        context,
        message: 'Unable to load ${widget.title.toLowerCase()}',
        type: PravaToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;
    final border = isDark
        ? PravaColors.darkBorderSubtle
        : PravaColors.lightBorderSubtle;

    return Scaffold(
      body: Stack(
        children: [
          PravaBackground(isDark: isDark),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileContentHeader(title: widget.title, primary: primary),
                Expanded(
                  child: RefreshIndicator(
                    color: PravaColors.accentPrimary,
                    onRefresh: _load,
                    child: _loading
                        ? const Center(
                            child: CupertinoActivityIndicator(radius: 12),
                          )
                        : !_visible
                        ? _ProfileContentEmptyState(
                            icon: CupertinoIcons.lock_fill,
                            title: '${widget.title} are private',
                            subtitle:
                                'This profile owner limits who can see this list.',
                            primary: primary,
                            secondary: secondary,
                          )
                        : _items.isEmpty
                        ? _ProfileContentEmptyState(
                            icon: CupertinoIcons.person_2,
                            title: 'No ${widget.title.toLowerCase()} yet',
                            subtitle:
                                '${widget.title} will appear here when available.',
                            primary: primary,
                            secondary: secondary,
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return _ProfileConnectionRow(
                                item: item,
                                primary: primary,
                                secondary: secondary,
                                border: border,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  widget.onOpenProfile(context, item);
                                },
                              );
                            },
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemCount: _items.length,
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

class _ProfileContentHeader extends StatelessWidget {
  const _ProfileContentHeader({required this.title, required this.primary});

  final String title;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: PravaTypography.h2.copyWith(
          color: primary,
          letterSpacing: 0,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ProfileContentEmptyState extends StatelessWidget {
  const _ProfileContentEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.secondary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 110, 24, 24),
      children: [
        Icon(icon, size: 38, color: secondary),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: PravaTypography.h3.copyWith(
            color: primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: PravaTypography.body.copyWith(color: secondary),
        ),
      ],
    );
  }
}

class _ProfileContentPostRow extends StatelessWidget {
  const _ProfileContentPostRow({
    required this.post,
    required this.timestamp,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.formatCount,
  });

  final ProfilePostContentItem post;
  final String timestamp;
  final Color primary;
  final Color secondary;
  final Color border;
  final String Function(int) formatCount;

  @override
  Widget build(BuildContext context) {
    final body = post.body.trim().isEmpty ? 'Text post' : post.body.trim();
    final tags = <String>[
      ...post.hashtags.map((tag) => tag.startsWith('#') ? tag : '#$tag'),
      ...post.mentions.map((tag) => tag.startsWith('@') ? tag : '@$tag'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            body,
            style: PravaTypography.bodyLarge.copyWith(
              color: primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.take(8).map((tag) {
                return Text(
                  tag,
                  style: PravaTypography.caption.copyWith(
                    color: PravaColors.accentPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '$timestamp - ${formatCount(post.likeCount)} likes - '
            '${formatCount(post.commentCount)} comments',
            style: PravaTypography.bodySmall.copyWith(color: secondary),
          ),
        ],
      ),
    );
  }
}

class _ProfileConnectionRow extends StatelessWidget {
  const _ProfileConnectionRow({
    required this.item,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.onTap,
  });

  final FriendConnectionItem item;
  final Color primary;
  final Color secondary;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final user = item.user;
    final name = user.displayName.isNotEmpty ? user.displayName : user.username;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: border)),
        ),
        child: Row(
          children: [
            _ProfileConnectionAvatar(user: user),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PravaTypography.bodyLarge.copyWith(
                            color: primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (user.isVerified) ...[
                        const SizedBox(width: 5),
                        const Icon(
                          CupertinoIcons.check_mark_circled_solid,
                          color: PravaColors.accentPrimary,
                          size: 15,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${user.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PravaTypography.bodySmall.copyWith(color: secondary),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, color: secondary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ProfileConnectionAvatar extends StatelessWidget {
  const _ProfileConnectionAvatar({required this.user});

  final FriendConnectionUser user;

  @override
  Widget build(BuildContext context) {
    final name =
        (user.displayName.isNotEmpty ? user.displayName : user.username).trim();

    return SizedBox(
      width: 52,
      height: 52,
      child: ClipOval(
        child: user.avatarUrl.trim().isNotEmpty
            ? Image.network(user.avatarUrl, fit: BoxFit.cover)
            : Container(
                color: PravaColors.accentPrimary.withValues(alpha: 0.16),
                child: Center(
                  child: Text(
                    name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: PravaTypography.h3.copyWith(
                      color: PravaColors.accentPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
