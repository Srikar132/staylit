import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/data/models/daily_stat.dart';

List<DailyStat> days(List<int> completed) => [
  for (var i = 0; i < completed.length; i++)
    DailyStat(
      date: 'd$i',
      focusMinutes: completed[i] * 25,
      sessions: completed[i],
      completedSessions: completed[i],
    ),
];

void main() {
  group('DailyStat.streaks', () {
    test('empty history has no streak', () {
      expect(DailyStat.streaks(const []), (current: 0, longest: 0));
      expect(DailyStat.streaks(days([0, 0, 0])), (current: 0, longest: 0));
    });

    test('counts consecutive days ending today', () {
      expect(DailyStat.streaks(days([0, 1, 2, 1])), (current: 3, longest: 3));
    });

    test('an empty today does not break the streak yet', () {
      expect(DailyStat.streaks(days([1, 1, 1, 0])), (current: 3, longest: 3));
    });

    test('a gap resets current but keeps longest', () {
      expect(DailyStat.streaks(days([1, 1, 1, 1, 0, 0, 1])), (
        current: 1,
        longest: 4,
      ));
    });

    test('ended-early sessions do not count', () {
      final stats = [
        const DailyStat(date: 'a', focusMinutes: 10, sessions: 1),
        const DailyStat(
          date: 'b',
          focusMinutes: 25,
          sessions: 1,
          completedSessions: 1,
        ),
      ];
      expect(DailyStat.streaks(stats), (current: 1, longest: 1));
    });
  });
}
