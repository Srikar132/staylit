import 'package:flutter/material.dart';

import 'package:staylit/core/theme/theme_context.dart';

/// Flat canvas behind every block overlay (white in light, near-black in dark).
class OverlayBackground extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;

  const OverlayBackground({
    super.key,
    required this.child,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor ?? context.palette.canvas,
      child: SizedBox.expand(child: child),
    );
  }
}
