import 'package:flutter/material.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/widgets/design/scalloped.dart';

/// Accent panel with a scalloped bottom edge: the hero block of the welcome
/// screen. Put the illustration (or any content) in [child].
class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key, required this.child, this.scallopDepth = 10});

  final Widget child;
  final double scallopDepth;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: ScallopedBottomClipper(depth: scallopDepth),
      child: ColoredBox(
        color: context.palette.accent,
        child: Padding(
          padding: EdgeInsets.only(bottom: scallopDepth),
          child: child,
        ),
      ),
    );
  }
}
