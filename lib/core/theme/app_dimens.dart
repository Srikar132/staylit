/// Mode-independent layout constants for the Warm Focus design system.
///
/// Colors live in `AppPalette` (they change with the theme mode); spacing,
/// radii and sizes do not, so they are plain constants.
library;

/// Spacing scale (logical pixels). Multiples of 4, 8 preferred.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 14;

  /// Standard screen gutter.
  static const double xl = 16;
  static const double xxl = 20;
  static const double xxxl = 28;
}

/// Corner radii.
abstract final class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;

  /// Cards.
  static const double card = 24;

  /// Hero panels and large sheets.
  static const double hero = 30;

  /// Large enough to render any control as a pill/circle.
  static const double pill = 999;
}

/// Control sizes.
abstract final class AppSizes {
  /// Minimum interactive target (Material guideline).
  static const double minTouchTarget = 48;

  /// Circular icon button (back, bell, more).
  static const double iconButton = 48;

  /// Primary pill button height.
  static const double buttonHeight = 50;
}
