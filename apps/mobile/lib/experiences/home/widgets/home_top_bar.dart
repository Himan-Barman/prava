import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../ui-system/typography.dart';
import '../../../ui-system/colors.dart';
import '../../../navigation/prava_navigator.dart';
import '../../../services/notification_center.dart';
import '../pages/notifications_page.dart';
import '../pages/search_page.dart';
import '../pages/settings_page.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    this.tabIndex = 0,
    this.onChatMenuSelected,
    this.onProfileEdit,
  });

  final int tabIndex;
  final ValueChanged<ChatTopMenuAction>? onChatMenuSelected;
  final VoidCallback? onProfileEdit;

  static const _tabTitles = ['Prava', 'Chats', 'Friends', 'Profile'];
  static const double _height = 44;
  static const double _actionLaneWidth = 124;

  @override
  Widget build(BuildContext context) {
    NotificationCenter.instance.ensureInitialized();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primaryText = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;

    final title = tabIndex >= 0 && tabIndex < _tabTitles.length
        ? _tabTitles[tabIndex]
        : 'Prava';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 10, 4),
      child: SizedBox(
        height: _height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: SizedBox(
                height: _height,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: Align(
                    key: ValueKey(title),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PravaTypography.h2.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                        color: primaryText,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: _actionLaneWidth,
              height: _height,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: Align(
                  key: ValueKey(tabIndex),
                  alignment: Alignment.centerRight,
                  child: _buildActions(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    if (tabIndex == 1) {
      return _ChatTopMenuButton(onSelected: onChatMenuSelected);
    }

    if (tabIndex == 2) {
      return const SizedBox.shrink();
    }

    if (tabIndex == 3) {
      return _TopIconButton(
        icon: Icons.edit_rounded,
        onPressed: () {
          HapticFeedback.selectionClick();
          onProfileEdit?.call();
        },
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TopIconButton(
          icon: Icons.search_rounded,
          onPressed: () {
            HapticFeedback.selectionClick();
            PravaNavigator.push(
              context,
              const SearchPage(),
              fullscreenDialog: true,
            );
          },
        ),
        ValueListenableBuilder<int>(
          valueListenable: NotificationCenter.instance.unreadCount,
          builder: (context, count, _) {
            return _NotificationBell(
              count: count,
              onTap: () {
                HapticFeedback.selectionClick();
                PravaNavigator.push(
                  context,
                  const NotificationsPage(),
                  fullscreenDialog: true,
                );
              },
            );
          },
        ),
        _TopIconButton(
          icon: Icons.menu_rounded,
          onPressed: () {
            HapticFeedback.selectionClick();
            PravaNavigator.push(
              context,
              const SettingsPage(),
              fullscreenDialog: true,
            );
          },
        ),
      ],
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      padding: EdgeInsets.zero,
      icon: Icon(icon, size: 27),
      onPressed: onPressed,
    );
  }
}

class _ChatTopMenuButton extends StatelessWidget {
  const _ChatTopMenuButton({required this.onSelected});

  final ValueChanged<ChatTopMenuAction>? onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;
    final surface = isDark
        ? PravaColors.darkBgElevated
        : PravaColors.lightBgElevated;

    return PopupMenuButton<ChatTopMenuAction>(
      onSelected: (action) {
        HapticFeedback.selectionClick();
        onSelected?.call(action);
      },
      color: surface,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (context) => [
        _menuItem(
          value: ChatTopMenuAction.newGroup,
          icon: CupertinoIcons.person_2_fill,
          label: 'New group',
          primary: primary,
        ),
        _menuItem(
          value: ChatTopMenuAction.broadcasts,
          icon: CupertinoIcons.speaker_2_fill,
          label: 'Broadcasts',
          primary: primary,
        ),
        _menuItem(
          value: ChatTopMenuAction.starred,
          icon: CupertinoIcons.star_fill,
          label: 'Starred',
          primary: primary,
        ),
        _menuItem(
          value: ChatTopMenuAction.messageRequests,
          icon: CupertinoIcons.tray_full_fill,
          label: 'Message requests',
          primary: primary,
        ),
      ],
      child: SizedBox(
        width: 38,
        height: 38,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [Icon(Icons.more_vert_rounded, size: 27, color: primary)],
        ),
      ),
    );
  }

  PopupMenuItem<ChatTopMenuAction> _menuItem({
    required ChatTopMenuAction value,
    required IconData icon,
    required String label,
    required Color primary,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: PravaColors.accentPrimary),
          const SizedBox(width: 10),
          Text(label, style: PravaTypography.body.copyWith(color: primary)),
        ],
      ),
    );
  }
}

enum ChatTopMenuAction { newGroup, broadcasts, starred, messageRequests }

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final display = count > 9 ? '9+' : count.toString();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.notifications_rounded, size: 27),
          onPressed: onTap,
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: PravaColors.accentPrimary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                display,
                style: PravaTypography.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
