import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/presentation/widgets/design/week_bar_chart.dart';

Widget _chart({
  required List<int> values,
  String tooltip = '',
  double? height,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          child: WeekBarChart(
            values: values,
            highlightIndex: values.length - 1,
            tooltip: tooltip,
            height: height ?? 52,
            barColor: const Color(0xFF000000),
            stripeBaseColor: const Color(0xFF000000),
            stripeColor: const Color(0xFFFFFFFF),
            tooltipBackground: const Color(0xFF000000),
            tooltipStyle: const TextStyle(fontSize: 10),
            semanticsLabel: 'chart',
          ),
        ),
      ),
    ),
  );
}

bool _barOfHeight(Symbol method, List<dynamic> args, double height) =>
    method == #drawRRect && ((args[0] as RRect).height - height).abs() < 0.01;

void main() {
  testWidgets('without a tooltip, bar heights follow the values', (
    tester,
  ) async {
    await tester.pumpWidget(_chart(values: const [0, 5, 10]));

    // 52 high, no tooltip room: 0 -> minimum 14, 5 of 10 -> 26. The last
    // (highlighted) bar is the striped, clipped one at the full 52.
    final chart = find.descendant(
      of: find.byType(WeekBarChart),
      matching: find.byType(CustomPaint),
    );
    expect(
      tester.renderObject(chart.first),
      paints
        ..something((m, a) => _barOfHeight(m, a, 14))
        ..something((m, a) => _barOfHeight(m, a, 26))
        ..something(
          (m, a) =>
              m == #clipRRect && ((a[0] as RRect).height - 52).abs() < 0.01,
        ),
    );
  });

  testWidgets('with a tooltip, room is kept above the bars', (tester) async {
    await tester.pumpWidget(
      _chart(values: const [0, 5, 10], tooltip: '10', height: 90),
    );

    // 90 - 38 = 52 for the bars.
    final chart = find.descendant(
      of: find.byType(WeekBarChart),
      matching: find.byType(CustomPaint),
    );
    expect(
      tester.renderObject(chart.first),
      paints
        ..something((m, a) => _barOfHeight(m, a, 14))
        ..something((m, a) => _barOfHeight(m, a, 26))
        ..something(
          (m, a) =>
              m == #clipRRect && ((a[0] as RRect).height - 52).abs() < 0.01,
        ),
    );
  });
}
