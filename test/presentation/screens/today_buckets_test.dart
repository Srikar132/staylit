import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/presentation/screens/focus/today_buckets.dart';

void main() {
  final day = DateTime(2026, 11, 25, 15);

  test('an empty day is all zeros', () {
    final buckets = bucketTodayMinutes(const [], day: day);
    expect(buckets, List<int>.filled(12, 0));
  });

  test('a session inside one bucket lands in it', () {
    final buckets = bucketTodayMinutes([
      (start: DateTime(2026, 11, 25, 9, 10), minutes: 25),
    ], day: day);
    expect(buckets[4], 25); // 08:00-10:00
    expect(buckets.fold<int>(0, (a, b) => a + b), 25);
  });

  test('a session crossing a bucket boundary is split', () {
    final buckets = bucketTodayMinutes([
      (start: DateTime(2026, 11, 25, 9, 50), minutes: 30),
    ], day: day);
    expect(buckets[4], 10); // until 10:00
    expect(buckets[5], 20); // from 10:00
  });

  test('time before midnight or after the day ends is ignored', () {
    final buckets = bucketTodayMinutes([
      (start: DateTime(2026, 11, 24, 23, 50), minutes: 30),
      (start: DateTime(2026, 11, 25, 23, 50), minutes: 30),
    ], day: day);
    expect(buckets[0], 20); // 00:00-00:20 of today
    expect(buckets[11], 10); // 23:50-24:00
  });

  test(
    'zero-minute sessions are skipped and the bucket index follows the clock',
    () {
      expect(
        bucketTodayMinutes([(start: day, minutes: 0)], day: day),
        List<int>.filled(12, 0),
      );
      expect(currentBucket(DateTime(2026, 1, 1, 15)), 7);
      expect(currentBucket(DateTime(2026, 1, 1, 0)), 0);
    },
  );
}
