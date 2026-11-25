import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tells Android which night mode this app should use, so the system splash
/// screen (drawn before Flutter starts) follows the in-app Appearance setting.
abstract interface class NightModeBridge {
  /// Applies [mode]. Returns whether the platform accepted it; returns false
  /// (never throws) when unsupported, e.g. Android 11 and below.
  Future<bool> apply(ThemeMode mode);
}

/// [NightModeBridge] over the existing `com.staylit.app/native` channel.
class MethodChannelNightModeBridge implements NightModeBridge {
  MethodChannelNightModeBridge([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'com.staylit.app/native';
  static const String methodName = 'setNightMode';

  final MethodChannel _channel;

  /// The value the native side expects for [mode].
  static String argumentFor(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };

  @override
  Future<bool> apply(ThemeMode mode) async {
    try {
      return await _channel.invokeMethod<bool>(methodName, argumentFor(mode)) ??
          false;
    } on MissingPluginException {
      return false; // no native side (tests, other platforms)
    } on PlatformException catch (error) {
      debugPrint('NightModeBridge.apply failed: ${error.message}');
      return false;
    }
  }
}
