import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/data/repositories/scroll_stats_repository.dart';
import 'package:staylit/presentation/screens/focus/focus_home_data.dart';

final scrollStatsRepositoryProvider = Provider<ScrollStatsRepository>(
  (ref) => ScrollStatsRepository(),
);

/// The Home card's numbers: today's count, the last 7 days and the trend.
final scrollDamageProvider = StreamProvider.family<ScrollDamageData, String>(
  (ref, userId) => ref
      .watch(scrollStatsRepositoryProvider)
      .streamRecent(userId, days: 7)
      .map(ScrollDamageData.fromDays),
);
