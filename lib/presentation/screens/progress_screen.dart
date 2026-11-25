import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/presentation/providers/auth_provider.dart';
import 'package:staylit/presentation/providers/daily_stats_provider.dart';
import 'package:staylit/presentation/providers/session_history_provider.dart';
import 'package:staylit/presentation/providers/usage_stats_provider.dart';
import 'package:staylit/presentation/screens/focus/focus_home_data.dart';
import 'package:staylit/presentation/screens/progress/progress_view.dart';

/// The Progress tab: wires providers into [ProgressView].
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final week = ref.watch(weekStatsProvider(user.uid)).value;
    final streaks = ref.watch(streakProvider(user.uid)).value;
    final history = ref.watch(sessionHistoryProvider(user.uid)).value;
    final usage = ref.watch(todayUsageStatsProvider).value;

    final data = ProgressData(
      currentStreak: streaks?.current ?? 0,
      longestStreak: streaks?.longest ?? 0,
      weekMinutes: [for (final d in week ?? const []) d.focusMinutes],
      distractingTodayText: usage?.formattedDistractingTime,
      history: [
        for (final s in history ?? const [])
          HistoryEntry(day: s.startTime, tile: SessionTileData.fromSession(s)),
      ],
    );

    return ProgressView(
      data: data,
      onRefresh: () async {
        ref.invalidate(sessionHistoryProvider(user.uid));
        ref.invalidate(todayUsageStatsProvider);
        await ref.read(sessionHistoryProvider(user.uid).future);
      },
    );
  }
}
