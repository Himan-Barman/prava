import 'package:flutter/material.dart';

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
    final tokens = context.pravaColors;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: RepaintBoundary(
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: tokens.backgroundSurface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: tokens.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: tokens.shadowMedium,
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              return _NavItem(
                item: item,
                active: index == i,
                activeColor: tokens.brandContent,
                inactiveColor: tokens.iconSecondary,
                activeContainer: tokens.brandContainer,
                onTap: () => onChanged(i),
              );
            }),
          ),
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
    required this.activeContainer,
    required this.onTap,
  });

  final _NavItemData item;
  final bool active;
  final Color activeColor;
  final Color inactiveColor;
  final Color activeContainer;
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
          height: 50,
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 48,
                height: 30,
                decoration: BoxDecoration(
                  color: active ? activeContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: AnimatedScale(
                  scale: active ? 1.04 : 1,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    active ? item.activeIcon : item.icon,
                    size: 25,
                    color: iconColor,
                  ),
                ),
              ),
              const SizedBox(height: 1),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                style:
                    (active
                            ? PravaTypography.navLabel
                            : PravaTypography.tinyLabel)
                        .copyWith(color: iconColor),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
