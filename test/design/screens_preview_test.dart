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
import 'package:staylit/data/models/app_limit_model.dart';
import 'package:staylit/data/models/blocked_content_model.dart';
import 'package:staylit/data/models/focus_session_model.dart';
import 'package:staylit/data/models/pomodoro_settings.dart';
import 'package:staylit/data/models/user_model.dart';
import 'package:staylit/data/models/user_settings_model.dart';
import 'package:staylit/data/models/installed_app_model.dart';
import 'package:staylit/models/block_app_bottom_model.dart';
import 'package:staylit/models/focus_time_bottom_model.dart';
import 'package:staylit/presentation/overlays/widgets/actions_buttons.dart';
import 'package:staylit/presentation/overlays/widgets/block_header.dart';
import 'package:staylit/presentation/overlays/widgets/focus_timer_widget.dart';
import 'package:staylit/presentation/overlays/widgets/motivational_message.dart';
import 'package:staylit/presentation/overlays/widgets/overlay_background.dart';
import 'package:staylit/presentation/widgets/design/lit_badge.dart';
import 'package:staylit/presentation/providers/settings_provider.dart';
import 'package:staylit/presentation/providers/app_management_provide.dart'
    show appIconProvider, groupedAppsProvider, installedAppsProvider;
import 'package:staylit/presentation/providers/app_limits_provider.dart';
import 'package:staylit/presentation/widgets/design/app_icon_badge.dart';
import 'package:staylit/presentation/widgets/design/limit_setup_sheet.dart';
import 'package:staylit/presentation/providers/auth_provider.dart';
import 'package:staylit/presentation/providers/blocked_content_provider.dart';
import 'package:staylit/presentation/screens/blocks_screen.dart';
import 'package:staylit/presentation/screens/focus/focus_home_data.dart';
import 'package:staylit/presentation/screens/groups/group_detail_view.dart';
import 'package:staylit/presentation/screens/groups/groups_view.dart';
import 'package:staylit/presentation/screens/profile/profile_view.dart';
import 'package:staylit/presentation/screens/progress/progress_view.dart';
import 'package:staylit/widgets/parental_control_dialogs.dart';
import 'package:staylit/presentation/screens/save_session/save_session_view.dart';

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

/// A stand-in launcher icon: a rounded gradient square with a glyph-like dot.
Future<Uint8List> _fakeIcon(Color a, Color b) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const size = 192.0;
  final rect = RRect.fromRectAndRadius(
    const Rect.fromLTWH(0, 0, size, size),
    const Radius.circular(44),
  );
  canvas.drawRRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, const Offset(size, size), [
        a,
        b,
      ]),
  );
  canvas.drawCircle(
    const Offset(size / 2, size / 2),
    38,
    Paint()..color = const Color(0xFFFFFFFF),
  );
  final image = await recorder.endRecording().toImage(
    size.toInt(),
    size.toInt(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
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

  testWidgets('groups previews', (tester) async {
    if (!enabled) return;
    await tester.runAsync(_loadFonts);
    const mine = [
      GroupTileData(
        id: '1',
        name: 'Study Squad',
        memberCount: 8,
        focusTimeText: '42h 30m',
      ),
      GroupTileData(
        id: '2',
        name: 'Early Birds',
        memberCount: 3,
        focusTimeText: '6h',
      ),
    ];
    const suggested = [
      GroupTileData(
        id: '3',
        name: 'Deep Work Club',
        memberCount: 120,
        focusTimeText: '980h 15m',
      ),
    ];
    for (final b in Brightness.values) {
      await _snapshot(
        tester,
        name: 'groups_${b.name}',
        child: Scaffold(
          body: GroupsView(
            yourGroups: mine,
            suggested: suggested,
            onSearch: () {},
            onCreate: () {},
            onOpen: (_) {},
          ),
        ),
        brightness: b,
      );
    }
    await _snapshot(
      tester,
      name: 'groups_empty_light',
      child: Scaffold(
        body: GroupsView(
          yourGroups: const [],
          suggested: const [],
          onSearch: () {},
          onCreate: () {},
          onOpen: (_) {},
        ),
      ),
      brightness: Brightness.light,
    );
  }, skip: !enabled);

  testWidgets('blocks previews', (tester) async {
    if (!enabled) return;
    await tester.runAsync(_loadFonts);
    final user = UserModel(
      uid: 'u1',
      email: 'a@b.c',
      createdAt: DateTime(2026),
      lastLoginAt: DateTime(2026),
    );
    final igIcon = await tester.runAsync(
      () => _fakeIcon(const Color(0xFFF58529), const Color(0xFFDD2A7B)),
    );
    final ytIcon = await tester.runAsync(
      () => _fakeIcon(const Color(0xFFFF0033), const Color(0xFFB00020)),
    );
    final ttIcon = await tester.runAsync(
      () => _fakeIcon(const Color(0xFF111111), const Color(0xFF25F4EE)),
    );
    final fbIcon = await tester.runAsync(
      () => _fakeIcon(const Color(0xFF1877F2), const Color(0xFF0B4FB5)),
    );
    final overrides = <Override>[
      appIconProvider('com.instagram.android')
          .overrideWith((ref) async => igIcon),
      appIconProvider('com.google.android.youtube')
          .overrideWith((ref) async => ytIcon),
      appIconProvider('com.zhiliaoapp.musically')
          .overrideWith((ref) async => ttIcon),
      appIconProvider('com.facebook.katana')
          .overrideWith((ref) async => fbIcon),
      currentUserProvider.overrideWith((ref) => Stream.value(user)),
      appLimitsProvider('u1').overrideWith(
        (ref) => Stream.value([
          AppLimitModel(
            packageName: 'com.instagram.android',
            appName: 'Instagram',
            dailyLimit: 60,
            weeklyLimit: 420,
          ),
          AppLimitModel(
            packageName: 'com.google.android.youtube',
            appName: 'YouTube',
            dailyLimit: 45,
            weeklyLimit: 315,
            isActive: false,
          ),
        ]),
      ),
      blockedContentProvider('u1').overrideWith(
        (ref) => Stream.value(
          BlockedContentModel(
            blockedWebsites: [
              BlockedWebsite(url: 'reddit.com', name: 'Reddit'),
              BlockedWebsite(url: 'x.com', name: 'X', isActive: false),
            ],
            shortFormBlocks: {
              'youtube_shorts': ShortFormBlock(
                platform: 'youtube',
                feature: 'shorts',
              ),
            },
          ),
        ),
      ),
    ];
    for (final b in Brightness.values) {
      await _snapshot(
        tester,
        name: 'blocks_${b.name}',
        child: const BlocksScreen(),
        brightness: b,
        overrides: overrides,
        logicalSize: const Size(360, 1500),
      );
    }
  }, skip: !enabled);

  testWidgets('limit sheet previews', (tester) async {
    if (!enabled) return;
    await tester.runAsync(_loadFonts);
    final icon = await tester.runAsync(
      () => _fakeIcon(const Color(0xFFF58529), const Color(0xFFDD2A7B)),
    );
    for (final b in Brightness.values) {
      await _snapshot(
        tester,
        name: 'limit_sheet_${b.name}',
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: LimitSetupSheet(
              appName: 'Instagram',
              appIcon: AppIconBadge(name: 'Instagram', icon: icon),
              onSubmit: (_, _) {},
            ),
          ),
        ),
        brightness: b,
        logicalSize: const Size(360, 800),
      );
    }
  }, skip: !enabled);

  testWidgets('focus sheet previews', (tester) async {
    if (!enabled) return;
    await tester.runAsync(_loadFonts);
    final user = UserModel(
      uid: 'u1',
      email: 'a@b.c',
      createdAt: DateTime(2026),
      lastLoginAt: DateTime(2026),
    );
    final settings = UserSettingsModel(
      defaultDuration: 25,
      timerMode: 'timer',
      pomodoroSettings: PomodoroSettings.fromMap(null),
      numberOfBreaks: 1,
      blockPhoneHomeScreen: false,
      strictMode: false,
      autoStartBreaks: false,
      soundEnabled: true,
      vibrationEnabled: true,
    );
    final overrides = <Override>[
      currentUserProvider.overrideWith((ref) => Stream.value(user)),
      userSettingsProvider('u1').overrideWith((ref) => Stream.value(settings)),
      blockedContentProvider('u1')
          .overrideWith((ref) => Stream.value(BlockedContentModel())),
    ];
    for (final b in Brightness.values) {
      await _snapshot(
        tester,
        name: 'focus_sheet_${b.name}',
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: FocusTimeBottomSheet(onSave: () {}),
          ),
        ),
        brightness: b,
        overrides: overrides,
      );
    }
  }, skip: !enabled);

  testWidgets('overlay previews', (tester) async {
    if (!enabled) return;
    await tester.runAsync(_loadFonts);
    for (final b in Brightness.values) {
      await _snapshot(
        tester,
        name: 'overlay_${b.name}',
        child: Scaffold(
          body: OverlayBackground(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const LitBadge(size: 140),
                    const SizedBox(height: 28),
                    const BlockHeader(
                      title: 'Instagram is blocked',
                      chip: 'Focus mode active',
                    ),
                    const SizedBox(height: 24),
                    const FocusTimerWidget(
                      elapsedMinutes: 42,
                      sessionType: 'timer',
                    ),
                    const SizedBox(height: 24),
                    const MotivationalMessage(
                      message: 'Stay focused on what truly matters!',
                    ),
                    const SizedBox(height: 32),
                    ActionButtons(
                      onGoHome: () {},
                      onEndSession: () {},
                      onShowEducation: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        brightness: b,
      );
    }
  }, skip: !enabled);

  testWidgets('save session previews', (tester) async {
    if (!enabled) return;
    await tester.runAsync(_loadFonts);
    for (final auto in [true, false]) {
      for (final b in Brightness.values) {
        await _snapshot(
          tester,
          name: 'save_${auto ? 'auto' : 'manual'}_${b.name}',
          child: Scaffold(
            body: SaveSessionView(
              data: SaveSessionData(
                focusMinutes: 25,
                plannedMinutes: 25,
                interruptions: 2,
                timeRange: '9:10 AM - 9:35 AM',
                autoCompleted: auto,
              ),
              notesController: TextEditingController(),
              tags: const ['Study', 'Work', 'Reading', 'Coding', 'Other'],
              selectedTag: 'Study',
              onTag: (_) {},
              saving: false,
              onSave: () {},
              onDiscard: () {},
            ),
          ),
          brightness: b,
        );
      }
    }
  }, skip: !enabled);

  testWidgets('profile and dialog previews', (tester) async {
    if (!enabled) return;
    await tester.runAsync(_loadFonts);
    for (final b in Brightness.values) {
      await _snapshot(
        tester,
        name: 'profile_${b.name}',
        child: Scaffold(
          body: ProfileView(
            data: const ProfileData(
              name: 'Srikar Chinthala',
              email: 'srikar@example.com',
              photoUrl: null,
              focusMinutes: 735,
              sessions: 31,
              currentStreak: 4,
              parentalEnabled: true,
              appearanceLabel: 'System',
            ),
            onBack: () {},
            onAppearance: () {},
            onParentalChanged: (_) {},
            onChangePassword: () {},
            onSignOut: () {},
          ),
        ),
        brightness: b,
      );
      await _snapshot(
        tester,
        name: 'dialog_${b.name}',
        child: Scaffold(
          body: Center(child: CreatePasswordDialog(onConfirm: (_) {})),
        ),
        brightness: b,
      );
    }
  }, skip: !enabled);

  testWidgets('block apps sheet previews', (tester) async {
    if (!enabled) return;
    await tester.runAsync(_loadFonts);
    final user = UserModel(
      uid: 'u1',
      email: 'a@b.c',
      createdAt: DateTime(2026),
      lastLoginAt: DateTime(2026),
    );
    InstalledApp app(String name, String pkg, String category) => InstalledApp(
      appName: name,
      packageName: pkg,
      versionName: '1',
      installTime: 0,
      updateTime: 0,
      isSystemApp: false,
      category: category,
      canLaunch: true,
    );
    final grouped = {
      'Social': [
        app('Instagram', 'com.instagram.android', 'Social'),
        app('Snapchat', 'com.snapchat.android', 'Social'),
        app('WhatsApp', 'com.whatsapp', 'Social'),
      ],
      'Video': [
        app('YouTube', 'com.google.android.youtube', 'Video'),
        app('Netflix', 'com.netflix.mediaclient', 'Video'),
      ],
    };
    final ig = await tester.runAsync(
      () => _fakeIcon(const Color(0xFFF58529), const Color(0xFFDD2A7B)),
    );
    final overrides = <Override>[
      currentUserProvider.overrideWith((ref) => Stream.value(user)),
      groupedAppsProvider.overrideWithValue(grouped),
      installedAppsProvider.overrideWith(
        (ref) async => [for (final list in grouped.values) ...list],
      ),
      appIconProvider('com.instagram.android').overrideWith((ref) async => ig),
      blockedContentProvider('u1').overrideWith(
        (ref) => Stream.value(
          BlockedContentModel(
            permanentlyBlockedApps: [
              'com.instagram.android',
              'com.snapchat.android',
            ],
          ),
        ),
      ),
    ];
    for (final b in Brightness.values) {
      await _snapshot(
        tester,
        name: 'block_apps_${b.name}',
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: const BlockAppsSheet(),
          ),
        ),
        brightness: b,
        overrides: overrides,
      );
    }
  }, skip: !enabled);

  testWidgets('group detail previews', (tester) async {
    if (!enabled) return;
    await tester.runAsync(_loadFonts);
    const members = [
      MemberTileData(
        name: 'Asha',
        focusText: '14h 20m',
        isAdmin: true,
        isMe: false,
      ),
      MemberTileData(
        name: 'Srikar',
        focusText: '12h 5m',
        isAdmin: false,
        isMe: true,
      ),
      MemberTileData(
        name: 'Ravi',
        focusText: '8h',
        isAdmin: false,
        isMe: false,
      ),
      MemberTileData(
        name: 'Meera',
        focusText: '3h 40m',
        isAdmin: false,
        isMe: false,
      ),
    ];
    for (final b in Brightness.values) {
      await _snapshot(
        tester,
        name: 'group_detail_${b.name}',
        child: Scaffold(
          body: GroupDetailView(
            data: const GroupDetailData(
              name: 'Study Squad',
              description: 'Daily deep work sessions before exams.',
              memberCount: 4,
              totalFocusText: '38h',
              goalText: '2h',
              isPublic: true,
              isMember: true,
              isCreator: false,
              showLeaderboard: true,
              members: members,
            ),
            onBack: () {},
            onShare: () {},
            onDelete: () {},
            onJoin: () {},
            onLeave: () {},
          ),
        ),
        brightness: b,
      );
    }
  }, skip: !enabled);
}
