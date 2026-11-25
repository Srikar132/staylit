import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';

/// A selectable answer card (single choice shows a radio mark, multiple choice
/// a check mark). The selected card gets an accent outline and a soft tint.
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.multiSelect = false,
  });

  final String title;
  final String? subtitle;

  /// Icon or emoji shown at the start.
  final Widget? leading;
  final bool selected;
  final VoidCallback onTap;

  /// True when several cards can be selected at once.
  final bool multiSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(AppRadius.card);

    return Semantics(
      button: true,
      checked: selected,
      inMutuallyExclusiveGroup: !multiSelect,
      label: subtitle == null ? title : '$title, $subtitle',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected
              ? palette.accentSoft.withValues(alpha: 0.35)
              : palette.surface,
          borderRadius: radius,
          border: Border.all(
            color: selected ? palette.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    IconTheme(
                      data: IconThemeData(
                        color: selected
                            ? palette.accentText
                            : palette.onCanvasSecondary,
                        size: 26,
                      ),
                      child: leading!,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleMedium?.copyWith(
                            color: palette.onCanvas,
                          ),
                        ),
                        if (subtitle != null)
                          Text(subtitle!, style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : (multiSelect
                              ? Icons.check_circle_outline_rounded
                              : Icons.radio_button_unchecked_rounded),
                    color: selected ? palette.accent : palette.onCanvasDisabled,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
