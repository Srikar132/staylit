import 'package:flutter/material.dart';
import 'package:pace/core/theme/app_palette.dart';

/// Convenience accessors for the design system on [BuildContext].
extension AppThemeContext on BuildContext {
  /// The active [AppPalette].
  ///
  /// Falls back to the palette matching the current brightness when the
  /// extension is not registered (e.g. a plain `ThemeData` in a test), so
  /// reading it never throws.
  AppPalette get palette {
    final theme = Theme.of(this);
    return theme.extension<AppPalette>() ??
        (theme.brightness == Brightness.dark
            ? AppPalette.dark
            : AppPalette.light);
  }
}
