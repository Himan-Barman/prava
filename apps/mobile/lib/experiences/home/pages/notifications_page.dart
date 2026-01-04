import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../navigation/prava_navigator.dart';
import '../../../services/notification_center.dart';
import '../../../services/notification_service.dart';
import '../../../ui-system/background.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';
import '../../../ui-system/typography.dart';
import '../tabs/profile/public_profile_page.dart';

enum NotificationFilter {
  all,
  mentions,
  follows,
  posts,
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _service = NotificationService();
  final NotificationCenter _center = NotificationCenter.instance;
  final ScrollController _controller = ScrollController();

  final List<NotificationItem> _items = <NotificationItem>[];

  StreamSubscription<NotificationItem>? _subscription;

  bool _loading = true;
  bool _loadingMore = false;
  bool _markingAll = false;
  String? _cursor;
  NotificationFilter _filter = NotificationFilter.all;

  @override
  void initState() {
    super.initState();
    _center.ensureInitialized();
    _subscription = _center.stream.listen(_onRealtimeNotification);
    _controller.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    try {
      final page = await _service.fetchNotifications(limit: 25);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _cursor = page.nextCursor;
        _loading = false;
      });
      _center.unreadCount.value = page.unreadCount;
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      PravaToast.show(
        context,
        message: 'Unable to load notifications',
        type: PravaToastType.error,
      );
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _service.fetchNotifications(
        limit: 25,
        cursor: _cursor,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh() async {
    await _loadInitial();
  }

  void _onScroll() {
    if (_controller.position.pixels >
        _controller.position.maxScrollExtent - 180) {
      _loadMore();
    }
  }

  void _onRealtimeNotification(NotificationItem item) {
    if (!mounted) return;
    if (_items.any((it) => it.id == item.id)) return;
    setState(() {
      _items.insert(0, item);
    });
  }

  bool _matchesFilter(NotificationItem item) {
    switch (_filter) {
      case NotificationFilter.mentions:
        return item.type == 'mention';
      case NotificationFilter.follows:
        return item.type == 'follow';
      case NotificationFilter.posts:
        return item.type == 'like' ||
            item.type == 'comment' ||
            item.type == 'share';
      case NotificationFilter.all:
      default:
        return true;
    }
  }

  List<NotificationItem> get _visibleItems =>
      _items.where(_matchesFilter).toList();

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      await _service.markAllRead();
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          _items[i] = _items[i].copyWith(readAt: DateTime.now());
        }
        _markingAll = false;
      });
      _center.applyReadAll();
    } catch (_) {
      if (!mounted) return;
      setState(() => _markingAll = false);
      PravaToast.show(
        context,
        message: 'Unable to mark all read',
        type: PravaToastType.error,
      );
    }
  }

  Future<void> _markRead(NotificationItem item) async {
    if (!item.isUnread) return;
    setState(() {
      final index = _items.indexWhere((it) => it.id == item.id);
      if (index != -1) {
        _items[index] =
            _items[index].copyWith(readAt: DateTime.now());
      }
    });
    _center.applyRead();
    try {
      await _service.markRead(item.id);
    } catch (_) {
      // ignore failure to avoid UI jumpiness
    }
  }

  void _openProfile(NotificationItem item) {
    final actor = item.actor;
    if (actor == null || actor.id.isEmpty) return;
    PravaNavigator.push(
      context,
      PublicProfilePage(userId: actor.id),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 4) return '${weeks}w';
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '${time.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final secondary =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;
    final border =
        isDark ? PravaColors.darkBorderSubtle : PravaColors.lightBorderSubtle;

    final items = _visibleItems;

    return Scaffold(
      body: Stack(
        children: [
          _NotificationsBackdrop(isDark: isDark),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Row(
                    children: [
                      Text(
                        'Notifications',
                        style: PravaTypography.h2.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      ValueListenableBuilder<int>(
                        valueListenable: _center.unreadCount,
                        builder: (_, count, __) {
                          return _UnreadPill(
                            count: count,
                            isDark: isDark,
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _markingAll ? null : _markAllRead,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white10
                                : Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: border),
                          ),
                          child: _markingAll
                              ? const CupertinoActivityIndicator(
                                  radius: 8,
                                )
                              : Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.check_mark_circled,
                                      size: 14,
                                      color: PravaColors.accentPrimary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Mark all read',
                                      style: PravaTypography.caption.copyWith(
                                        color: PravaColors.accentPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _FilterRow(
                    filter: _filter,
                    onChanged: (next) {
                      HapticFeedback.selectionClick();
                      setState(() => _filter = next);
                    },
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: _loading
                        ? const Center(
                            child: CupertinoActivityIndicator(radius: 12),
                          )
                        : items.isEmpty
                            ? _EmptyState(primary: primary)
                            : ListView.separated(
                                controller: _controller,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                physics: const BouncingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics(),
                                ),
                                itemCount:
                                    items.length + (_loadingMore ? 1 : 0),
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  if (index >= items.length) {
                                    return const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 12),
                                      child: Center(
                                        child: CupertinoActivityIndicator(
                                          radius: 10,
                                        ),
                                      ),
                                    );
                                  }

                                  final item = items[index];
                                  return _NotificationCard(
                                    item: item,
                                    primary: primary,
                                    secondary: secondary,
                                    isDark: isDark,
                                    timeLabel: _formatTime(item.createdAt),
                                    onTap: () {
                                      _markRead(item);
                                      _openProfile(item);
                                    },
                                  );
                                },
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

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.filter,
    required this.onChanged,
  });

  final NotificationFilter filter;
  final ValueChanged<NotificationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterChip(
          label: 'All',
          active: filter == NotificationFilter.all,
          onTap: () => onChanged(NotificationFilter.all),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Mentions',
          active: filter == NotificationFilter.mentions,
          onTap: () => onChanged(NotificationFilter.mentions),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Follows',
          active: filter == NotificationFilter.follows,
          onTap: () => onChanged(NotificationFilter.follows),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Posts',
          active: filter == NotificationFilter.posts,
          onTap: () => onChanged(NotificationFilter.posts),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveText = isDark
        ? PravaColors.darkTextTertiary
        : PravaColors.lightTextTertiary;
    final inactiveFill =
        isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? PravaColors.accentPrimary.withValues(alpha: 0.2)
              : inactiveFill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                active ? PravaColors.accentPrimary : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: PravaTypography.caption.copyWith(
            color: active
                ? PravaColors.accentPrimary
                : inactiveText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _UnreadPill extends StatelessWidget {
  const _UnreadPill({
    required this.count,
    required this.isDark,
  });

  final int count;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final label = count == 0 ? 'All caught up' : '$count unread';
    final color = count == 0
        ? (isDark ? Colors.white24 : Colors.black26)
        : PravaColors.accentPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: count == 0 ? color : PravaColors.accentPrimary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: PravaTypography.caption.copyWith(
              color: count == 0 ? color : PravaColors.accentPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.primary,
    required this.secondary,
    required this.isDark,
    required this.timeLabel,
    required this.onTap,
  });

  final NotificationItem item;
  final Color primary;
  final Color secondary;
  final bool isDark;
  final String timeLabel;
  final VoidCallback onTap;

  Color _accentForType(String type) {
    switch (type) {
      case 'follow':
        return const Color(0xFF5B8CFF);
      case 'comment':
        return const Color(0xFF2EC4B6);
      case 'share':
        return const Color(0xFFFFB703);
      case 'mention':
        return const Color(0xFF845EC2);
      case 'like':
        return const Color(0xFFFF6B6B);
      default:
        return PravaColors.accentPrimary;
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'follow':
        return CupertinoIcons.person_add;
      case 'comment':
        return CupertinoIcons.chat_bubble_2_fill;
      case 'share':
        return CupertinoIcons.arrowshape_turn_up_right_fill;
      case 'mention':
        return CupertinoIcons.tag_fill;
      case 'like':
        return CupertinoIcons.heart_fill;
      default:
        return CupertinoIcons.bell_fill;
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.95);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.06);
    final accent = _accentForType(item.type);
    final actor = item.actor;
    final avatarLabel = actor?.displayName.isNotEmpty == true
        ? actor!.displayName.substring(0, 1).toUpperCase()
        : actor?.username.isNotEmpty == true
            ? actor!.username.substring(0, 1).toUpperCase()
            : 'N';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: accent.withValues(alpha: 0.2),
                    child: Icon(
                      _iconForType(item.type),
                      size: 18,
                      color: accent,
                    ),
                  ),
                  if (actor != null)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor:
                            isDark ? Colors.black : Colors.white,
                        child: CircleAvatar(
                          radius: 8,
                          backgroundColor: accent.withValues(alpha: 0.2),
                          child: Text(
                            avatarLabel,
                            style: PravaTypography.caption.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: PravaTypography.body.copyWith(
                              color: primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (item.isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: PravaColors.accentPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          timeLabel,
                          style: PravaTypography.caption.copyWith(
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.body,
                      style: PravaTypography.bodySmall.copyWith(
                        color: secondary,
                      ),
                    ),
                    if (actor != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '@${actor.username}',
                        style: PravaTypography.caption.copyWith(
                          color: PravaColors.accentPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.primary});

  final Color primary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 120, 16, 16),
      children: [
        Center(
          child: Icon(
            CupertinoIcons.bell_slash,
            size: 40,
            color: primary.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'No notifications yet',
            style: PravaTypography.bodyLarge.copyWith(
              color: primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationsBackdrop extends StatelessWidget {
  const _NotificationsBackdrop({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return PravaBackground(isDark: isDark);
  }
}
