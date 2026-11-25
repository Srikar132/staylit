import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pace/core/router/app_router.dart';
import 'package:pace/core/theme/theme_context.dart';
import 'package:pace/models/audio_bottom_model.dart';
import 'package:pace/models/end_session_bottom_sheet.dart';
import 'package:pace/models/model_manager.dart';
import 'package:pace/presentation/providers/auth_provider.dart';
import 'package:pace/presentation/providers/focus_session_provider.dart';
import 'package:pace/presentation/screens/active_session/active_session_view.dart';
import 'package:pace/services/audio_service.dart';
import 'package:pace/widgets/allowed_apps_drawer.dart';

class ActiveFocusScreen extends ConsumerStatefulWidget {
  const ActiveFocusScreen({super.key});

  @override
  ConsumerState<ActiveFocusScreen> createState() => _ActiveFocusScreenState();
}

class _ActiveFocusScreenState extends ConsumerState<ActiveFocusScreen> {
  final AudioService _audioService = AudioService();

  // KEY FIX: Track if navigation is already in progress
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    // Play haptic vibration and sound when session starts
    _playSessionStartFeedback();
  }

  Future<void> _playSessionStartFeedback() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      // Play haptic feedback
      await HapticFeedback.vibrate();

      // Play focus start sound
      await _audioService.playFocusStartSound();
    } catch (e) {
      debugPrint('Error playing session start feedback: $e');
    }
  }

  Future<void> _pauseSession() async {
    try {
      await ref.read(focusSessionProvider.notifier).pauseSession();
    } catch (e) {
      debugPrint('Error pausing session: $e');
      _showErrorSnackBar('Failed to pause session');
    }
  }

  Future<void> _resumeSession() async {
    try {
      await ref.read(focusSessionProvider.notifier).resumeSession();
    } catch (e) {
      debugPrint('Error resuming session: $e');
      _showErrorSnackBar('Failed to resume session');
    }
  }

  void _showAllowedAppsDrawer() {
    final user = ref.read(currentUserProvider).value;
    if (user != null) {
      BottomSheetManager.show(
        context: context,
        height: MediaQuery.of(context).size.height * 0.75,
        child: AllowedAppsDrawer(userId: user.uid),
      );
    }
  }

  Future<void> _endSession() async {
    final confirmed = await BottomSheetManager.show<bool>(
      context: context,
      height: 300,
      child: const EndSessionBottomSheet(),
    );

    if (confirmed == true && mounted) {
      try {
        debugPrint('🎯 _endSession: Calling endSession()');
        await ref.read(focusSessionProvider.notifier).endSession();
        debugPrint(
          '🎯 _endSession: endSession() completed, listener will handle navigation',
        );
      } catch (e) {
        debugPrint('Error ending session: $e');
        _showErrorSnackBar('Failed to end session');
      }
    }
  }

  void _showAudioBottomSheet() {
    BottomSheetManager.show(context: context, child: const AudioBottomSheet());
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: context.palette.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // KEY FIX: Synchronous navigation without PostFrameCallback
  void _navigateToSaveScreen() {
    // Prevent duplicate navigation
    if (_isNavigating) {
      debugPrint('🎯 Navigation already in progress, skipping');
      return;
    }

    if (!mounted) {
      debugPrint('🎯 Widget not mounted, cannot navigate');
      return;
    }

    _isNavigating = true;
    debugPrint('🎯 Starting navigation to SaveSessionScreen');

    try {
      final sessionData = ref
          .read(focusSessionProvider.notifier)
          .getCurrentSessionData();

      debugPrint('🎯 Session data retrieved: $sessionData');

      // Use pushReplacement to replace current screen. Unlike Navigator's
      // pushReplacement, go_router's doesn't return a Future to await - this
      // widget gets disposed as part of the replacement anyway, so there's
      // nothing further to do once the call returns.
      context.pushReplacement(saveSessionRoute, extra: sessionData);
      _isNavigating = false;

      debugPrint('🎯 Navigation initiated successfully');
    } catch (e, stackTrace) {
      debugPrint('🎯 Error during navigation: $e');
      debugPrint('🎯 Stack trace: $stackTrace');
      _isNavigating = false;
    }
  }

  // KEY FIX: Synchronous navigation for completed state
  void _navigateToHome() {
    if (_isNavigating) {
      debugPrint('🎯 Navigation already in progress, skipping home navigation');
      return;
    }

    if (!mounted) {
      debugPrint('🎯 Widget not mounted, cannot navigate to home');
      return;
    }

    _isNavigating = true;
    debugPrint('🎯 Navigating to home');

    // Reached via context.push() from FocusScreen -> pop back to it.
    // Reached via the router's redirect (cold start into an already-active
    // session) -> nothing to pop back to, go home directly.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(homeRoute);
    }

    _isNavigating = false;
  }

  static String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(focusSessionProvider);

    // KEY FIX: Listen and navigate immediately in the same frame
    ref.listen<FocusSessionState>(focusSessionProvider, (previous, next) {
      if (previous?.status == next.status) return;

      debugPrint(
        '🎯 ActiveFocusScreen: Status changed from ${previous?.status} to ${next.status}',
      );

      // Handle endingWithSave - navigate to save screen
      if (next.status == FocusSessionStatus.endingWithSave) {
        debugPrint('🎯 ActiveFocusScreen: Detected endingWithSave status');
        // Call navigation immediately, no PostFrameCallback
        _navigateToSaveScreen();
      }
      // Handle completed and idle states - go back to home
      else if (next.status == FocusSessionStatus.completed ||
          next.status == FocusSessionStatus.idle) {
        debugPrint(
          '🎯 ActiveFocusScreen: Navigating to home (status: ${next.status})',
        );
        _navigateToHome();
      }
    });

    final type = (sessionState.sessionType ?? 'timer').toLowerCase();
    final isPaused = sessionState.status == FocusSessionStatus.paused;
    final isActive = sessionState.status == FocusSessionStatus.active;
    final elapsed = sessionState.elapsedSeconds ?? 0;
    final remaining = sessionState.remainingSeconds ?? 0;
    final planned = sessionState.plannedDuration ?? 0;

    // Timers count down; stopwatch and pomodoro show elapsed time. The
    // stopwatch has no end, so its ring makes one lap per hour.
    final countsDown = type == 'timer';
    final progress = type == 'stopwatch'
        ? (elapsed % 3600) / 3600
        : planned > 0
        ? (elapsed / (planned * 60)).clamp(0.0, 1.0)
        : 0.0;

    final (typeLabel, typeIcon, timerLabel, runningText) = switch (type) {
      'stopwatch' => (
        'Stopwatch',
        Icons.access_time_outlined,
        'Elapsed Time',
        'Tracking time',
      ),
      'pomodoro' => (
        'Pomodoro',
        Icons.local_fire_department_outlined,
        'Focus Time',
        'Focus mode',
      ),
      _ => ('Timer', Icons.timer_outlined, 'Time Left', 'Counting down'),
    };

    final (messageTitle, messageBody) = SessionMessages.pick(
      elapsedMinutes: sessionState.elapsedMinutes,
      paused: isPaused,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool result, dynamic dya) {
        _playSessionStartFeedback();
      },
      child: Material(
        color: context.palette.canvas,
        child: ActiveSessionView(
          typeLabel: typeLabel,
          typeIcon: typeIcon,
          timerLabel: timerLabel,
          timeText: _formatTime(countsDown ? remaining : elapsed),
          statusText: isPaused ? 'Paused' : runningText,
          progress: progress,
          paused: isPaused,
          canControl: isActive || isPaused,
          messageTitle: messageTitle,
          messageBody: messageBody,
          onApps: _showAllowedAppsDrawer,
          onAmbient: _showAudioBottomSheet,
          onPauseResume: isPaused ? _resumeSession : _pauseSession,
          onStop: _endSession,
        ),
      ),
    );
  }
}
