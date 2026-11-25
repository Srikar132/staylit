import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace/data/repositories/theme_repository.dart';
import 'package:pace/presentation/providers/theme_mode_provider.dart';
import 'package:pace/services/night_mode_bridge.dart';

class FakeThemeRepository implements ThemeRepository {
  FakeThemeRepository({
    this.stored = ThemeMode.system,
    this.failOnSave = false,
  });

  ThemeMode stored;
  final bool failOnSave;
  final List<ThemeMode> saved = [];

  @override
  Future<ThemeMode> load() async => stored;

  @override
  Future<void> save(ThemeMode mode) async {
    if (failOnSave) throw StateError('disk full');
    saved.add(mode);
    stored = mode;
  }
}

class FakeNightModeBridge implements NightModeBridge {
  final List<ThemeMode> applied = [];

  @override
  Future<bool> apply(ThemeMode mode) async {
    applied.add(mode);
    return true;
  }
}

ProviderContainer makeContainer(
  FakeThemeRepository repository, {
  ThemeMode initial = ThemeMode.system,
  FakeNightModeBridge? bridge,
}) {
  final container = ProviderContainer(
    overrides: [
      initialThemeModeProvider.overrideWithValue(initial),
      themeRepositoryProvider.overrideWithValue(repository),
      nightModeBridgeProvider.overrideWithValue(
        bridge ?? FakeNightModeBridge(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('ThemeModeNotifier', () {
    test('starts with the injected initial mode', () {
      final container = makeContainer(
        FakeThemeRepository(),
        initial: ThemeMode.dark,
      );
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('defaults to system', () {
      final container = makeContainer(FakeThemeRepository());
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('setThemeMode updates state and persists', () async {
      final repository = FakeThemeRepository();
      final container = makeContainer(repository);

      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.light);

      expect(container.read(themeModeProvider), ThemeMode.light);
      expect(repository.saved, [ThemeMode.light]);
    });

    test('selecting the current mode does not write again', () async {
      final repository = FakeThemeRepository();
      final container = makeContainer(repository, initial: ThemeMode.dark);

      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);

      expect(repository.saved, isEmpty);
    });

    test('a failing save keeps the chosen mode and does not throw', () async {
      final repository = FakeThemeRepository(failOnSave: true);
      final container = makeContainer(repository);

      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);

      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('tells the native night mode about each change, once', () async {
      final bridge = FakeNightModeBridge();
      final container = makeContainer(FakeThemeRepository(), bridge: bridge);
      final notifier = container.read(themeModeProvider.notifier);

      await notifier.setThemeMode(ThemeMode.dark);
      await notifier.setThemeMode(ThemeMode.dark); // no-op
      await notifier.setThemeMode(ThemeMode.system);

      expect(bridge.applied, [ThemeMode.dark, ThemeMode.system]);
    });

    test('still tells the native side when saving fails', () async {
      final bridge = FakeNightModeBridge();
      final container = makeContainer(
        FakeThemeRepository(failOnSave: true),
        bridge: bridge,
      );

      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.light);

      expect(bridge.applied, [ThemeMode.light]);
    });

    test('reading without an override fails loudly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(() => container.read(themeModeProvider), throwsA(anything));
    });
  });
}
