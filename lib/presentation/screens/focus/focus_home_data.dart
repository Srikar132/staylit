import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:staylit/data/models/focus_session_model.dart';
import 'package:staylit/data/models/scroll_day.dart';
import 'package:staylit/presentation/screens/focus/scroll_trend.dart';

/// One row of "Today's sessions".
@immutable
class SessionTileData {
  const SessionTileData({
    required this.title,
    required this.subtitle,
    required this.minutes,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final int minutes;
  final IconData icon;

  /// Title for a session without a tag ("untagged" is how the save screen
  /// records no tag).
  static const String untaggedTitle = 'Focus session';

  factory SessionTileData.fromSession(FocusSessionModel session) {
    final tag = session.tag?.trim();
    final hasTag = tag != null && tag.isNotEmpty && tag != 'untagged';
    final started = DateFormat('h:mm a').format(session.startTime);

    final (statusLabel, icon) = switch (session.status) {
      SessionStatus.completed => (
        'Completed',
        Icons.check_circle_outline_rounded,
      ),
      SessionStatus.endedEarly => ('Ended early', Icons.timelapse_rounded),
      _ => ('In progress', Icons.play_circle_outline_rounded),
    };

    return SessionTileData(
      title: hasTag ? tag : untaggedTitle,
      subtitle: '$started · $statusLabel',
      minutes: session.actualDuration ?? 0,
      icon: icon,
    );
  }
}

/// Scroll Damage numbers for the Home card (null data = feature off).
@immutable
class ScrollDamageData {
  const ScrollDamageData({
    required this.todayCount,
    required this.week,
    this.trendText,
    this.trendGood = true,
  });

  /// From a continuous run of days, oldest first, ending today (as returned
  /// by `ScrollDay.lastDays`). Fewer than two days gives no trend.
  factory ScrollDamageData.fromDays(List<ScrollDay> days) {
    final totals = [for (final day in days) day.total];
    final today = totals.isEmpty ? 0 : totals.last;
    final trend = totals.length < 2
        ? null
        : ScrollTrend.compare(
            today: today,
            yesterday: totals[totals.length - 2],
          );
    return ScrollDamageData(
      todayCount: today,
      week: totals,
      trendText: trend?.text,
      trendGood: trend?.good ?? true,
    );
  }

  final int todayCount;

  /// Items scrolled per day for the last 7 days, oldest first.
  final List<int> week;

  /// e.g. "↓ 12% vs yesterday".
  final String? trendText;
  final bool trendGood;
}

/// Everything the Focus home screen shows, already resolved from providers.
@immutable
class FocusHomeData {
  const FocusHomeData({
    required this.firstName,
    required this.photoUrl,
    required this.usageText,
    required this.goalMinutes,
    required this.todayMinutes,
    required this.todayBuckets,
    required this.currentBucket,
    required this.setupLabel,
    required this.streak,
    this.scrollEnabled = false,
    this.scrollDamage,
  });

  final String firstName;
  final String? photoUrl;

  /// Phone usage today, e.g. "2h 5m" (or "..." while loading).
  final String usageText;
  final int goalMinutes;
  final int todayMinutes;

  /// Focus minutes per 2-hour bucket of today (12 values from midnight).
  final List<int> todayBuckets;

  /// Index of the bucket the clock is in.
  final int currentBucket;

  /// e.g. "Timer · 25 min · 5 apps blocked".
  final String setupLabel;

  /// Current streak in days.
  final int streak;

  /// The user turned Scroll damage on.
  final bool scrollEnabled;

  /// Numbers once the native counter reports them; null until then.
  final ScrollDamageData? scrollDamage;
}
