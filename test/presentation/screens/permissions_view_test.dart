import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/core/theme/app_theme.dart';
import 'package:staylit/presentation/screens/permissions/permissions_view.dart';

PermissionItem item(
  String title,
  bool granted, {
  Future<void> Function()? onAllow,
}) => PermissionItem(
  icon: Icons.bar_chart_rounded,
  title: title,
  description: 'About $title',
  granted: granted,
  onAllow: onAllow ?? () async {},
);

void main() {
  testWidgets('counts granted permissions and runs Allow', (tester) async {
    var allowed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: PermissionsView(
            items: [
              item('Usage access', true),
              item('Notifications', false, onAllow: () async => allowed++),
            ],
            onComplete: () {},
            onWhy: () {},
          ),
        ),
      ),
    );

    expect(find.text('1 of 2 allowed'), findsOneWidget);
    expect(find.text('Allowed'), findsOneWidget);

    await tester.tap(find.text('Allow'));
    await tester.pump();
    expect(allowed, 1);
  });

  testWidgets('Complete setup and Why callbacks fire', (tester) async {
    var completed = 0;
    var why = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: PermissionsView(
            items: [item('Usage access', false)],
            onComplete: () => completed++,
            onWhy: () => why++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Complete setup'));
    await tester.tap(find.text('Why do you need these?'));
    expect(completed, 1);
    expect(why, 1);
  });
}
