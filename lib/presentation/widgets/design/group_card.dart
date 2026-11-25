import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';

/// A group in a list: colored initial, name, member count and the group's
/// combined focus time.
class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.name,
    required this.memberCount,
    required this.focusTimeText,
    required this.onTap,
  });

  final String name;
  final int memberCount;

  /// e.g. "12h 30m".
  final String focusTimeText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final initial = name.trim().isEmpty ? 'G' : name.trim()[0].toUpperCase();
    final avatar = palette.groupColor(name);
    // Light text on dark avatars, dark text on pastel ones (dark mode).
    final onAvatar =
        ThemeData.estimateBrightnessForColor(avatar) == Brightness.dark
        ? palette.onInk
        : palette.ink;

    return Semantics(
      button: true,
      label:
          '$name, $memberCount ${memberCount == 1 ? 'member' : 'members'}, '
          '$focusTimeText focused',
      excludeSemantics: true,
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: avatar,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initial,
                    style: textTheme.titleLarge?.copyWith(color: onAvatar),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$memberCount ${memberCount == 1 ? 'member' : 'members'}'
                        ' · $focusTimeText focused',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: palette.onCanvasMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
