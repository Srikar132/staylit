import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/core/theme/app_theme.dart';
import 'package:staylit/data/models/user_settings_model.dart';
import 'package:staylit/data/models/pomodoro_settings.dart';
import 'package:staylit/presentation/screens/focus/scroll_mood.dart';
import 'package:staylit/presentation/widgets/design/scroll_damage_card.dart';
import 'package:staylit/presentation/widgets/scroll_damage_sheet.dart';

Widget host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  test('mood follows the count and never goes below calm', () {
    expect(ScrollMood.forCount(-5), ScrollMood.calm);
    expect(ScrollMood.forCount(0), ScrollMood.calm);
    expect(ScrollMood.forCount(19), ScrollMood.calm);
    expect(ScrollMood.forCount(20), ScrollMood.warmingUp);
    expect(ScrollMood.forCount(119), ScrollMood.hooked);
    expect(ScrollMood.forCount(199), ScrollMood.doomscrolling);
    expect(ScrollMood.forCount(500), ScrollMood.meltdown);
    expect(ScrollMood.meltdown.level, 5);
  });

  test('the setting defaults to off and round-trips', () {
    final settings = UserSettingsModel(
      defaultDuration: 25,
      timerMode: 'timer',
      pomodoroSettings: PomodoroSettings.defaultSettings(),
      numberOfBreaks: 1,
      blockPhoneHomeScreen: false,
      strictMode: false,
      autoStartBreaks: true,
      soundEnabled: true,
      vibrationEnabled: true,
    );
    expect(settings.scrollDamageEnabled, isFalse);
    final on = settings.copyWith(scrollDamageEnabled: true);
    expect(on.toFirestore()['scrollDamageEnabled'], isTrue);
    expect(on.copyWith(dailyGoalMinutes: 90).scrollDamageEnabled, isTrue);
  });

  testWidgets('card shows the invitation when off and the count when on', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(ScrollDamageCard(enabled: false, onTap: () {})),
    );
    expect(find.text('Turn on'), findsOneWidget);
    expect(find.text('See how far you scroll'), findsOneWidget);

    await tester.pumpWidget(
      host(
        ScrollDamageCard(
          enabled: true,
          todayCount: 87,
          week: const [10, 20, 87],
          onTap: () {},
        ),
      ),
    );
    expect(find.text('87'), findsOneWidget);
    expect(find.text('Getting hooked'), findsOneWidget);
  });

  testWidgets('sheet offers Turn on, or Allow accessibility first', (
    tester,
  ) async {
    var turnedOn = 0;
    var allow = 0;
    Widget sheet({required bool granted, bool enabled = false}) => host(
      ScrollDamageSheet(
        enabled: enabled,
        accessibilityGranted: granted,
        onTurnOn: () => turnedOn++,
        onTurnOff: () {},
        onAllowAccessibility: () => allow++,
        onClose: () {},
      ),
    );

    await tester.pumpWidget(sheet(granted: true));
    await tester.tap(find.text('Turn on'));
    expect(turnedOn, 1);

    await tester.pumpWidget(sheet(granted: false));
    await tester.tap(find.text('Allow accessibility'));
    expect(allow, 1);

    await tester.pumpWidget(sheet(granted: true, enabled: true));
    expect(find.text('Turn off'), findsOneWidget);
    expect(find.text('Turn on'), findsNothing);
  });
}
