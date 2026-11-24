import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pace/data/repositories/theme_repository.dart';

/// The theme mode loaded before `runApp`, so the very first frame already uses
/// the right theme (no flash). Must be overridden in the root `ProviderScope`.
final initialThemeModeProvider = Provider<ThemeMode>(
  (ref) => throw UnimplementedError(
    'initialThemeModeProvider must be overridden in the root ProviderScope.',
  ),
);

final themeRepositoryProvider = Provider<ThemeRepository>(
  (ref) => SharedPreferencesThemeRepository(),
);

/// Current [ThemeMode] (System by default) and the way to change it.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(initialThemeModeProvider);

  /// Applies [mode] immediately, then persists it. If persisting fails the
  /// in-memory choice is kept for this session and the failure is logged; the
  /// next launch falls back to the last value that was saved successfully.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    try {
      await ref.read(themeRepositoryProvider).save(mode);
    } catch (error, stackTrace) {
      debugPrint('Failed to persist theme mode: $error\n$stackTrace');
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
