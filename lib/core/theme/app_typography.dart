import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_palette.dart';

/// Typography of the Warm Focus design system: Space Grotesk (OFL), bundled in
/// `assets/fonts` in Regular 400, Medium 500 and Bold 700 (no runtime fetch).
///
/// Weights follow the reference design: Bold for display text and numbers,
/// Medium for titles and controls, Regular for body text.
abstract final class AppTypography {
  static const String fontFamily = 'SpaceGrotesk';

  /// Fixed-width digits so a ticking timer does not jitter.
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  /// Builds the [TextTheme] for [palette]. Colors come from the palette so the
  /// same scale works in both modes.
  static TextTheme textTheme(AppPalette palette) {
    TextStyle style(
      double size,
      FontWeight weight, {
      required Color color,
      double? height,
      double letterSpacing = 0,
    }) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
    }

    return TextTheme(
      displayLarge: style(
        36,
        FontWeight.w700,
        color: palette.onCanvas,
        height: 1.1,
        letterSpacing: -1,
      ),
      displayMedium: style(
        30,
        FontWeight.w700,
        color: palette.onCanvas,
        height: 1.15,
        letterSpacing: -0.8,
      ),
      displaySmall: style(
        24,
        FontWeight.w700,
        color: palette.onCanvas,
        height: 1.2,
        letterSpacing: -0.5,
      ),
      headlineLarge: style(22, FontWeight.w500, color: palette.onCanvas),
      headlineMedium: style(20, FontWeight.w500, color: palette.onCanvas),
      headlineSmall: style(18, FontWeight.w500, color: palette.onCanvas),
      titleLarge: style(
        18,
        FontWeight.w500,
        color: palette.onCanvas,
        letterSpacing: -0.2,
      ),
      titleMedium: style(15, FontWeight.w500, color: palette.onCanvas),
      titleSmall: style(13, FontWeight.w500, color: palette.onCanvasSecondary),
      bodyLarge: style(
        15,
        FontWeight.w400,
        color: palette.onCanvasSecondary,
        height: 1.5,
      ),
      bodyMedium: style(
        13,
        FontWeight.w400,
        color: palette.onCanvasSecondary,
        height: 1.5,
      ),
      bodySmall: style(
        11.5,
        FontWeight.w400,
        color: palette.onCanvasMuted,
        height: 1.4,
      ),
      labelLarge: style(
        15,
        FontWeight.w500,
        color: palette.onCanvas,
        letterSpacing: 0.1,
      ),
      labelMedium: style(12, FontWeight.w500, color: palette.onCanvasSecondary),
      labelSmall: style(
        10,
        FontWeight.w500,
        color: palette.onCanvasMuted,
        letterSpacing: 0.2,
      ),
    );
  }
}
