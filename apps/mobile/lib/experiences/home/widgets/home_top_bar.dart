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
  const HomeTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    NotificationCenter.instance.ensureInitialized();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primaryText = isDark
        ? PravaColors.darkTextPrimary
        : PravaColors.lightTextPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      child: Row(
        children: [
          /// Brand
          Text(
            "Prava",
            style: PravaTypography.h2.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              color: primaryText,
            ),
          ),

          const Spacer(),

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
      ),
    );
  }
}

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
