/// Focus recorded for one local day, from `dailyStats/{uid}/days/{date}`.
///
/// [focusMinutes] is in **minutes**, as written by
/// `FocusSessionRepository.finishSession`.
class DailyStat {
  const DailyStat({
    required this.date,
    required this.focusMinutes,
    required this.sessions,
    this.completedSessions = 0,
  });

  /// Day key, `yyyy-MM-dd` in the device's local time.
  final String date;
  final int focusMinutes;
  final int sessions;

  /// Sessions that ran to their planned length (streak input).
  final int completedSessions;

  /// Parses a day document; [date] is the document id.
  factory DailyStat.fromMap(String date, Map<String, dynamic> data) {
    return DailyStat(
      date: date,
      focusMinutes: (data['totalFocusTime'] as num?)?.toInt() ?? 0,
      sessions: (data['totalSessions'] as num?)?.toInt() ?? 0,
      completedSessions: (data['completedSessions'] as num?)?.toInt() ?? 0,
    );
  }

  /// The day key (`yyyy-MM-dd`) for [day] in its own time zone.
  static String dayKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// Current and longest streak of consecutive local days with at least one
  /// completed session. [stats] is a continuous run of days, oldest first,
  /// ending on today (as returned by [lastDays]).
  ///
  /// The current streak is not broken by an empty *today* - the day is not over
  /// yet - so it counts back from yesterday in that case.
  static ({int current, int longest}) streaks(List<DailyStat> stats) {
    var longest = 0;
    var run = 0;
    for (final stat in stats) {
      if (stat.completedSessions > 0) {
        run++;
        if (run > longest) longest = run;
      } else {
        run = 0;
      }
    }

    var current = 0;
    var index = stats.length - 1;
    if (index >= 0 && stats[index].completedSessions == 0) index--;
    while (index >= 0 && stats[index].completedSessions > 0) {
      current++;
      index--;
    }
    return (current: current, longest: longest);
  }

  /// Exactly [days] entries ending on [today] (oldest first). Days with no
  /// document are zero, so a chart always has one bar per day.
  static List<DailyStat> lastDays({
    required List<DailyStat> stats,
    required DateTime today,
    int days = 7,
  }) {
    final byDate = {for (final stat in stats) stat.date: stat};
    return [
      for (var offset = days - 1; offset >= 0; offset--)
        byDate[dayKey(DateTime(today.year, today.month, today.day - offset))] ??
            DailyStat(
              date: dayKey(
                DateTime(today.year, today.month, today.day - offset),
              ),
              focusMinutes: 0,
              sessions: 0,
            ),
    ];
  }
}
