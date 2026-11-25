import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/core/theme/app_theme.dart';
import 'package:staylit/presentation/widgets/design/app_limit_card.dart';

Widget host(AppLimitCard card) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: card),
);

AppLimitCard card({
  int used = 10,
  int limit = 60,
  bool active = true,
  ValueChanged<bool>? onToggle,
}) => AppLimitCard(
  appName: 'Instagram',
  usedMinutes: used,
  limitMinutes: limit,
  isActive: active,
  onToggle: onToggle ?? (_) {},
  onMenu: () {},
);

void main() {
  test('status follows usage against the limit', () {
    expect(card(used: 10).status, AppLimitStatus.ok);
    expect(card(used: 50).status, AppLimitStatus.near);
    expect(card(used: 60).status, AppLimitStatus.exceeded);
    expect(card(active: false).status, AppLimitStatus.off);
  });

  test('format reads as hours and minutes', () {
    expect(AppLimitCard.format(65), '1h 5m');
    expect(AppLimitCard.format(45), '45m');
    expect(AppLimitCard.format(120), '2h');
    expect(AppLimitCard.format(-5), '0m');
  });

  testWidgets('shows time left and toggles', (tester) async {
    bool? toggled;
    await tester.pumpWidget(host(card(onToggle: (v) => toggled = v)));

    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('50m left today'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    expect(toggled, isFalse);
  });

  testWidgets('says the limit is reached and hides the bar when off', (
    tester,
  ) async {
    await tester.pumpWidget(host(card(used: 70)));
    expect(find.text('Limit reached'), findsOneWidget);

    await tester.pumpWidget(host(card(active: false)));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Off · 1h a day'), findsOneWidget);
  });
}
