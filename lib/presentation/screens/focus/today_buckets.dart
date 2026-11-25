/// One finished focus session: when it started and how many minutes it ran.
typedef SessionSpan = ({DateTime start, int minutes});

/// Splits today's focus minutes into time-of-day buckets (default: twelve
/// 2-hour buckets from midnight) for the Home chart.
///
/// A session that crosses a bucket boundary is split between the buckets it
/// overlaps; anything outside [day] is ignored. Pure so it can be tested.
List<int> bucketTodayMinutes(
  Iterable<SessionSpan> sessions, {
  DateTime? day,
  int bucketHours = 2,
}) {
  assert(bucketHours > 0 && 24 % bucketHours == 0);
  final reference = day ?? DateTime.now();
  final dayStart = DateTime(reference.year, reference.month, reference.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final bucketCount = 24 ~/ bucketHours;
  final bucketMs = Duration(hours: bucketHours).inMilliseconds;
  final dayStartMs = dayStart.millisecondsSinceEpoch;
  final totals = List<double>.filled(bucketCount, 0);

  for (final session in sessions) {
    if (session.minutes <= 0) continue;
    final startMs = session.start.millisecondsSinceEpoch;
    final endMs = startMs + Duration(minutes: session.minutes).inMilliseconds;
    final from = startMs < dayStartMs ? dayStartMs : startMs;
    final to = endMs > dayEnd.millisecondsSinceEpoch
        ? dayEnd.millisecondsSinceEpoch
        : endMs;
    if (to <= from) continue;

    for (var i = 0; i < bucketCount; i++) {
      final bucketStart = dayStartMs + i * bucketMs;
      final bucketEnd = bucketStart + bucketMs;
      final overlapStart = from > bucketStart ? from : bucketStart;
      final overlapEnd = to < bucketEnd ? to : bucketEnd;
      if (overlapEnd > overlapStart) {
        totals[i] += (overlapEnd - overlapStart) / 60000;
      }
    }
  }
  return [for (final minutes in totals) minutes.round()];
}

/// Index of the bucket that contains [now].
int currentBucket(DateTime now, {int bucketHours = 2}) =>
    now.hour ~/ bucketHours;
