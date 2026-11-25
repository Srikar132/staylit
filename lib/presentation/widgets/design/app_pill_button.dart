import 'package:flutter/material.dart';
import 'package:pace/core/theme/app_dimens.dart';
import 'package:pace/core/theme/theme_context.dart';

/// How an [AppPillButton] is filled.
enum PillButtonVariant {
  /// Accent fill: the one primary action on a screen.
  primary,

  /// Near-black fill: a strong secondary action.
  ink,

  /// Transparent with a hairline border.
  outline,
}

/// Full-width pill button, the primary call to action of the design system.
class AppPillButton extends StatelessWidget {
  const AppPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = PillButtonVariant.primary,
    this.expand = true,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final IconData? icon;
  final PillButtonVariant variant;

  /// Stretch to the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (background, foreground, side) = switch (variant) {
      PillButtonVariant.primary => (
        palette.accent,
        palette.onAccent,
        BorderSide.none,
      ),
      PillButtonVariant.ink => (palette.ink, palette.onInk, BorderSide.none),
      PillButtonVariant.outline => (
        Colors.transparent,
        palette.onCanvas,
        BorderSide(color: palette.border, width: 1.5),
      ),
    };

    final button = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: palette.surfaceTrack,
        disabledForegroundColor: palette.onCanvasDisabled,
        minimumSize: const Size(64, AppSizes.buttonHeight),
        side: side,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 22), const SizedBox(width: 8)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
