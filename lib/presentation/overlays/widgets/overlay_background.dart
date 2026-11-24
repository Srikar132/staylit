import 'package:flutter/material.dart';

import 'package:pace/core/theme/theme_context.dart';

class OverlayBackground extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  final Color? backgroundColor;

  const OverlayBackground({
    super.key,
    required this.child,
    this.gradient,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient:
            gradient ??
            LinearGradient(
              colors: [context.palette.canvas, context.palette.surface],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
        color: backgroundColor,
      ),
      child: child,
    );
  }
}
