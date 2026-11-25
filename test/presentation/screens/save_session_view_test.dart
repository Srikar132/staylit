import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/core/theme/app_theme.dart';
import 'package:staylit/presentation/screens/save_session/save_session_view.dart';

Widget host({
  required bool auto,
  VoidCallback? onSave,
  VoidCallback? onDiscard,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: SaveSessionView(
        data: SaveSessionData(
          focusMinutes: 25,
          plannedMinutes: 25,
          interruptions: 2,
          timeRange: '9:10 AM - 9:35 AM',
          autoCompleted: auto,
        ),
        notesController: TextEditingController(),
        tags: const ['Study', 'Work'],
        selectedTag: 'Study',
        onTag: (_) {},
        saving: false,
        onSave: onSave ?? () {},
        onDiscard: onDiscard ?? () {},
      ),
    ),
  );
}

void main() {
  testWidgets('manual end offers Save and Discard', (tester) async {
    var saved = 0;
    var discarded = 0;
    await tester.pumpWidget(
      host(auto: false, onSave: () => saved++, onDiscard: () => discarded++),
    );

    expect(find.text('Save session'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.tap(find.text('Discard session'));
    expect(saved, 1);
    expect(discarded, 1);
  });

  testWidgets('a session that finished by itself cannot be discarded', (
    tester,
  ) async {
    await tester.pumpWidget(host(auto: true));

    expect(find.text('Session complete'), findsOneWidget);
    expect(find.text('Discard session'), findsNothing);
    expect(find.text('Save'), findsOneWidget);
  });
}
