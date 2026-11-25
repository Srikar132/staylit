import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/core/theme/app_palette.dart';
import 'package:staylit/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('light and dark carry the matching palette extension', () {
      expect(AppTheme.light.extension<AppPalette>(), AppPalette.light);
      expect(AppTheme.dark.extension<AppPalette>(), AppPalette.dark);
    });

    test('brightness matches the mode', () {
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.dark.brightness, Brightness.dark);
    });

    test('color scheme is driven by the palette', () {
      for (final (theme, palette) in [
        (AppTheme.light, AppPalette.light),
        (AppTheme.dark, AppPalette.dark),
      ]) {
        expect(theme.colorScheme.primary, palette.accent);
        expect(theme.colorScheme.onPrimary, palette.onAccent);
        expect(theme.scaffoldBackgroundColor, palette.canvas);
        expect(theme.colorScheme.error, palette.error);
      }
    });

    test('uses the bundled font family', () {
      expect(AppTheme.light.textTheme.bodyMedium?.fontFamily, 'SpaceGrotesk');
    });

    group('overlayStyle', () {
      test('light mode uses dark system icons', () {
        final style = AppTheme.overlayStyle(
          palette: AppPalette.light,
          brightness: Brightness.light,
        );
        expect(style.statusBarIconBrightness, Brightness.dark);
        expect(style.systemNavigationBarIconBrightness, Brightness.dark);
        expect(style.systemNavigationBarColor, AppPalette.light.canvas);
      });

      test('dark mode uses light system icons', () {
        final style = AppTheme.overlayStyle(
          palette: AppPalette.dark,
          brightness: Brightness.dark,
        );
        expect(style.statusBarIconBrightness, Brightness.light);
        expect(style.systemNavigationBarIconBrightness, Brightness.light);
      });

      test('navigation bar color can be overridden', () {
        final style = AppTheme.overlayStyle(
          palette: AppPalette.light,
          brightness: Brightness.light,
          navigationBarColor: Colors.transparent,
        );
        expect(style.systemNavigationBarColor, Colors.transparent);
      });
    });
  });
}
