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
    this.kind = 'offer',
    this.minutes = 0,
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

  /// Offer answers: `break`, `keep`, `timeout`, `left`. Others: `shown`, `go_back`, `done`,
  /// `start`, `expired`, `ended_early`.
  final String response;

  /// `offer` (sheet answer), `island` (answer from the island card), `blocked` (block sheet) or `pass`.
  final String kind;

  /// Break pass length in minutes for `pass` rows, else 0.
  final int minutes;

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
      kind: raw['kind'] is String ? raw['kind'] as String : 'offer',
      minutes: _int(raw['minutes']),
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
    'kind': kind,
    'minutes': minutes,
  };

  /// The user chose Take a break: the app's short-form block was switched on natively and the
  /// Blocks tab (Firestore) has to show it.
  bool get switchedBlockOn =>
      response == 'break' && (kind == 'offer' || kind == 'island');

  /// The Blocks-tab toggle (platform, feature) for this event's app, or null for other apps.
  ({String platform, String feature})? get blockTarget => switch (pkg) {
    'com.instagram.android' => (platform: 'Instagram', feature: 'Reels'),
    'com.google.android.youtube' => (platform: 'YouTube', feature: 'Shorts'),
    'com.zhiliaoapp.musically' => (platform: 'TikTok', feature: 'Videos'),
    'com.facebook.katana' => (platform: 'Facebook', feature: 'Reels'),
    _ => null,
  };
}
