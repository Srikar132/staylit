// Developer tool, not a regression test: renders design-system widgets to PNG
// files so they can be reviewed without a device.
//
//   PREVIEW_DIR=C:/some/dir flutter test test/design/preview_render_test.dart
//
// Does nothing (and passes) when PREVIEW_DIR is not set.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/app_theme.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/screens/active_session/active_session_view.dart';
import 'package:staylit/presentation/screens/focus/focus_home_data.dart';
import 'package:staylit/presentation/screens/focus/focus_home_view.dart';
import 'package:staylit/presentation/screens/welcome_screen.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';
import 'package:staylit/presentation/widgets/design/black_bottom_nav.dart';
import 'package:staylit/presentation/widgets/design/control_dock.dart';
import 'package:staylit/presentation/widgets/design/focus_ring_timer.dart';
import 'package:staylit/presentation/widgets/design/goal_card.dart';
import 'package:staylit/presentation/widgets/design/hero_panel.dart';
import 'package:staylit/presentation/widgets/design/icon_circle_button.dart';
import 'package:staylit/presentation/widgets/design/message_card.dart';
import 'package:staylit/presentation/widgets/design/pill_chip.dart';
import 'package:staylit/presentation/widgets/design/scalloped.dart';
import 'package:staylit/presentation/widgets/design/session_card.dart';

final String? _outDir = Platform.environment['PREVIEW_DIR'];

Future<void> _loadFonts() async {
  final loader = FontLoader('SpaceGrotesk');
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/SpaceGrotesk-$weight.ttf'));
  }
  await loader.load();

  // Material icons, so icons render as glyphs instead of boxes.
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
  Size logicalSize = const Size(360, 800),
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = logicalSize * 3;
  addTearDown(tester.view.reset);

  final boundaryKey = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      home: RepaintBoundary(key: boundaryKey, child: child),
    ),
  );
  // Let asset images finish decoding (it happens off the fake-async clock).
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 600)),
  );
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

class _ComponentSheet extends StatelessWidget {
  const _ComponentSheet();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Row(
              children: [
                IconCircleButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onPressed: () {},
                  semanticLabel: 'Back',
                ),
                const SizedBox(width: 12),
                const PillChip(
                  label: 'Pomodoro',
                  icon: Icons.grid_view_rounded,
                  showChevron: true,
                ),
                const Spacer(),
                IconCircleButton(
                  icon: Icons.notifications_none_rounded,
                  onPressed: () {},
                  semanticLabel: 'Notifications',
                  showDot: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            GoalCard(
              goalMinutes: 150,
              todayMinutes: 112,
              weekMinutes: const [60, 35, 90, 120, 150, 40, 112],
              onEditGoal: () {},
            ),
            const SizedBox(height: 16),
            const SessionCard(
              title: 'Algebra',
              subtitle: '9:41 AM · Completed',
              minutes: 52,
            ),
            const SizedBox(height: 8),
            const SessionCard(
              title: 'Untagged',
              subtitle: '2:10 PM · Ended early',
              minutes: 18,
              icon: Icons.timelapse_rounded,
            ),
            const SizedBox(height: 16),
            const MessageCard(
              title: "You're doing great!",
              body: 'Stay in zone. Amazing things happen when you focus.',
            ),
            const SizedBox(height: 16),
            AppPillButton(label: 'Start Focus Session', onPressed: () {}),
            const SizedBox(height: 8),
            AppPillButton(
              label: 'Secondary',
              variant: PillButtonVariant.outline,
              onPressed: () {},
            ),
            const SizedBox(height: 16),
            ScallopedProgressStrip(
              progress: 0.6,
              fillColor: palette.ink,
              trackColor: palette.surfaceTrack,
            ),
            ControlDock(
              children: [
                ControlButton(
                  icon: Icons.volume_up_outlined,
                  label: 'Ambient',
                  onPressed: () {},
                ),
                ControlButton(
                  icon: Icons.pause_rounded,
                  label: 'Pause',
                  large: true,
                  onPressed: () {},
                ),
                ControlButton(
                  icon: Icons.stop_rounded,
                  label: 'Stop',
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Center(
              child: FocusRingTimer(
                progress: 0.62,
                timeText: '25:00',
                label: 'Focus Time',
                chipText: 'Pomodoro 1 of 4',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: HeroPanel(
                child: Center(
                  child: Text(
                    'Hero panel',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(color: palette.onAccent),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            BlackBottomNav(
              selectedIndex: 0,
              onSelected: (_) {},
              items: const [
                BottomNavItem(
                  icon: Icons.center_focus_strong_outlined,
                  selectedIcon: Icons.center_focus_strong,
                  label: 'Focus',
                ),
                BottomNavItem(
                  icon: Icons.group_outlined,
                  selectedIcon: Icons.group,
                  label: 'Groups',
                ),
                BottomNavItem(
                  icon: Icons.block_outlined,
                  selectedIcon: Icons.block,
                  label: 'Blocks',
                ),
                BottomNavItem(
                  icon: Icons.bar_chart_outlined,
                  selectedIcon: Icons.bar_chart,
                  label: 'Usage',
                ),
                BottomNavItem(
                  icon: Icons.insights_outlined,
                  selectedIcon: Icons.insights,
                  label: 'Insights',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _focusHome({bool scrollOn = false}) => Scaffold(
  body: FocusHomeView(
    onProfile: () {},
    onEditGoal: () {},
    onSetup: () {},
    onStart: () {},
    onScrollDamage: () {},
    onSeeAll: () {},
    data: FocusHomeData(
      firstName: 'Jack',
      photoUrl: null,
      usageText: '2h 5m',
      goalMinutes: 150,
      todayMinutes: 112,
      todayBuckets: const [0, 0, 0, 0, 52, 0, 18, 0, 42, 0, 0, 0],
      currentBucket: 8,
      setupLabel: 'Timer · 25 min · 5 apps blocked',
      streak: 4,
      streakWeek: const [1, 0, 2, 1, 3, 1, 2],
      scrollDamage: scrollOn
          ? const ScrollDamageData(
              todayCount: 87,
              week: [140, 96, 210, 120, 160, 99, 87],
              trendText: '↓ 12% vs yesterday',
            )
          : null,
    ),
  ),
  bottomNavigationBar: const _Nav(),
);

class _Nav extends StatelessWidget {
  const _Nav();

  @override
  Widget build(BuildContext context) {
    return BlackBottomNav(
      selectedIndex: 0,
      onSelected: (_) {},
      items: const [
        BottomNavItem(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          label: 'Focus',
        ),
        BottomNavItem(
          icon: Icons.groups_outlined,
          selectedIcon: Icons.groups_rounded,
          label: 'Groups',
        ),
        BottomNavItem(
          icon: Icons.shield_outlined,
          selectedIcon: Icons.shield_rounded,
          label: 'Blocks',
        ),
        BottomNavItem(
          icon: Icons.bar_chart_rounded,
          selectedIcon: Icons.bar_chart_rounded,
          label: 'Usage',
        ),
      ],
    );
  }
}

Widget _session({required bool paused}) => Builder(
  builder: (context) => Material(
    color: context.palette.canvas,
    child: ActiveSessionView(
      typeLabel: 'Pomodoro',
      typeIcon: Icons.local_fire_department_outlined,
      timerLabel: 'Focus Time',
      timeText: '25:00',
      statusText: paused ? 'Paused' : 'Focus mode',
      progress: 0.4,
      paused: paused,
      canControl: true,
      messageTitle: paused
          ? SessionMessages.paused.$1
          : SessionMessages.running.first.$1,
      messageBody: paused
          ? SessionMessages.paused.$2
          : SessionMessages.running.first.$2,
      onAmbient: () {},
      onPauseResume: () {},
      onStop: () {},
    ),
  ),
);

void main() {
  final enabled = _outDir != null && _outDir!.isNotEmpty;

  testWidgets('render component sheet (light)', skip: !enabled, (tester) async {
    await tester.runAsync(_loadFonts);
    await _snapshot(
      tester,
      name: 'components_light',
      child: const _ComponentSheet(),
      brightness: Brightness.light,
      logicalSize: const Size(360, 1900),
    );
  });

  testWidgets('render component sheet (dark)', skip: !enabled, (tester) async {
    await tester.runAsync(_loadFonts);
    await _snapshot(
      tester,
      name: 'components_dark',
      child: const _ComponentSheet(),
      brightness: Brightness.dark,
      logicalSize: const Size(360, 1900),
    );
  });

  for (final mode in [Brightness.light, Brightness.dark]) {
    final tag = mode.name;
    testWidgets('render focus home ($tag)', skip: !enabled, (tester) async {
      await tester.runAsync(_loadFonts);
      await _snapshot(
        tester,
        name: 'focus_home_$tag',
        child: _focusHome(),
        brightness: mode,
      );
    });
    testWidgets('render focus home scroll on ($tag)', skip: !enabled, (
      tester,
    ) async {
      await tester.runAsync(_loadFonts);
      await _snapshot(
        tester,
        name: 'focus_home_scroll_$tag',
        child: _focusHome(scrollOn: true),
        brightness: mode,
      );
    });
    testWidgets('render session ($tag)', skip: !enabled, (tester) async {
      await tester.runAsync(_loadFonts);
      await _snapshot(
        tester,
        name: 'session_$tag',
        child: _session(paused: false),
        brightness: mode,
      );
    });
    testWidgets('render welcome ($tag)', skip: !enabled, (tester) async {
      await tester.runAsync(_loadFonts);
      await _snapshot(
        tester,
        name: 'welcome_$tag',
        child: const WelcomeScreen(),
        brightness: mode,
      );
    });
  }

  testWidgets('render session paused (dark)', skip: !enabled, (tester) async {
    await tester.runAsync(_loadFonts);
    await _snapshot(
      tester,
      name: 'session_paused_dark',
      child: _session(paused: true),
      brightness: Brightness.dark,
    );
  });
}
