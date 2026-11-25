import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/screens/focus/focus_home_data.dart';
import 'package:staylit/presentation/widgets/design/duration_text.dart';
import 'package:staylit/presentation/widgets/design/message_card.dart';
import 'package:staylit/presentation/widgets/design/session_card.dart';
import 'package:staylit/presentation/widgets/design/week_bar_chart.dart';

/// One history row plus the day it belongs to (for date headings).
@immutable
class HistoryEntry {
  const HistoryEntry({required this.day, required this.tile});

  final DateTime day;
  final SessionTileData tile;
}

/// Everything the Progress tab shows, already resolved from providers.
@immutable
class ProgressData {
  const ProgressData({
    required this.currentStreak,
    required this.longestStreak,
    required this.weekMinutes,
    required this.history,
    this.distractingTodayText,
  });

  final int currentStreak;
  final int longestStreak;

  /// Minutes per day for the last 7 days, oldest first; last is today.
  final List<int> weekMinutes;

  /// "Time on distracting apps today", null when unavailable.
  final String? distractingTodayText;

  /// Newest first.
  final List<HistoryEntry> history;

  int get weekTotal => weekMinutes.fold(0, (sum, m) => sum + m);
}

/// The Progress tab: streak, this week, history. Pure presentation.
class ProgressView extends StatelessWidget {
  const ProgressView({super.key, required this.data, required this.onRefresh});

  final ProgressData data;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          children: [
            Text('Progress', style: textTheme.displaySmall),
            const SizedBox(height: AppSpacing.xl),
            _StreakCard(current: data.currentStreak, best: data.longestStreak),
            const SizedBox(height: AppSpacing.lg),
            _WeekCard(
              weekMinutes: data.weekMinutes,
              total: data.weekTotal,
              distractingTodayText: data.distractingTodayText,
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text('History', style: textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            if (data.history.isEmpty)
              const MessageCard(
                title: 'No sessions yet',
                body: 'Finish a focus session and it will show up here.',
              )
            else
              ..._historyRows(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _historyRows(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rows = <Widget>[];
    DateTime? lastDay;
    for (final entry in data.history) {
      if (lastDay == null || !_sameDay(lastDay, entry.day)) {
        rows.add(
          Padding(
            padding: EdgeInsets.only(
              top: lastDay == null ? 0 : AppSpacing.lg,
              bottom: AppSpacing.sm,
            ),
            child: Text(_dayLabel(entry.day), style: textTheme.titleSmall),
          ),
        );
        lastDay = entry.day;
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: SessionCard(
            title: entry.tile.title,
            subtitle: entry.tile.subtitle,
            minutes: entry.tile.minutes,
            icon: entry.tile.icon,
          ),
        ),
      );
    }
    return rows;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(day.year, day.month, day.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEE, MMM d').format(day);
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.current, required this.best});

  final int current;
  final int best;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final onCard = palette.onAccent;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: palette.accent,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current streak',
                  style: textTheme.titleMedium?.copyWith(color: onCard),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _days(current),
                  style: textTheme.displaySmall?.copyWith(color: onCard),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Best',
                style: textTheme.bodySmall?.copyWith(
                  color: onCard.withValues(alpha: 0.75),
                ),
              ),
              Text(
                _days(best),
                style: textTheme.titleMedium?.copyWith(color: onCard),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _days(int n) => '$n ${n == 1 ? 'day' : 'days'}';
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.weekMinutes,
    required this.total,
    required this.distractingTodayText,
  });

  final List<int> weekMinutes;
  final int total;
  final String? distractingTodayText;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final today = weekMinutes.isEmpty ? 0 : weekMinutes.last;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This week', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          DurationText(minutes: total, color: palette.onCanvas),
          const SizedBox(height: AppSpacing.lg),
          WeekBarChart(
            values: weekMinutes,
            highlightIndex: weekMinutes.isEmpty ? 0 : weekMinutes.length - 1,
            tooltip: _short(today),
            barColor: palette.accent,
            stripeBaseColor: palette.accent,
            stripeColor: palette.onAccent.withValues(alpha: 0.35),
            tooltipBackground: palette.ink,
            tooltipStyle: textTheme.labelMedium!.copyWith(
              color: palette.onInk,
              fontWeight: FontWeight.w600,
            ),
            semanticsLabel:
                'Focus time for the last ${weekMinutes.length} days. '
                'Total ${DurationText.spoken(total)}.',
          ),
          if (distractingTodayText != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Icon(
                  Icons.phone_android_rounded,
                  size: 16,
                  color: palette.onCanvasMuted,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'On distracting apps today: $distractingTodayText',
                    style: textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _short(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '${mins}min';
    if (mins == 0) return '${hours}hr';
    return '${hours}hr ${mins}min';
  }
}
