import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/core/theme/app_theme.dart';
import 'package:staylit/presentation/screens/focus/focus_home_data.dart';
import 'package:staylit/presentation/screens/progress/progress_view.dart';

Widget host(ProgressData data) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: ProgressView(data: data, onRefresh: () async {}),
  ),
);

void main() {
  testWidgets('shows streak, week total and an empty-history message', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const ProgressData(
          currentStreak: 1,
          longestStreak: 5,
          weekMinutes: [0, 30, 0, 0, 0, 0, 90],
          history: [],
        ),
      ),
    );

    expect(find.text('1 day'), findsOneWidget);
    expect(find.text('5 days'), findsOneWidget);
    expect(find.text('No sessions yet'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Total 2 hours')), findsOneWidget);
  });

  testWidgets('groups history under Today / Yesterday headings', (
    tester,
  ) async {
    final now = DateTime.now();
    HistoryEntry entry(DateTime day, String title) => HistoryEntry(
      day: day,
      tile: SessionTileData(
        title: title,
        subtitle: '9:00 AM · Completed',
        minutes: 25,
        icon: Icons.check_circle_outline_rounded,
      ),
    );

    await tester.pumpWidget(
      host(
        ProgressData(
          currentStreak: 0,
          longestStreak: 0,
          weekMinutes: const [0, 0, 0, 0, 0, 0, 0],
          history: [
            entry(now, 'Study'),
            entry(now.subtract(const Duration(days: 1)), 'Reading'),
          ],
        ),
      ),
    );

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Study'), findsOneWidget);
    expect(find.text('Reading'), findsOneWidget);
  });
}
