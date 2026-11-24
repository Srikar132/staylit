import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace/data/repositories/theme_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Platform whose reads always fail, to prove `load` never throws.
base class _ThrowingPlatform extends InMemorySharedPreferencesAsync {
  _ThrowingPlatform() : super.empty();

  @override
  Future<String?> getString(String key, SharedPreferencesOptions options) {
    throw StateError('store unavailable');
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('SharedPreferencesThemeRepository.parse', () {
    test('maps every ThemeMode name back to the mode', () {
      for (final mode in ThemeMode.values) {
        expect(SharedPreferencesThemeRepository.parse(mode.name), mode);
      }
    });

    test('falls back to system for null, legacy or corrupt values', () {
      expect(SharedPreferencesThemeRepository.parse(null), ThemeMode.system);
      expect(SharedPreferencesThemeRepository.parse(''), ThemeMode.system);
      expect(
        SharedPreferencesThemeRepository.parse('amoled'),
        ThemeMode.system,
      );
    });
  });

  group('SharedPreferencesThemeRepository', () {
    test('defaults to system when nothing was saved', () async {
      final repository = SharedPreferencesThemeRepository();
      expect(await repository.load(), ThemeMode.system);
    });

    test('round-trips every mode', () async {
      final repository = SharedPreferencesThemeRepository();
      for (final mode in ThemeMode.values) {
        await repository.save(mode);
        expect(await repository.load(), mode);
      }
    });

    test('a second repository instance sees the saved value', () async {
      await SharedPreferencesThemeRepository().save(ThemeMode.dark);
      expect(await SharedPreferencesThemeRepository().load(), ThemeMode.dark);
    });

    test('an unknown stored value loads as system', () async {
      await SharedPreferencesAsync().setString(
        SharedPreferencesThemeRepository.storageKey,
        'not-a-mode',
      );
      expect(await SharedPreferencesThemeRepository().load(), ThemeMode.system);
    });

    test('load never throws when the store fails', () async {
      SharedPreferencesAsyncPlatform.instance = _ThrowingPlatform();
      expect(await SharedPreferencesThemeRepository().load(), ThemeMode.system);
    });
  });
}
