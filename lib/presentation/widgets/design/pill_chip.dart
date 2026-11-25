import 'package:flutter/material.dart';
import 'package:pace/core/theme/app_dimens.dart';
import 'package:pace/core/theme/theme_context.dart';

/// `surface` pill with an optional leading icon and trailing chevron, e.g. the
/// session-type chip in the session top bar.
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    this.icon,
    this.showChevron = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: palette.surface,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: palette.accentText),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  style: textTheme.labelLarge?.copyWith(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showChevron) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: palette.onCanvasMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
