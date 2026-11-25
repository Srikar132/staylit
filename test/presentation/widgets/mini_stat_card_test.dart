import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/core/theme/app_theme.dart';
import 'package:staylit/presentation/widgets/design/mini_stat_card.dart';

Widget host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: SizedBox(width: 170, child: child)),
);

void main() {
  testWidgets('shows value, caption and trend, and is tappable', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        MiniStatCard(
          icon: Icons.local_fire_department_rounded,
          label: 'Streak',
          value: '4',
          caption: 'days',
          trendText: 'Keep going',
          values: const [1, 0, 2, 1, 3, 1, 2],
          onTap: () => taps++,
        ),
      ),
    );

    expect(find.text('4'), findsOneWidget);
    expect(find.text('days'), findsOneWidget);
    expect(find.text('Keep going'), findsOneWidget);
    await tester.tap(find.text('Streak'));
    expect(taps, 1);
  });

  testWidgets('off state shows the call to action instead of data', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        MiniStatCard(
          icon: Icons.swipe_vertical_rounded,
          label: 'Scroll damage',
          caption: 'Counts the shorts you scroll past',
          offLabel: 'Turn on',
          onTap: () {},
        ),
      ),
    );

    expect(find.text('Turn on'), findsOneWidget);
    expect(find.text('Counts the shorts you scroll past'), findsOneWidget);
  });
}
