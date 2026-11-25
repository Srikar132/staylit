import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/widgets/design/control_dock.dart';
import 'package:staylit/presentation/widgets/design/focus_ring_timer.dart';
import 'package:staylit/presentation/widgets/design/icon_circle_button.dart';
import 'package:staylit/presentation/widgets/design/message_card.dart';
import 'package:staylit/presentation/widgets/design/pill_chip.dart';
import 'package:staylit/presentation/widgets/design/scalloped.dart';
import 'package:staylit/presentation/widgets/design/lit_badge.dart';

/// Short encouragements shown under the timer.
abstract final class SessionMessages {
  static const List<(String, String)> running = [
    (
      "You're doing great!",
      'Stay in zone. Amazing things happen when you focus.',
    ),
    ('Deep work in progress', 'One thing at a time. The rest can wait.'),
    ('Keep the streak alive', 'Every focused minute adds up.'),
    ('Nice and steady', 'Distractions are blocked. Just keep going.'),
  ];

  static const (String, String) paused = (
    'Taking a breath',
    "Resume when you're ready. Your session is waiting.",
  );

  /// A message that changes every 5 minutes of focus, or the pause message.
  static (String, String) pick({
    required int elapsedMinutes,
    required bool paused,
  }) {
    if (paused) return SessionMessages.paused;
    final index = (elapsedMinutes < 0 ? 0 : elapsedMinutes) ~/ 5;
    return running[index % running.length];
  }
}

/// The active focus session screen: top bar, ring timer, encouragement, progress
/// strip and control dock. Pure presentation; the screen owns the session logic.
class ActiveSessionView extends StatelessWidget {
  const ActiveSessionView({
    super.key,
    required this.typeLabel,
    required this.typeIcon,
    required this.timerLabel,
    required this.timeText,
    required this.statusText,
    required this.progress,
    required this.paused,
    required this.canControl,
    required this.messageTitle,
    required this.messageBody,
    required this.onApps,
    required this.onAmbient,
    required this.onPauseResume,
    required this.onStop,
  });

  /// "Timer", "Stopwatch" or "Pomodoro".
  final String typeLabel;
  final IconData typeIcon;

  /// Caption above the time, e.g. "Time Left".
  final String timerLabel;
  final String timeText;

  /// Chip under the time, e.g. "Counting down" or "Paused".
  final String statusText;

  /// 0..1 around the ring and along the strip.
  final double progress;
  final bool paused;

  /// False while the session is starting or ending; disables the controls.
  final bool canControl;
  final String messageTitle;
  final String messageBody;
  final VoidCallback onApps;
  final VoidCallback onAmbient;
  final VoidCallback onPauseResume;
  final VoidCallback onStop;

  /// Below this window height the controls are no longer pinned: the whole
  /// screen scrolls instead, so nothing is ever clipped.
  static const double _compactHeight = 320;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return LayoutBuilder(
      builder: (context, constraints) {
        final ringSize = math.min(
          250.0,
          constraints.maxWidth - 2 * AppSpacing.xxl,
        );

        final topBar = SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              0,
            ),
            child: Row(
              children: [
                IconCircleButton(
                  icon: Icons.apps_rounded,
                  semanticLabel: 'Allowed apps',
                  onPressed: onApps,
                ),
                const Spacer(),
                PillChip(label: typeLabel, icon: typeIcon),
                const Spacer(),
                // Keeps the chip centered.
                const SizedBox(width: AppSizes.iconButton),
              ],
            ),
          ),
        );

        final middle = Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FocusRingTimer(
                size: ringSize,
                progress: progress,
                timeText: timeText,
                label: timerLabel,
                chipText: statusText,
                paused: paused,
              ),
              const SizedBox(height: AppSpacing.xl),
              MessageCard(
                leading: const LitBadge(size: 72),
                title: messageTitle,
                body: messageBody,
              ),
            ],
          ),
        );

        final strip = ScallopedProgressStrip(
          progress: progress,
          fillColor: palette.ink,
          trackColor: palette.surfaceTrack,
        );

        final dock = ControlDock(
          children: [
            ControlButton(
              icon: Icons.graphic_eq_rounded,
              label: 'Ambient',
              onPressed: onAmbient,
            ),
            ControlButton(
              icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              label: paused ? 'Resume' : 'Pause',
              large: true,
              onPressed: canControl ? onPauseResume : null,
            ),
            ControlButton(
              icon: Icons.stop_rounded,
              label: 'Stop',
              onPressed: canControl ? onStop : null,
            ),
          ],
        );

        if (constraints.maxHeight < _compactHeight) {
          return SingleChildScrollView(
            child: Column(children: [topBar, middle, strip, dock]),
          );
        }

        // Dock pinned at the bottom; only the middle scrolls when the window
        // is short (split-screen, floating).
        return Column(
          children: [
            topBar,
            Expanded(
              child: Center(child: SingleChildScrollView(child: middle)),
            ),
            strip,
            dock,
          ],
        );
      },
    );
  }
}
