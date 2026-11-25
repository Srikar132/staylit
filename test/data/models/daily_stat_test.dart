import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/data/models/daily_stat.dart';

void main() {
  group('DailyStat.dayKey', () {
    test('pads month and day', () {
      expect(DailyStat.dayKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(DailyStat.dayKey(DateTime(2026, 11, 24)), '2026-11-24');
    });
  });

  group('DailyStat.fromMap', () {
    test('reads minutes and sessions', () {
      final stat = DailyStat.fromMap('2026-11-24', {
        'totalFocusTime': 95,
        'totalSessions': 3,
      });
      expect(stat.date, '2026-11-24');
      expect(stat.focusMinutes, 95);
      expect(stat.sessions, 3);
    });

    test('missing fields are zero', () {
      final stat = DailyStat.fromMap('2026-11-24', {});
      expect(stat.focusMinutes, 0);
      expect(stat.sessions, 0);
    });
  });

  group('DailyStat.lastDays', () {
    final today = DateTime(2026, 11, 24);

    test('returns exactly 7 days ending today, oldest first', () {
      final days = DailyStat.lastDays(stats: const [], today: today);
      expect(days, hasLength(7));
      expect(days.first.date, '2026-11-18');
      expect(days.last.date, '2026-11-24');
      expect(days.every((d) => d.focusMinutes == 0), isTrue);
    });

    test('keeps recorded days and zero-fills the gaps', () {
      final days = DailyStat.lastDays(
        today: today,
        stats: const [
          DailyStat(date: '2026-11-24', focusMinutes: 112, sessions: 2),
          DailyStat(date: '2026-11-21', focusMinutes: 40, sessions: 1),
        ],
      );
      expect(days.map((d) => d.focusMinutes), [0, 0, 0, 40, 0, 0, 112]);
    });

    test('ignores days older than the window', () {
      final days = DailyStat.lastDays(
        today: today,
        stats: const [
          DailyStat(date: '2026-11-01', focusMinutes: 500, sessions: 9),
        ],
      );
      expect(days.fold<int>(0, (sum, d) => sum + d.focusMinutes), 0);
    });

    test('crosses month and year boundaries', () {
      final days = DailyStat.lastDays(
        today: DateTime(2026, 1, 2),
        stats: const [],
      );
      expect(days.first.date, '2025-12-27');
      expect(days.last.date, '2026-01-02');
    });
  });
}
