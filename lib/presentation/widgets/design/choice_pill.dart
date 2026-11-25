import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';

/// A selectable pill (tag, preset). Selected gets an accent outline and a soft
/// accent tint; unselected is a flat `surface` pill.
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? palette.accentSoft : palette.surface,
        shape: StadiumBorder(
          side: selected
              ? BorderSide(color: palette.accent, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: selected ? palette.accentText : palette.onCanvas,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
