import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Native service for app limit management
/// Communicates with Android's AccessibilityService + UsageStatsManager
/// This implementation follows the simplified architecture:
/// - Kotlin handles all usage tracking and enforcement
/// - Flutter only manages UI and pushes limits to native
class AppLimitNativeService {
  static const _limitsChannel = MethodChannel('com.staylit.app/app_limits');
  static const _eventsChannel = MethodChannel(
    'com.staylit.app/app_limits_events',
  );

  /// Update limits in native (Kotlin). FULL REPLACE, not a merge: native drops every
  /// package that is not in [limits], so always send the complete set of active limits
  /// (see `activeLimitsMap`). Native saves it, so it survives a restart.
  /// @param limits Map of packageName -> limitMinutes
  Future<bool> updateLimits(Map<String, int> limits) async {
    try {
      final limitsList = limits.entries
          .map((entry) => {'package': entry.key, 'limitMinutes': entry.value})
          .toList();

      final result = await _limitsChannel.invokeMethod<bool>('updateLimits', {
        'limits': limitsList,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Error updating limits: $e');
      return false;
    }
  }

  /// Get today's usage for a specific app (in minutes)
  Future<int> getTodayUsage(String packageName) async {
    try {
      final result = await _limitsChannel.invokeMethod<int>(
        'getTodayUsage',
        packageName,
      );
      return result ?? 0;
    } catch (e) {
      debugPrint('Error getting today usage: $e');
      return 0;
    }
  }

  /// Get usage stats for all apps with limits
  Future<Map<String, Map<String, dynamic>>> getAllUsageStats() async {
    try {
      final result = await _limitsChannel.invokeMethod<Map>('getAllUsageStats');

      if (result == null) return {};

      return Map<String, Map<String, dynamic>>.from(
        result.map(
          (key, value) =>
              MapEntry(key.toString(), Map<String, dynamic>.from(value as Map)),
        ),
      );
    } catch (e) {
      debugPrint('Error getting usage stats: $e');
      return {};
    }
  }

  /// Force check all limits (useful for immediate updates)
  Future<List<String>> forceCheckLimits() async {
    try {
      final result = await _limitsChannel.invokeMethod<List>(
        'forceCheckLimits',
      );
      return result?.map((e) => e.toString()).toList() ?? [];
    } catch (e) {
      debugPrint('Error forcing check limits: $e');
      return [];
    }
  }

  /// Clear all pending limit-exceeded warnings (no native handler yet - no-op until implemented)
  Future<bool> clearAllWarnings() async {
    try {
      final result = await _limitsChannel.invokeMethod<bool>(
        'clearAllWarnings',
      );
      return result ?? false;
    } catch (e) {
      debugPrint('Error clearing warnings: $e');
      return false;
    }
  }

  /// Initialize limit events handler
  void initLimitEventsHandler(Function(String packageName) onLimitReached) {
    debugPrint('🔔 Setting up app limit events handler...');
    _eventsChannel.setMethodCallHandler((call) async {
      debugPrint('🔔 Received method call: ${call.method}');
      debugPrint('🔔 Arguments: ${call.arguments}');
      if (call.method == 'limitReached') {
        final packageName = call.arguments['package'] as String?;
        debugPrint('⚠️ Limit reached event for: $packageName');
        if (packageName != null) {
          onLimitReached(packageName);
        } else {
          debugPrint('❌ Package name is null in limit reached event');
        }
      }
    });
    debugPrint('✅ App limit events handler setup complete');
  }
}
