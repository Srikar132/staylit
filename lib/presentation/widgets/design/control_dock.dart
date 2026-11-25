import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';

/// Full-width accent panel holding the session controls.
class ControlDock extends StatelessWidget {
  const ControlDock({super.key, required this.children});

  /// Usually three [ControlButton]s.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.palette.accent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xl,
            AppSpacing.xxl,
            AppSpacing.lg,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Round near-black button with a caption underneath, for a [ControlDock].
class ControlButton extends StatelessWidget {
  const ControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.large = false,
  });

  final IconData icon;

  /// Shown under the button and used as its accessibility label.
  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// The emphasized middle button.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final diameter = large ? 72.0 : 56.0;
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.hero),
        onTap: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                color: enabled
                    ? palette.ink
                    : palette.ink.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: palette.onInk, size: large ? 32 : 24),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: palette.onAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
