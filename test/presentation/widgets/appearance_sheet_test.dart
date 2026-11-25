import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/core/theme/app_palette.dart';
import 'package:staylit/core/theme/app_theme.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/data/repositories/theme_repository.dart';
import 'package:staylit/presentation/providers/theme_mode_provider.dart';
import 'package:staylit/presentation/widgets/appearance_sheet.dart';

class _MemoryThemeRepository implements ThemeRepository {
  ThemeMode stored = ThemeMode.system;

  @override
  Future<ThemeMode> load() async => stored;

  @override
  Future<void> save(ThemeMode mode) async => stored = mode;
}

/// Mirrors how `StaylitApp` wires the theme, around a probe widget.
class _TestApp extends ConsumerWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      home: const Scaffold(
        body: Column(children: [AppearanceTile(), _BrightnessProbe()]),
      ),
    );
  }
}

class _BrightnessProbe extends StatelessWidget {
  const _BrightnessProbe();

  @override
  Widget build(BuildContext context) {
    return Text(
      '${Theme.of(context).brightness.name}|${context.palette == AppPalette.dark}',
    );
  }
}

Widget _buildApp(_MemoryThemeRepository repository, {ThemeMode? initial}) {
  return ProviderScope(
    overrides: [
      initialThemeModeProvider.overrideWithValue(initial ?? ThemeMode.system),
      themeRepositoryProvider.overrideWithValue(repository),
    ],
    child: const _TestApp(),
  );
}

void main() {
  testWidgets('follows the platform brightness while mode is System', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(_buildApp(_MemoryThemeRepository()));

    expect(find.text('dark|true'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
  });

  testWidgets('choosing Dark then Light in the sheet switches the theme and '
      'persists', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final repository = _MemoryThemeRepository();

    await tester.pumpWidget(_buildApp(repository));
    expect(find.text('light|false'), findsOneWidget);

    await tester.tap(find.byType(AppearanceTile));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(find.text('dark|true'), findsOneWidget);
    expect(repository.stored, ThemeMode.dark);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(find.text('light|false'), findsOneWidget);
    expect(repository.stored, ThemeMode.light);
  });

  testWidgets('starts in the injected mode regardless of the platform', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      _buildApp(_MemoryThemeRepository(), initial: ThemeMode.dark),
    );

    expect(find.text('dark|true'), findsOneWidget);
  });
}
