import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';

/// Small red dot marking something new.
class NotificationDot extends StatelessWidget {
  const NotificationDot({super.key, this.size = 10});

  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.badge,
        shape: BoxShape.circle,
        border: Border.all(color: palette.canvas, width: 1.5),
      ),
    );
  }
}

/// Circular icon button (back, bell, more, apps).
///
/// [semanticLabel] is required: an icon alone says nothing to a screen reader.
class IconCircleButton extends StatelessWidget {
  const IconCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.showDot = false,
    this.size = AppSizes.iconButton,
    this.background,
    this.foreground,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final bool showDot;
  final double size;

  /// Defaults to the palette's `surface`.
  final Color? background;

  /// Defaults to the palette's `onCanvas`.
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Material(
                color: background ?? palette.surface,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPressed,
                  child: Icon(
                    icon,
                    size: size * 0.43,
                    color: foreground ?? palette.onCanvas,
                  ),
                ),
              ),
            ),
            if (showDot)
              const Positioned(top: 2, right: 2, child: NotificationDot()),
          ],
        ),
      ),
    );
  }
}
