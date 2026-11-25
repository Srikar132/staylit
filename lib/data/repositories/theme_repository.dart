import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's theme mode on this device.
///
/// Device-local on purpose: the preference must apply before login and before
/// the first frame, and it is not account data.
abstract interface class ThemeRepository {
  /// The saved mode, or [ThemeMode.system] when nothing valid is stored or the
  /// store cannot be read. Never throws.
  Future<ThemeMode> load();

  /// Saves [mode]. May throw if the platform store rejects the write.
  Future<void> save(ThemeMode mode);
}

/// [ThemeRepository] backed by [SharedPreferencesAsync].
///
/// The async API reads the platform store directly (no per-isolate cache), so
/// the overlay engine, which runs in a separate isolate, always sees the value
/// last written by the main app.
class SharedPreferencesThemeRepository implements ThemeRepository {
  SharedPreferencesThemeRepository([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  /// Storage key. Changing it resets every user to [ThemeMode.system].
  static const String storageKey = 'theme_mode';

  final SharedPreferencesAsync _preferences;

  @override
  Future<ThemeMode> load() async {
    try {
      return parse(await _preferences.getString(storageKey));
    } catch (error, stackTrace) {
      debugPrint('ThemeRepository.load failed: $error\n$stackTrace');
      return ThemeMode.system;
    }
  }

  @override
  Future<void> save(ThemeMode mode) {
    return _preferences.setString(storageKey, mode.name);
  }

  /// Parses a stored value; anything unknown (null, legacy, corrupt) is
  /// [ThemeMode.system].
  @visibleForTesting
  static ThemeMode parse(String? raw) {
    if (raw == null) return ThemeMode.system;
    return ThemeMode.values.asNameMap()[raw] ?? ThemeMode.system;
  }
}
