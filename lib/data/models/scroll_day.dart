import 'package:staylit/data/models/daily_stat.dart';

/// Short-form items scrolled on one local day, from
/// `scrollStats/{uid}/days/{date}`. Counts are estimates.
class ScrollDay {
  const ScrollDay({
    required this.date,
    required this.total,
    this.perApp = const {},
    this.sessions = 0,
  });

  /// Day key, `yyyy-MM-dd` in the device's local time.
  final String date;
  final int total;
  final Map<String, int> perApp;
  final int sessions;

  /// Parses a day document; [date] is the document id. A counter can never be
  /// negative, so a damaged value reads as zero.
  factory ScrollDay.fromMap(String date, Map<String, dynamic> data) {
    final per = data['perApp'];
    return ScrollDay(
      date: date,
      total: _count(data['total']),
      sessions: _count(data['sessions']),
      perApp: {
        if (per is Map)
          for (final entry in per.entries)
            if (entry.key is String) entry.key as String: _count(entry.value),
      },
    );
  }

  static int _count(Object? value) {
    final n = value is num ? value.toInt() : 0;
    return n < 0 ? 0 : n;
  }

  /// Exactly [days] entries ending on [today] (oldest first). Days with no
  /// document are zero, so a chart always has one bar per day.
  static List<ScrollDay> lastDays({
    required List<ScrollDay> stats,
    required DateTime today,
    int days = 7,
  }) {
    final byDate = {for (final stat in stats) stat.date: stat};
    return [
      for (var offset = days - 1; offset >= 0; offset--)
        () {
          final key = DailyStat.dayKey(
            DateTime(today.year, today.month, today.day - offset),
          );
          return byDate[key] ?? ScrollDay(date: key, total: 0);
        }(),
    ];
  }
}
