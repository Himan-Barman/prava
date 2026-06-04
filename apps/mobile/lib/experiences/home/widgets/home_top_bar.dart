import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../ui-system/typography.dart';
import '../../../ui-system/colors.dart';
import '../../../navigation/prava_navigator.dart';
import '../../../services/notification_center.dart';
import '../pages/notifications_page.dart';
import '../pages/search_page.dart';
import 'home_overflow_menu.dart';

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
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      child: Row(
        children: [
          /// Brand / tab title
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Text(
              title,
              key: ValueKey(title),
              style: PravaTypography.h2.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                color: primaryText,
              ),
            ),
          ),

          const Spacer(),

          if (tabIndex == 1) ...[
            _ChatTopMenuButton(onSelected: onChatMenuSelected),
          ] else if (tabIndex == 3) ...[
            IconButton(
              icon: const Icon(CupertinoIcons.pencil),
              onPressed: () {
                HapticFeedback.selectionClick();
                onProfileEdit?.call();
              },
            ),
          ] else ...[
            /// Search
            IconButton(
              icon: const Icon(CupertinoIcons.search),
              onPressed: () {
                HapticFeedback.selectionClick();
                PravaNavigator.push(
                  context,
                  const SearchPage(),
                  fullscreenDialog: true,
                );
              },
            ),

            /// Notifications
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

            /// Overflow menu
            IconButton(
              icon: const Icon(CupertinoIcons.ellipsis_vertical),
              onPressed: () {
                HomeOverflowMenu.show(context);
              },
            ),
          ],
        ],
      ),
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
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Icon(
              CupertinoIcons.ellipsis_vertical,
              size: 22,
              color: primary,
            ),
          ],
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
          Text(
            label,
            style: PravaTypography.body.copyWith(color: primary),
          ),
        ],
      ),
    );
  }
}

enum ChatTopMenuAction { newGroup, broadcasts, starred, messageRequests }

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final display = count > 9 ? '9+' : count.toString();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(CupertinoIcons.bell),
          onPressed: onTap,
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
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
