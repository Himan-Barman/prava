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
      icon: Icons.dynamic_feed_rounded,
      activeIcon: Icons.dynamic_feed_rounded,
    ),
    _NavItemData(
      label: 'Chats',
      icon: Icons.chat_bubble_rounded,
      activeIcon: Icons.chat_bubble_rounded,
    ),
    _NavItemData(
      label: 'Friends',
      icon: Icons.groups_rounded,
      activeIcon: Icons.groups_rounded,
    ),
    _NavItemData(
      label: 'Profile',
      icon: Icons.person_rounded,
      activeIcon: Icons.person_rounded,
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
      minimum: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    final iconColor = active ? activeColor : inactiveColor;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: active ? 48 : 38,
                height: 30,
                decoration: BoxDecoration(
                  color: active
                      ? activeColor.withValues(alpha: isDark ? 0.18 : 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: AnimatedScale(
                  scale: active ? 1.06 : 1,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    active ? item.activeIcon : item.icon,
                    size: active ? 26 : 24,
                    color: iconColor,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                style: PravaTypography.caption.copyWith(
                  color: iconColor,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 11,
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
