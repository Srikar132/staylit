import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/core/theme/app_theme.dart';
import 'package:staylit/presentation/screens/onboarding/onboarding_layout.dart';
import 'package:staylit/presentation/widgets/design/option_card.dart';
import 'package:staylit/presentation/widgets/design/step_progress_bar.dart';

Widget host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('OptionCard reports taps and is labelled', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        OptionCard(title: 'Early Bird', selected: true, onTap: () => taps++),
      ),
    );

    await tester.tap(find.text('Early Bird'));
    expect(taps, 1);
    expect(find.bySemanticsLabel('Early Bird'), findsOneWidget);
  });

  testWidgets('StepProgressBar labels the current step', (tester) async {
    await tester.pumpWidget(
      host(const StepProgressBar(currentStep: 1, stepCount: 3)),
    );
    expect(find.bySemanticsLabel('Step 2 of 3'), findsOneWidget);
  });

  testWidgets('OnboardingQuestionLayout disables action until answered', (
    tester,
  ) async {
    var pressed = 0;
    Widget layout(VoidCallback? onAction) => host(
      OnboardingQuestionLayout(
        title: 'Question?',
        actionLabel: 'Continue',
        onAction: onAction,
        children: const [Text('answer')],
      ),
    );

    await tester.pumpWidget(layout(null));
    await tester.tap(find.text('Continue'));
    expect(pressed, 0);

    await tester.pumpWidget(layout(() => pressed++));
    await tester.tap(find.text('Continue'));
    expect(pressed, 1);
  });
}
