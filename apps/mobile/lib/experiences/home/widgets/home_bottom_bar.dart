import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui-system/colors.dart';
import '../../../ui-system/typography.dart';

class HomeBottomBar extends StatelessWidget {
  const HomeBottomBar({
    super.key,
    required this.index,
    required this.onChanged,
  });

  final int index;
  final ValueChanged<int> onChanged;

  static const _items = [
    _NavItemData(
      label: 'Feed',
      icon: CupertinoIcons.news,
      activeIcon: CupertinoIcons.news_solid,
    ),
    _NavItemData(
      label: 'Chats',
      icon: CupertinoIcons.chat_bubble_2,
      activeIcon: CupertinoIcons.chat_bubble_2_fill,
    ),
    _NavItemData(
      label: 'Friends',
      icon: CupertinoIcons.person_2,
      activeIcon: CupertinoIcons.person_2_fill,
    ),
    _NavItemData(
      label: 'Profile',
      icon: CupertinoIcons.person,
      activeIcon: CupertinoIcons.person_fill,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactive = isDark
        ? PravaColors.darkTextTertiary
        : PravaColors.lightTextTertiary;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: List.generate(_items.length, (i) {
            final item = _items[i];
            return _NavItem(
              item: item,
              active: index == i,
              activeColor: PravaColors.accentPrimary,
              inactiveColor: inactive,
              isDark: isDark,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(i);
              },
            );
          }),
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
    required this.isDark,
    required this.onTap,
  });

  final _NavItemData item;
  final bool active;
  final Color activeColor;
  final Color inactiveColor;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlight = active
        ? activeColor.withValues(alpha: isDark ? 0.18 : 0.12)
        : Colors.transparent;
    final iconColor = active ? activeColor : inactiveColor;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: highlight,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: active ? 1.06 : 1,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: Icon(
                  active ? item.activeIcon : item.icon,
                  size: 22,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                style: PravaTypography.caption.copyWith(
                  color: iconColor,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
