import 'package:flutter/material.dart';
import 'package:pace/core/theme/app_palette.dart';

/// Typography of the Warm Focus design system (Plus Jakarta Sans, bundled in
/// `assets/fonts`, no runtime fetch).
abstract final class AppTypography {
  static const String fontFamily = 'PlusJakartaSans';

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
        44,
        FontWeight.w800,
        color: palette.onCanvas,
        height: 1.1,
        letterSpacing: -1,
      ),
      displayMedium: style(
        36,
        FontWeight.w800,
        color: palette.onCanvas,
        height: 1.15,
        letterSpacing: -0.8,
      ),
      displaySmall: style(
        28,
        FontWeight.w700,
        color: palette.onCanvas,
        height: 1.2,
        letterSpacing: -0.5,
      ),
      headlineLarge: style(24, FontWeight.w600, color: palette.onCanvas),
      headlineMedium: style(22, FontWeight.w600, color: palette.onCanvas),
      headlineSmall: style(20, FontWeight.w600, color: palette.onCanvas),
      titleLarge: style(
        20,
        FontWeight.w600,
        color: palette.onCanvas,
        letterSpacing: -0.2,
      ),
      titleMedium: style(16, FontWeight.w600, color: palette.onCanvas),
      titleSmall: style(14, FontWeight.w600, color: palette.onCanvasSecondary),
      bodyLarge: style(
        16,
        FontWeight.w400,
        color: palette.onCanvasSecondary,
        height: 1.5,
      ),
      bodyMedium: style(
        14,
        FontWeight.w400,
        color: palette.onCanvasSecondary,
        height: 1.5,
      ),
      bodySmall: style(
        12,
        FontWeight.w400,
        color: palette.onCanvasMuted,
        height: 1.4,
      ),
      labelLarge: style(
        16,
        FontWeight.w600,
        color: palette.onCanvas,
        letterSpacing: 0.1,
      ),
      labelMedium: style(13, FontWeight.w500, color: palette.onCanvasSecondary),
      labelSmall: style(
        11,
        FontWeight.w500,
        color: palette.onCanvasMuted,
        letterSpacing: 0.2,
      ),
    );
  }
}
