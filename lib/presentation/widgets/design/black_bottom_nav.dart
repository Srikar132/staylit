import 'package:flutter/material.dart';
import 'package:pace/core/theme/theme_context.dart';

/// One destination of a [BlackBottomNav].
@immutable
class BottomNavItem {
  const BottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;

  /// Read by screen readers (the bar itself shows icons only).
  final String label;
}

/// Flat near-black bottom navigation. The screen above it has rounded bottom
/// corners, so the bar reads as sitting behind the content. The selected item
/// is drawn in the accent color with a small dot beneath it.
class BlackBottomNav extends StatelessWidget {
  const BlackBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  }) : assert(items.length >= 2);

  final List<BottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.ink,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final BottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = selected
        ? palette.accent
        : palette.onInk.withValues(alpha: 0.6);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? item.selectedIcon : item.icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: selected ? 5 : 0,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}
