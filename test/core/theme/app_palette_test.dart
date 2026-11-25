import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/core/theme/app_palette.dart';

/// WCAG 2.x contrast ratio between two opaque colors.
double contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

typedef _Pair = (
  String name,
  Color Function(AppPalette) fg,
  Color Function(AppPalette) bg,
);

void main() {
  const palettes = <String, AppPalette>{
    'light': AppPalette.light,
    'dark': AppPalette.dark,
  };

  // Text must reach 4.5:1.
  final textPairs = <_Pair>[
    ('onCanvas on canvas', (p) => p.onCanvas, (p) => p.canvas),
    ('onCanvas on surface', (p) => p.onCanvas, (p) => p.surface),
    ('onCanvas on surfaceRaised', (p) => p.onCanvas, (p) => p.surfaceRaised),
    ('secondary on canvas', (p) => p.onCanvasSecondary, (p) => p.canvas),
    ('secondary on surface', (p) => p.onCanvasSecondary, (p) => p.surface),
    ('muted on canvas', (p) => p.onCanvasMuted, (p) => p.canvas),
    ('muted on surface', (p) => p.onCanvasMuted, (p) => p.surface),
    ('muted on surfaceRaised', (p) => p.onCanvasMuted, (p) => p.surfaceRaised),
    ('accentText on canvas', (p) => p.accentText, (p) => p.canvas),
    ('onAccent on accent', (p) => p.onAccent, (p) => p.accent),
    ('onAccent on accentStrong', (p) => p.onAccent, (p) => p.accentStrong),
    ('onInk on ink', (p) => p.onInk, (p) => p.ink),
    ('onError on error', (p) => p.onError, (p) => p.error),
    ('onError on success', (p) => p.onError, (p) => p.success),
    ('onError on warning', (p) => p.onError, (p) => p.warning),
    ('onError on info', (p) => p.onError, (p) => p.info),
  ];

  // Icons, large text and graphics must reach 3:1.
  final graphicPairs = <_Pair>[
    ('accent on ink', (p) => p.accent, (p) => p.ink),
    ('accentText on surface', (p) => p.accentText, (p) => p.surface),
    ('chartAlt on surface', (p) => p.chartAlt, (p) => p.surface),
    ('success on canvas', (p) => p.success, (p) => p.canvas),
    ('warning on canvas', (p) => p.warning, (p) => p.canvas),
    ('error on canvas', (p) => p.error, (p) => p.canvas),
    ('info on canvas', (p) => p.info, (p) => p.canvas),
    ('premium on canvas', (p) => p.premium, (p) => p.canvas),
  ];

  for (final entry in palettes.entries) {
    group('${entry.key} palette contrast', () {
      for (final (name, fg, bg) in textPairs) {
        test('$name >= 4.5', () {
          final ratio = contrastRatio(fg(entry.value), bg(entry.value));
          expect(ratio, greaterThanOrEqualTo(4.5), reason: '$name = $ratio');
        });
      }
      for (final (name, fg, bg) in graphicPairs) {
        test('$name >= 3.0', () {
          final ratio = contrastRatio(fg(entry.value), bg(entry.value));
          expect(ratio, greaterThanOrEqualTo(3.0), reason: '$name = $ratio');
        });
      }
    });
  }

  group('AppPalette', () {
    test('light and dark define the same number of categorical colors', () {
      expect(
        AppPalette.light.categorical.length,
        AppPalette.dark.categorical.length,
      );
      expect(AppPalette.light.categorical, isNotEmpty);
    });

    test('copyWith overrides only the given tokens', () {
      final copy = AppPalette.light.copyWith(accent: const Color(0xFF123456));
      expect(copy.accent, const Color(0xFF123456));
      expect(copy.canvas, AppPalette.light.canvas);
      expect(copy.categorical, AppPalette.light.categorical);
    });

    test('lerp returns the endpoints at t = 0 and t = 1', () {
      final atStart = AppPalette.light.lerp(AppPalette.dark, 0);
      final atEnd = AppPalette.light.lerp(AppPalette.dark, 1);
      expect(atStart.canvas, AppPalette.light.canvas);
      expect(atStart.accent, AppPalette.light.accent);
      expect(atEnd.canvas, AppPalette.dark.canvas);
      expect(atEnd.categorical.first, AppPalette.dark.categorical.first);
    });

    test('lerp blends colors at t = 0.5', () {
      final mid = AppPalette.light.lerp(AppPalette.dark, 0.5);
      expect(
        mid.canvas,
        Color.lerp(AppPalette.light.canvas, AppPalette.dark.canvas, 0.5),
      );
    });

    test('lerp with a different extension type returns this palette', () {
      expect(AppPalette.light.lerp(null, 0.5), same(AppPalette.light));
    });

    test('groupColor is stable and comes from the categorical list', () {
      final first = AppPalette.light.groupColor('Study Group');
      expect(AppPalette.light.groupColor('Study Group'), first);
      expect(AppPalette.light.categorical, contains(first));
    });
  });
}
