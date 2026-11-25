import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/models/usage_stats_models.dart';
import 'package:staylit/services/native_service.dart';

/// Today's per-app phone usage, read from the native UsageStatsManager bridge.
/// Used for the "phone usage today" chip on Focus and the distracting-apps line
/// on Progress.
final todayUsageStatsProvider = FutureProvider<UsageStatsResponse>((ref) async {
  final rawData = await NativeService.getTodayUsageStats();
  debugPrint('Today usage: ${(rawData['apps'] as List?)?.length ?? 0} apps');
  return UsageStatsResponse.fromMap(rawData);
});
