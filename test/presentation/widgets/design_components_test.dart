import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/core/theme/app_theme.dart';
import 'package:staylit/presentation/screens/active_session/active_session_view.dart';
import 'package:staylit/presentation/widgets/design/black_bottom_nav.dart';
import 'package:staylit/presentation/widgets/design/duration_text.dart';
import 'package:staylit/presentation/widgets/design/goal_card.dart';
import 'package:staylit/presentation/widgets/goal_sheet.dart';

Widget host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('DurationText.spoken', () {
    test('formats hours and minutes', () {
      expect(DurationText.spoken(150), '2 hours 30 minutes');
      expect(DurationText.spoken(60), '1 hour');
      expect(DurationText.spoken(61), '1 hour 1 minute');
      expect(DurationText.spoken(45), '45 minutes');
    });

    test('zero and negative read as 0 minutes', () {
      expect(DurationText.spoken(0), '0 minutes');
      expect(DurationText.spoken(-10), '0 minutes');
    });
  });

  group('BlackBottomNav', () {
    const items = [
      BottomNavItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: 'Home',
      ),
      BottomNavItem(
        icon: Icons.bar_chart_outlined,
        selectedIcon: Icons.bar_chart,
        label: 'Stats',
      ),
    ];

    testWidgets('reports the tapped destination', (tester) async {
      var selected = -1;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            bottomNavigationBar: BlackBottomNav(
              items: items,
              selectedIndex: 0,
              onSelected: (i) => selected = i,
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.bar_chart_outlined));
      expect(selected, 1);
    });

    testWidgets('exposes a label for every destination', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            bottomNavigationBar: BlackBottomNav(
              items: items,
              selectedIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Home'), findsOneWidget);
      expect(find.bySemanticsLabel('Stats'), findsOneWidget);
      handle.dispose();
    });
  });

  group('GoalCard', () {
    Widget card({required int goal, required int today}) => host(
      GoalCard(
        goalMinutes: goal,
        todayMinutes: today,
        weekMinutes: const [10, 20, 30, 40, 50, 60, 70],
        onEditGoal: () {},
      ),
    );

    testWidgets('shows the completed percentage', (tester) async {
      await tester.pumpWidget(card(goal: 150, today: 112));
      expect(find.text('75% Completed'), findsOneWidget);
    });

    testWidgets('caps at 100% and tolerates a zero goal', (tester) async {
      await tester.pumpWidget(card(goal: 60, today: 600));
      expect(find.text('100% Completed'), findsOneWidget);
      await tester.pumpWidget(card(goal: 0, today: 30));
      expect(find.text('0% Completed'), findsOneWidget);
    });

    testWidgets('edit button calls back', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          GoalCard(
            goalMinutes: 120,
            todayMinutes: 30,
            weekMinutes: const [0, 0, 0, 0, 0, 0, 30],
            onEditGoal: () => taps++,
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Edit daily goal'));
      expect(taps, 1);
    });
  });

  group('GoalSheet', () {
    testWidgets('saves the chosen minutes', (tester) async {
      int? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    result = await showGoalSheet(context, initialMinutes: 90),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Daily goal'), findsOneWidget);

      await tester.tap(find.text('Save goal'));
      await tester.pumpAndSettle();
      expect(result, 90);
    });

    testWidgets('clamps an out-of-range initial value', (tester) async {
      int? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    result = await showGoalSheet(context, initialMinutes: 5000),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save goal'));
      await tester.pumpAndSettle();
      expect(result, GoalSheet.maxMinutes);
    });
  });

  group('ActiveSessionView', () {
    Widget view({required bool canControl, required VoidCallback onStop}) =>
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ActiveSessionView(
              typeLabel: 'Timer',
              typeIcon: Icons.timer_outlined,
              timerLabel: 'Time Left',
              timeText: '25:00',
              statusText: 'Counting down',
              progress: 0.2,
              paused: false,
              canControl: canControl,
              messageTitle: 'Hi',
              messageBody: 'There',
              onApps: () {},
              onAmbient: () {},
              onPauseResume: () {},
              onStop: onStop,
            ),
          ),
        );

    testWidgets('Stop works while the session can be controlled', (
      tester,
    ) async {
      var stops = 0;
      await tester.pumpWidget(view(canControl: true, onStop: () => stops++));
      await tester.tap(find.text('Stop'));
      expect(stops, 1);
    });

    testWidgets('Stop and Pause are disabled while ending', (tester) async {
      var stops = 0;
      await tester.pumpWidget(view(canControl: false, onStop: () => stops++));
      await tester.tap(find.text('Stop'));
      expect(stops, 0);
      expect(find.text('25:00'), findsOneWidget);
    });

    testWidgets('survives a short window without overflow', (tester) async {
      tester.view.physicalSize = const Size(900, 700); // ~300x233 dp at 3x
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(view(canControl: true, onStop: () {}));
      expect(tester.takeException(), isNull);
    });
  });
}
