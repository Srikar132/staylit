import 'package:flutter/material.dart';

/// Color tokens of the Warm Focus design system, one instance per brightness.
///
/// Registered as a [ThemeExtension] on both `AppTheme.light` and
/// `AppTheme.dark`, read in widgets with `context.palette`
/// (see `theme_context.dart`). Widgets must never hardcode colors: every
/// color comes from here or from `Theme.of(context).colorScheme`.
///
/// Values are estimated from `designs/reference-focus-ui.png`; see
/// `designs/design-system.md`. Contrast of every text/background pair is
/// enforced by `test/core/theme/app_palette_test.dart`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceTrack,
    required this.border,
    required this.divider,
    required this.accent,
    required this.accentSoft,
    required this.accentStrong,
    required this.accentText,
    required this.onAccent,
    required this.ink,
    required this.onInk,
    required this.onCanvas,
    required this.onCanvasSecondary,
    required this.onCanvasMuted,
    required this.onCanvasDisabled,
    required this.chartAlt,
    required this.badge,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.onError,
    required this.scrim,
    required this.onScrim,
    required this.premium,
    required this.categorical,
  });

  /// Screen background.
  final Color canvas;

  /// Cards and tiles on [canvas].
  final Color surface;

  /// Dialogs, sheets, menus, inputs: one step above [surface].
  final Color surfaceRaised;

  /// Inactive tracks (ring, progress strip, slider).
  final Color surfaceTrack;

  /// Hairline outlines (inputs, outlined buttons).
  final Color border;

  /// Dividers.
  final Color divider;

  /// Brand accent used for fills: primary button, hero panels, ring.
  final Color accent;

  /// Soft tint of [accent] for halos and tinted fills.
  final Color accentSoft;

  /// Pressed / emphasized variant of [accent].
  final Color accentStrong;

  /// Accent for text and icons placed on [canvas] (darker/lighter than
  /// [accent] so it passes contrast).
  final Color accentText;

  /// Text and icons on [accent] fills.
  final Color onAccent;

  /// Emphasis surfaces: timer disc, bottom nav, control buttons, chart bars.
  final Color ink;

  /// Text and icons on [ink].
  final Color onInk;

  /// Primary text on [canvas] and [surface].
  final Color onCanvas;

  /// Secondary text.
  final Color onCanvasSecondary;

  /// Hints and captions.
  final Color onCanvasMuted;

  /// Disabled text and icons (exempt from contrast requirements).
  final Color onCanvasDisabled;

  /// Secondary data color (per-subject mini charts).
  final Color chartAlt;

  /// Notification dot.
  final Color badge;

  /// Semantic status colors, used as foreground (icons, text, tints).
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  /// Text and icons on [error], [success], [warning] and [info] fills.
  final Color onError;

  /// Dim layer drawn over content behind modals and photos.
  final Color scrim;

  /// Text and icons placed over photos or [scrim].
  final Color onScrim;

  /// PRO badge. Kept distinct from [accent].
  final Color premium;

  /// Cycled palette for identifying things by index (avatars, groups).
  final List<Color> categorical;

  /// Stable color for a group or user, derived from its [name].
  Color groupColor(String name) {
    var hash = 0;
    for (var i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return categorical[hash.abs() % categorical.length];
  }

  /// Warm Focus, light: cream canvas, burnt-orange accent, near-black ink.
  static const AppPalette light = AppPalette(
    canvas: Color(0xFFF1ECE7),
    surface: Color(0xFFE8E0D8),
    surfaceRaised: Color(0xFFFAF7F4),
    surfaceTrack: Color(0xFFDDD4CB),
    border: Color(0x29141210),
    divider: Color(0x1F141210),
    accent: Color(0xFFE8653A),
    accentSoft: Color(0xFFF2C0AE),
    accentStrong: Color(0xFFD4562C),
    accentText: Color(0xFFB93F14),
    onAccent: Color(0xFF141210),
    ink: Color(0xFF141210),
    onInk: Color(0xFFFFFFFF),
    onCanvas: Color(0xFF1A1614),
    onCanvasSecondary: Color(0xFF4F4944),
    onCanvasMuted: Color(0xFF625C57),
    onCanvasDisabled: Color(0xFFA39B94),
    chartAlt: Color(0xFF7A3BE8),
    badge: Color(0xFFE5483A),
    success: Color(0xFF1F7A4D),
    warning: Color(0xFF9A6410),
    error: Color(0xFFB8321F),
    info: Color(0xFF2F5FC4),
    onError: Color(0xFFFFFFFF),
    scrim: Color(0x99000000),
    onScrim: Color(0xFFFFFFFF),
    premium: Color(0xFF9A6B00),
    categorical: [
      Color(0xFFE8653A),
      Color(0xFF7A3BE8),
      Color(0xFF1F7A4D),
      Color(0xFF3B6FD4),
      Color(0xFFB7791F),
      Color(0xFFC23B2E),
      Color(0xFF0F8B8D),
      Color(0xFF8A5A44),
    ],
  );

  /// Warm Focus, dark: warm near-black canvas, same orange family, cream text.
  static const AppPalette dark = AppPalette(
    canvas: Color(0xFF141210),
    surface: Color(0xFF1F1B19),
    surfaceRaised: Color(0xFF2A2522),
    surfaceTrack: Color(0xFF36302C),
    border: Color(0x29F5F0EB),
    divider: Color(0x1FF5F0EB),
    accent: Color(0xFFF0734A),
    accentSoft: Color(0xFF5A2E22),
    accentStrong: Color(0xFFFF8559),
    accentText: Color(0xFFFF8A5E),
    onAccent: Color(0xFF141210),
    ink: Color(0xFF0B0A09),
    onInk: Color(0xFFFFFFFF),
    onCanvas: Color(0xFFF5F0EB),
    onCanvasSecondary: Color(0xFFB9B1AA),
    onCanvasMuted: Color(0xFF9A928B),
    onCanvasDisabled: Color(0xFF5E5852),
    chartAlt: Color(0xFFA67BFF),
    badge: Color(0xFFFF5A4A),
    success: Color(0xFF1F7F4F),
    warning: Color(0xFF9A6410),
    error: Color(0xFFD13B2F),
    info: Color(0xFF2F6FE0),
    onError: Color(0xFFFFFFFF),
    scrim: Color(0xB3000000),
    onScrim: Color(0xFFFFFFFF),
    premium: Color(0xFFFFD700),
    categorical: [
      Color(0xFFF0734A),
      Color(0xFFA67BFF),
      Color(0xFF4ADE80),
      Color(0xFF7FA8FF),
      Color(0xFFF5B942),
      Color(0xFFFF7A6B),
      Color(0xFF3DD6D0),
      Color(0xFFC89B7B),
    ],
  );

  @override
  AppPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceTrack,
    Color? border,
    Color? divider,
    Color? accent,
    Color? accentSoft,
    Color? accentStrong,
    Color? accentText,
    Color? onAccent,
    Color? ink,
    Color? onInk,
    Color? onCanvas,
    Color? onCanvasSecondary,
    Color? onCanvasMuted,
    Color? onCanvasDisabled,
    Color? chartAlt,
    Color? badge,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? onError,
    Color? scrim,
    Color? onScrim,
    Color? premium,
    List<Color>? categorical,
  }) {
    return AppPalette(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceTrack: surfaceTrack ?? this.surfaceTrack,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      accentStrong: accentStrong ?? this.accentStrong,
      accentText: accentText ?? this.accentText,
      onAccent: onAccent ?? this.onAccent,
      ink: ink ?? this.ink,
      onInk: onInk ?? this.onInk,
      onCanvas: onCanvas ?? this.onCanvas,
      onCanvasSecondary: onCanvasSecondary ?? this.onCanvasSecondary,
      onCanvasMuted: onCanvasMuted ?? this.onCanvasMuted,
      onCanvasDisabled: onCanvasDisabled ?? this.onCanvasDisabled,
      chartAlt: chartAlt ?? this.chartAlt,
      badge: badge ?? this.badge,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      onError: onError ?? this.onError,
      scrim: scrim ?? this.scrim,
      onScrim: onScrim ?? this.onScrim,
      premium: premium ?? this.premium,
      categorical: categorical ?? this.categorical,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    // Color.lerp only returns null when both inputs are null; ours never are.
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? b;
    return AppPalette(
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      surfaceTrack: mix(surfaceTrack, other.surfaceTrack),
      border: mix(border, other.border),
      divider: mix(divider, other.divider),
      accent: mix(accent, other.accent),
      accentSoft: mix(accentSoft, other.accentSoft),
      accentStrong: mix(accentStrong, other.accentStrong),
      accentText: mix(accentText, other.accentText),
      onAccent: mix(onAccent, other.onAccent),
      ink: mix(ink, other.ink),
      onInk: mix(onInk, other.onInk),
      onCanvas: mix(onCanvas, other.onCanvas),
      onCanvasSecondary: mix(onCanvasSecondary, other.onCanvasSecondary),
      onCanvasMuted: mix(onCanvasMuted, other.onCanvasMuted),
      onCanvasDisabled: mix(onCanvasDisabled, other.onCanvasDisabled),
      chartAlt: mix(chartAlt, other.chartAlt),
      badge: mix(badge, other.badge),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      error: mix(error, other.error),
      info: mix(info, other.info),
      onError: mix(onError, other.onError),
      scrim: mix(scrim, other.scrim),
      onScrim: mix(onScrim, other.onScrim),
      premium: mix(premium, other.premium),
      categorical: categorical.length == other.categorical.length
          ? [
              for (var i = 0; i < categorical.length; i++)
                mix(categorical[i], other.categorical[i]),
            ]
          : (t < 0.5 ? categorical : other.categorical),
    );
  }
}
