import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../navigation/prava_navigator.dart';
import '../../../services/notification_center.dart';
import '../../../services/notification_permission_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/settings_service.dart';
import '../../../ui-system/background.dart';
import '../../../ui-system/colors.dart';
import '../../../ui-system/feedback/prava_toast.dart';
import '../../../ui-system/feedback/toast_type.dart';
import '../../../ui-system/typography.dart';
import '../tabs/profile/public_profile_page.dart';

enum NotificationFilter { all, mentions, follows, posts }

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _service = NotificationService();
  final NotificationPermissionService _permissionService =
      NotificationPermissionService();
  final SettingsService _settingsService = SettingsService();
  final NotificationCenter _center = NotificationCenter.instance;
  final ScrollController _controller = ScrollController();

  final List<NotificationItem> _items = <NotificationItem>[];

  StreamSubscription<NotificationItem>? _subscription;

  bool _loading = true;
  bool _loadingMore = false;
  bool _markingAll = false;
  bool _permissionLoading = false;
  bool _settingsSaving = false;
  String? _cursor;
  NotificationFilter _filter = NotificationFilter.all;
  SettingsState _settings = SettingsState.defaults();
  NotificationPermissionSnapshot _nativePermission =
      NotificationPermissionSnapshot.unavailable;

  @override
  void initState() {
    super.initState();
    _center.ensureInitialized();
    _subscription = _center.stream.listen(_onRealtimeNotification);
    _controller.addListener(_onScroll);
    _loadNotificationControls();
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
    await Future.wait([_loadInitial(), _loadNotificationControls()]);
  }

  Future<void> _loadNotificationControls() async {
    if (mounted) {
      setState(() => _permissionLoading = true);
    }

    final localSettings = await _settingsService.loadLocal();
    if (mounted) {
      setState(() => _settings = localSettings);
    }

    var settings = localSettings;
    try {
      settings = await _settingsService.fetchRemote();
      await _settingsService.saveLocal(settings);
    } catch (_) {
      // Local settings keep the controls responsive when remote settings fail.
    }

    final permission = await _permissionService.getStatus();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _nativePermission = permission;
      _permissionLoading = false;
    });
  }

  Future<void> _requestNotificationPermission() async {
    if (_permissionLoading) return;
    HapticFeedback.selectionClick();
    setState(() => _permissionLoading = true);
    final permission = await _permissionService.requestPermission();
    if (!mounted) return;
    setState(() {
      _nativePermission = permission;
      _permissionLoading = false;
    });
    if (permission.canDeliver && !_settings.pushNotifications) {
      await _updateNotificationSettings(
        _settings.copyWith(pushNotifications: true),
      );
    }
  }

  Future<void> _updateNotificationSettings(SettingsState next) async {
    if (_settingsSaving) return;
    HapticFeedback.selectionClick();
    final previous = _settings;
    setState(() {
      _settings = next;
      _settingsSaving = true;
    });
    try {
      await _settingsService.saveLocal(next);
      final remote = await _settingsService.saveRemote(next);
      await _settingsService.saveLocal(remote);
      if (!mounted) return;
      setState(() {
        _settings = remote;
        _settingsSaving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _settings = previous;
        _settingsSaving = false;
      });
      PravaToast.show(
        context,
        message: 'Unable to update notification settings',
        type: PravaToastType.error,
      );
    }
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
        _items[index] = _items[index].copyWith(readAt: DateTime.now());
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
    PravaNavigator.push(context, PublicProfilePage(userId: actor.id));
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
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final secondary = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;
    final border = isDark
        ? PravaColors.darkBorderSubtle
        : PravaColors.lightBorderSubtle;
    final surface = isDark
        ? PravaColors.darkBgSurface
        : PravaColors.lightBgSurface;

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
                  child: ValueListenableBuilder<int>(
                    valueListenable: _center.unreadCount,
                    builder: (_, count, __) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Notifications',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: PravaTypography.h2.copyWith(
                                    color: primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (count > 0)
                                _MarkAllReadButton(
                                  marking: _markingAll,
                                  border: border,
                                  isDark: isDark,
                                  onTap: _markingAll ? null : _markAllRead,
                                ),
                            ],
                          ),
                          if (count > 0) ...[
                            const SizedBox(height: 8),
                            _UnreadPill(count: count, isDark: isDark),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: ValueListenableBuilder<int>(
                    valueListenable: _center.unreadCount,
                    builder: (_, count, __) {
                      return _NotificationControlPanel(
                        permission: _nativePermission,
                        settings: _settings,
                        unreadCount: count,
                        loading: _permissionLoading,
                        saving: _settingsSaving,
                        primary: primary,
                        secondary: secondary,
                        border: border,
                        surface: surface,
                        isDark: isDark,
                        onRequestPermission: _requestNotificationPermission,
                        onPushChanged: (value) => _updateNotificationSettings(
                          _settings.copyWith(pushNotifications: value),
                        ),
                        onEmailChanged: (value) => _updateNotificationSettings(
                          _settings.copyWith(emailNotifications: value),
                        ),
                        onSoundChanged: (value) => _updateNotificationSettings(
                          _settings.copyWith(inAppSounds: value),
                        ),
                        onHapticsChanged: (value) =>
                            _updateNotificationSettings(
                              _settings.copyWith(inAppHaptics: value),
                            ),
                      );
                    },
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
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            itemCount: items.length + (_loadingMore ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              if (index >= items.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
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

class _MarkAllReadButton extends StatelessWidget {
  const _MarkAllReadButton({
    required this.marking,
    required this.border,
    required this.isDark,
    required this.onTap,
  });

  final bool marking;
  final Color border;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: marking
            ? const CupertinoActivityIndicator(radius: 8)
            : const Icon(
                Icons.done_all_rounded,
                size: 23,
                color: PravaColors.accentPrimary,
              ),
      ),
    );
  }
}

class _NotificationControlPanel extends StatelessWidget {
  const _NotificationControlPanel({
    required this.permission,
    required this.settings,
    required this.unreadCount,
    required this.loading,
    required this.saving,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.surface,
    required this.isDark,
    required this.onRequestPermission,
    required this.onPushChanged,
    required this.onEmailChanged,
    required this.onSoundChanged,
    required this.onHapticsChanged,
  });

  final NotificationPermissionSnapshot permission;
  final SettingsState settings;
  final int unreadCount;
  final bool loading;
  final bool saving;
  final Color primary;
  final Color secondary;
  final Color border;
  final Color surface;
  final bool isDark;
  final VoidCallback onRequestPermission;
  final ValueChanged<bool> onPushChanged;
  final ValueChanged<bool> onEmailChanged;
  final ValueChanged<bool> onSoundChanged;
  final ValueChanged<bool> onHapticsChanged;

  Color get _permissionColor {
    if (permission.canDeliver) return PravaColors.success;
    if (permission.permission == NativeNotificationPermission.denied) {
      return PravaColors.error;
    }
    return PravaColors.warning;
  }

  String get _actionLabel {
    if (permission.canDeliver) return 'Refresh';
    if (permission.permission == NativeNotificationPermission.denied) {
      return 'Retry';
    }
    return 'Allow';
  }

  @override
  Widget build(BuildContext context) {
    final accent = _permissionColor;
    final inactive = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);

    return Container(
      padding: const EdgeInsets.all(12),
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
              Icon(Icons.notifications_active_rounded, color: accent, size: 31),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notification system',
                      style: PravaTypography.body.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      permission.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PravaTypography.caption.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(label: permission.label, color: accent),
            ],
          ),
          const SizedBox(height: 12),
          _PermissionRow(
            loading: loading,
            actionLabel: _actionLabel,
            alert: permission.alert,
            badge: permission.badge,
            sound: permission.sound,
            primary: primary,
            secondary: secondary,
            border: border,
            fill: inactive,
            onTap: onRequestPermission,
          ),
          const SizedBox(height: 10),
          _NotificationSummaryLine(
            realtime: settings.inAppSounds || settings.inAppHaptics,
            unreadCount: unreadCount,
            primary: primary,
            secondary: secondary,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: _DeliveryToggle(
                      icon: Icons.notifications_rounded,
                      title: 'Push',
                      subtitle: permission.canDeliver ? 'Device' : 'Blocked',
                      value: settings.pushNotifications,
                      enabled: !saving,
                      primary: primary,
                      secondary: secondary,
                      border: border,
                      fill: inactive,
                      onChanged: onPushChanged,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _DeliveryToggle(
                      icon: Icons.email_rounded,
                      title: 'Email',
                      subtitle: 'Digest',
                      value: settings.emailNotifications,
                      enabled: !saving,
                      primary: primary,
                      secondary: secondary,
                      border: border,
                      fill: inactive,
                      onChanged: onEmailChanged,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _DeliveryToggle(
                      icon: Icons.volume_up_rounded,
                      title: 'Sound',
                      subtitle: 'In-app',
                      value: settings.inAppSounds,
                      enabled: !saving,
                      primary: primary,
                      secondary: secondary,
                      border: border,
                      fill: inactive,
                      onChanged: onSoundChanged,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _DeliveryToggle(
                      icon: Icons.vibration_rounded,
                      title: 'Haptics',
                      subtitle: 'Feedback',
                      value: settings.inAppHaptics,
                      enabled: !saving,
                      primary: primary,
                      secondary: secondary,
                      border: border,
                      fill: inactive,
                      onChanged: onHapticsChanged,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: PravaTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.loading,
    required this.actionLabel,
    required this.alert,
    required this.badge,
    required this.sound,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.fill,
    required this.onTap,
  });

  final bool loading;
  final String actionLabel;
  final bool alert;
  final bool badge;
  final bool sound;
  final Color primary;
  final Color secondary;
  final Color border;
  final Color fill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabledCount = [alert, badge, sound].where((item) => item).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.shield_rounded,
            color: PravaColors.accentPrimary,
            size: 24,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'System permission - $enabledCount/3',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PravaTypography.caption.copyWith(
                color: primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: loading ? null : onTap,
            child: Container(
              height: 30,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: PravaColors.accentPrimary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: loading
                  ? const CupertinoActivityIndicator(
                      radius: 8,
                      color: Colors.white,
                    )
                  : Text(
                      actionLabel,
                      style: PravaTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationSummaryLine extends StatelessWidget {
  const _NotificationSummaryLine({
    required this.realtime,
    required this.unreadCount,
    required this.primary,
    required this.secondary,
  });

  final bool realtime;
  final int unreadCount;
  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.bolt_rounded,
          color: PravaColors.accentPrimary,
          size: 21,
        ),
        const SizedBox(width: 6),
        Text(
          realtime ? 'Realtime active' : 'Realtime silent',
          style: PravaTypography.caption.copyWith(
            color: primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 14),
        Icon(Icons.mark_email_unread_rounded, color: secondary, size: 19),
        const SizedBox(width: 6),
        Text(
          '$unreadCount unread',
          style: PravaTypography.caption.copyWith(
            color: secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DeliveryToggle extends StatelessWidget {
  const _DeliveryToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.fill,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final Color primary;
  final Color secondary;
  final Color border;
  final Color fill;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: secondary, size: 23),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PravaTypography.bodySmall.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PravaTypography.caption.copyWith(color: secondary),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.66,
            child: CupertinoSwitch(
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.filter, required this.onChanged});

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
    final inactiveFill = isDark
        ? Colors.white10
        : Colors.black.withValues(alpha: 0.04);

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
            color: active ? PravaColors.accentPrimary : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: PravaTypography.caption.copyWith(
            color: active ? PravaColors.accentPrimary : inactiveText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _UnreadPill extends StatelessWidget {
  const _UnreadPill({required this.count, required this.isDark});

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
                        backgroundColor: isDark ? Colors.black : Colors.white,
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
