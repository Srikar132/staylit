// Developer tool, not a regression test: renders full screens (with mock data
// and provider overrides) to PNG so they can be reviewed without a device.
//
//   PREVIEW_DIR=C:/some/dir flutter test test/design/screens_preview_test.dart
//
// Does nothing (and passes) when PREVIEW_DIR is not set.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/core/theme/app_theme.dart';
import 'package:staylit/data/models/focus_session_model.dart';
import 'package:staylit/presentation/screens/focus/focus_home_data.dart';
import 'package:staylit/presentation/screens/progress/progress_view.dart';

final String? _outDir = Platform.environment['PREVIEW_DIR'];

Future<void> _loadFonts() async {
  final loader = FontLoader('SpaceGrotesk');
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/SpaceGrotesk-$weight.ttf'));
  }
  await loader.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final file = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (file.existsSync()) {
      final icons = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      await icons.load();
    }
  }
}

Future<void> _snapshot(
  WidgetTester tester, {
  required String name,
  required Widget child,
  required Brightness brightness,
  List<Override> overrides = const [],
  Size logicalSize = const Size(360, 800),
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = logicalSize * 3;
  addTearDown(tester.view.reset);

  final boundaryKey = GlobalKey();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        home: RepaintBoundary(key: boundaryKey, child: child),
      ),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 600)),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));

  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await File('$_outDir/$name.png').writeAsBytes(bytes.buffer.asUint8List());
  });
}

HistoryEntry _entry(
  int daysAgo,
  int hour,
  String? tag,
  String status,
  int min,
) {
  final start = DateTime.now()
      .subtract(Duration(days: daysAgo))
      .copyWith(hour: hour, minute: 10);
  return HistoryEntry(
    day: start,
    tile: SessionTileData.fromSession(
      FocusSessionModel(
        sessionId: '$daysAgo$hour',
        userId: 'u',
        startTime: start,
        plannedDuration: 25,
        actualDuration: min,
        sessionType: 'timer',
        status: status,
        date: 'x',
        tag: tag,
      ),
    ),
  );
}

ProgressData _progress({bool empty = false}) => ProgressData(
  currentStreak: empty ? 0 : 4,
  longestStreak: empty ? 0 : 9,
  weekMinutes: empty
      ? const [0, 0, 0, 0, 0, 0, 0]
      : const [40, 75, 0, 120, 50, 95, 60],
  distractingTodayText: '2h 45m',
  history: empty
      ? const []
      : [
          _entry(0, 9, 'Study', SessionStatus.completed, 25),
          _entry(0, 14, null, SessionStatus.endedEarly, 12),
          _entry(1, 20, 'Reading', SessionStatus.completed, 50),
          _entry(3, 8, 'Study', SessionStatus.completed, 25),
        ],
);

void main() {
  final enabled = _outDir != null;

  testWidgets('progress previews', (tester) async {
    if (!enabled) return;
    await tester.runAsync(_loadFonts);
    for (final b in Brightness.values) {
      await _snapshot(
        tester,
        name: 'progress_${b.name}',
        child: Scaffold(
          body: ProgressView(data: _progress(), onRefresh: () async {}),
        ),
        brightness: b,
      );
    }
    await _snapshot(
      tester,
      name: 'progress_empty_light',
      child: Scaffold(
        body: ProgressView(
          data: _progress(empty: true),
          onRefresh: () async {},
        ),
      ),
      brightness: Brightness.light,
    );
  }, skip: !enabled);
}
