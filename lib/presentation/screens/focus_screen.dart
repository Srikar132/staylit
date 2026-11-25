import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:staylit/core/router/app_router.dart'
    show profileRoute, activeSessionRoute;
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/data/models/user_model.dart';
import 'package:staylit/data/models/user_settings_model.dart';
import 'package:staylit/models/focus_time_bottom_model.dart';
import 'package:staylit/models/model_manager.dart';
import 'package:staylit/presentation/providers/auth_provider.dart';
import 'package:staylit/presentation/providers/blocked_content_provider.dart';
import 'package:staylit/presentation/providers/daily_stats_provider.dart';
import 'package:staylit/presentation/providers/focus_session_provider.dart';
import 'package:staylit/presentation/providers/home_tab_provider.dart';
import 'package:staylit/presentation/providers/settings_provider.dart';
import 'package:staylit/presentation/providers/usage_stats_provider.dart';
import 'package:staylit/presentation/screens/focus/focus_home_data.dart';
import 'package:staylit/presentation/screens/focus/focus_home_view.dart';
import 'package:staylit/presentation/screens/focus/today_buckets.dart';
import 'package:staylit/presentation/widgets/goal_sheet.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  // Show focus mode modal and handle session creation
  void _showFocusModeModal() {
    BottomSheetManager.show(
      context: context,
      child: FocusTimeBottomSheet(
        onSave: () async {
          // Start focus session and navigate to active screen
          await _startFocusSession();
        },
      ),
    );
  }

  // Start focus session with current settings
  Future<void> _startFocusSession() async {
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) return;

      final settingsAsync = ref.read(userSettingsProvider(user.uid));
      final settings = settingsAsync.value;

      if (settings == null) return;

      // Get blocked content from the proper blocked content provider
      final blockedContentAsync = ref.read(blockedContentProvider(user.uid));
      final blockedContent = blockedContentAsync.value;

      // Get permanently blocked apps from blocked content provider
      final allBlockedApps = blockedContent?.permanentlyBlockedApps ?? [];

      // Get blocked websites from blocked content provider
      final blockedWebsites =
          blockedContent?.blockedWebsites
              .where((w) => w.isActive)
              .map(
                (w) => {'url': w.url, 'name': w.name, 'isActive': w.isActive},
              )
              .toList() ??
          [];

      // Get short form blocks
      final shortFormBlocks = blockedContent?.shortFormBlocks ?? {};
      final shortFormBlocked = shortFormBlocks.values.any(
        (block) => block.isBlocked,
      );

      // Start the focus session using the provider
      await ref
          .read(focusSessionProvider.notifier)
          .startSession(
            plannedDuration: settings.defaultDuration,
            sessionType: settings.timerMode,
            blockedApps: allBlockedApps,
            blockedWebsites: blockedWebsites,
            shortFormBlocked: shortFormBlocked,
            notificationsBlocked: true, // Default to blocking notifications
          );

      // Navigate to active focus screen. startSession() above already
      // populated focusSessionProvider's state, which ActiveFocusScreen
      // reads directly - no need to pass session data through the route.
      if (mounted) {
        context.push(activeSessionRoute);
      }
    } catch (e) {
      debugPrint('Error starting focus session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start focus session: $e'),
            backgroundColor: context.palette.error,
          ),
        );
      }
    }
  }

  /// Opens the goal picker and saves the choice to the user's settings.
  Future<void> _editGoal(String userId, UserSettingsModel? settings) async {
    final chosen = await showGoalSheet(
      context,
      initialMinutes:
          settings?.dailyGoalMinutes ??
          UserSettingsModel.defaultDailyGoalMinutes,
    );
    if (chosen == null || settings == null) return;
    try {
      await ref
          .read(settingsRepositoryProvider)
          .updateSettings(userId, settings.copyWith(dailyGoalMinutes: chosen));
    } catch (e) {
      debugPrint('Error saving daily goal: $e');
    }
  }

  static String _modeLabel(String mode) => switch (mode) {
    'timer' => 'Timer',
    'stopwatch' => 'Stopwatch',
    'pomodoro' => 'Pomodoro',
    _ =>
      mode.isEmpty ? 'Timer' : '${mode[0].toUpperCase()}${mode.substring(1)}',
  };

  FocusHomeData _homeData(UserModel user) {
    final settings = ref.watch(userSettingsProvider(user.uid)).value;
    final week = ref.watch(weekStatsProvider(user.uid)).value;
    final streak = ref.watch(streakProvider(user.uid)).value;
    final sessions = ref.watch(todaySessionsProvider(user.uid)).value ?? [];
    final blocked = ref.watch(blockedContentProvider(user.uid)).value;
    final usage = ref.watch(todayUsageStatsProvider);

    final todayMinutes = week != null && week.isNotEmpty
        ? week.last.focusMinutes
        : 0;
    final blockedCount = blocked?.permanentlyBlockedApps.length ?? 0;
    final duration = settings?.defaultDuration ?? 25;
    final now = DateTime.now();

    final apps = blockedCount == 0
        ? 'No apps blocked'
        : '$blockedCount ${blockedCount == 1 ? 'app' : 'apps'} blocked';

    return FocusHomeData(
      firstName: user.firstName,
      photoUrl: user.photoURL,
      usageText: usage.when(
        data: (stats) => stats.formattedTotalTimeExcludingSelf,
        loading: () => '...',
        error: (_, _) => '0m',
      ),
      goalMinutes:
          settings?.dailyGoalMinutes ??
          UserSettingsModel.defaultDailyGoalMinutes,
      todayMinutes: todayMinutes,
      todayBuckets: bucketTodayMinutes([
        for (final s in sessions)
          if (s.actualDuration != null)
            (start: s.startTime, minutes: s.actualDuration!),
      ], day: now),
      currentBucket: currentBucket(now),
      setupLabel:
          '${_modeLabel(settings?.timerMode ?? 'timer')} · $duration min · $apps',
      streak: streak?.current ?? 0,
      streakWeek: week != null
          ? [for (final day in week) day.completedSessions]
          : List<int>.filled(7, 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Center(child: Text('Please login first'));
        }

        return FocusHomeView(
          data: _homeData(user),
          onProfile: () => context.push(profileRoute),
          onEditGoal: () => _editGoal(
            user.uid,
            ref.read(userSettingsProvider(user.uid)).value,
          ),
          onSetup: _showFocusModeModal,
          onStart: _showFocusModeModal,
          onScrollDamage: () =>
              ref.read(homeTabRequestProvider.notifier).request(HomeTab.blocks),
          onSeeAll: () => ref
              .read(homeTabRequestProvider.notifier)
              .request(HomeTab.progress),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) =>
          const Scaffold(body: Center(child: Text('Error loading user data'))),
    );
  }
}
