/// One answer to the "Take a break?" offer, recorded by the native side.
/// Package id, numbers, an enum and a timestamp only: nothing from the screen.
class ScrollEvent {
  const ScrollEvent({
    required this.ts,
    required this.day,
    required this.tzOffsetMinutes,
    required this.pkg,
    required this.sessionCount,
    required this.threshold,
    required this.response,
  });

  /// Epoch milliseconds when the offer appeared. Unique per offer, so it is
  /// also the Firestore document id (a retry overwrites instead of doubling).
  final int ts;

  /// Local day key, `yyyy-MM-dd`.
  final String day;
  final int tzOffsetMinutes;
  final String pkg;

  /// Items in the session when the offer appeared.
  final int sessionCount;

  /// The first-offer threshold in force (N).
  final int threshold;

  /// `break`, `keep`, `timeout` or `left`.
  final String response;

  /// Parses a map from the native bridge. Null if it has no timestamp.
  static ScrollEvent? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final ts = raw['ts'];
    if (ts is! num) return null;
    return ScrollEvent(
      ts: ts.toInt(),
      day: raw['day'] is String ? raw['day'] as String : '',
      tzOffsetMinutes: _int(raw['tzOffsetMinutes']),
      pkg: raw['pkg'] is String ? raw['pkg'] as String : '',
      sessionCount: _int(raw['sessionCount']),
      threshold: _int(raw['threshold']),
      response: raw['response'] is String ? raw['response'] as String : '',
    );
  }

  static int _int(Object? value) => value is num ? value.toInt() : 0;

  Map<String, Object> toMap() => {
    'ts': ts,
    'day': day,
    'tzOffsetMinutes': tzOffsetMinutes,
    'pkg': pkg,
    'sessionCount': sessionCount,
    'threshold': threshold,
    'response': response,
  };
}
