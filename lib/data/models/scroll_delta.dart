/// Scroll damage counts for one local day that the native counter has not yet
/// handed to Firestore. Counts only: no screen content ever lives here.
class ScrollDelta {
  const ScrollDelta({
    required this.day,
    required this.tzOffsetMinutes,
    required this.total,
    required this.perApp,
    required this.sessions,
  });

  /// Day key, `yyyy-MM-dd` in the device's local time (same as
  /// `DailyStat.dayKey`).
  final String day;
  final int tzOffsetMinutes;
  final int total;

  /// Items per package id.
  final Map<String, int> perApp;
  final int sessions;

  /// Nothing worth writing.
  bool get isEmpty => total <= 0 && sessions <= 0;

  /// Parses a map from the native bridge. Returns null if it has no day.
  static ScrollDelta? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final day = raw['day'];
    if (day is! String || day.isEmpty) return null;
    final per = raw['perApp'];
    return ScrollDelta(
      day: day,
      tzOffsetMinutes: _int(raw['tzOffsetMinutes']),
      total: _int(raw['total']),
      perApp: {
        if (per is Map)
          for (final entry in per.entries)
            if (entry.key is String && entry.value is num)
              entry.key as String: (entry.value as num).toInt(),
      },
      sessions: _int(raw['sessions']),
    );
  }

  static int _int(Object? value) => value is num ? value.toInt() : 0;

  Map<String, Object> toMap() => {
    'day': day,
    'tzOffsetMinutes': tzOffsetMinutes,
    'total': total,
    'perApp': perApp,
    'sessions': sessions,
  };
}
