import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/data/models/daily_stat.dart';
import 'package:staylit/data/repositories/daily_stats_repository.dart';

final dailyStatsRepositoryProvider = Provider<DailyStatsRepository>(
  (ref) => DailyStatsRepository(),
);

/// Current and longest focus streak (last 90 days), from `dailyStats`.
final streakProvider =
    StreamProvider.family<({int current, int longest}), String>(
      (ref, userId) => ref
          .watch(dailyStatsRepositoryProvider)
          .streamRecent(userId, days: 90)
          .map(DailyStat.streaks),
    );

/// The last 7 days of focus (oldest first, today last) for a user.
final weekStatsProvider = StreamProvider.family<List<DailyStat>, String>(
  (ref, userId) =>
      ref.watch(dailyStatsRepositoryProvider).streamRecent(userId, days: 7),
);
