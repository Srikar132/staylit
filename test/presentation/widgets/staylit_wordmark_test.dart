import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace/core/theme/app_palette.dart';
import 'package:pace/core/theme/app_theme.dart';
import 'package:pace/presentation/widgets/design/staylit_wordmark.dart';

Future<TextSpan> pumpWordmark(
  WidgetTester tester, {
  Color? stay,
  Color? lit,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(
        body: StaylitWordmark(stayColor: stay, litColor: lit),
      ),
    ),
  );
  final rich = tester.widget<RichText>(find.byType(RichText).first);
  // Text.rich wraps the given span in a styled root span.
  return (rich.text as TextSpan).children!.single as TextSpan;
}

void main() {
  testWidgets('spells "stay" + "lit" in two colors', (tester) async {
    final span = await pumpWordmark(tester);
    final parts = span.children!.cast<TextSpan>();
    expect(parts.map((p) => p.text), ['stay', 'lit']);
    expect(parts[0].style!.color, AppPalette.light.onCanvas);
    expect(parts[1].style!.color, AppPalette.light.accentText);
  });

  testWidgets('follows the theme in dark mode', (tester) async {
    final span = await pumpWordmark(tester, theme: AppTheme.dark);
    final parts = span.children!.cast<TextSpan>();
    expect(parts[0].style!.color, AppPalette.dark.onCanvas);
    expect(parts[1].style!.color, AppPalette.dark.accentText);
  });

  testWidgets('colors can be overridden (e.g. on the orange hero)', (
    tester,
  ) async {
    const stay = Color(0xFF111113);
    const lit = Color(0xFFFFFFFF);
    final span = await pumpWordmark(tester, stay: stay, lit: lit);
    final parts = span.children!.cast<TextSpan>();
    expect(parts[0].style!.color, stay);
    expect(parts[1].style!.color, lit);
  });

  testWidgets('is announced as one word to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpWordmark(tester);
    expect(find.bySemanticsLabel('Staylit'), findsOneWidget);
    handle.dispose();
  });
}
