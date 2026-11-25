import 'package:flutter/material.dart';
import 'package:pace/core/theme/theme_context.dart';

/// The Staylit wordmark: "stay" in the text color and "lit" in the accent,
/// set in the app font (Space Grotesk Bold). Drawn in code, so it is always
/// crisp and follows the theme.
class StaylitWordmark extends StatelessWidget {
  const StaylitWordmark({
    super.key,
    this.fontSize = 28,
    this.stayColor,
    this.litColor,
  });

  final double fontSize;

  /// Defaults to the palette's `onCanvas`.
  final Color? stayColor;

  /// Defaults to the palette's `accentText`.
  final Color? litColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final base = Theme.of(context).textTheme.displaySmall!.copyWith(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: -fontSize * 0.03,
      height: 1,
    );
    return Semantics(
      label: 'Staylit',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'stay',
              style: base.copyWith(color: stayColor ?? palette.onCanvas),
            ),
            TextSpan(
              text: 'lit',
              style: base.copyWith(color: litColor ?? palette.accentText),
            ),
          ],
        ),
      ),
    );
  }
}
