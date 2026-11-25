import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';

/// "Focus time 12m" on a near-black pill.
class FocusTimerWidget extends StatelessWidget {
  final int elapsedMinutes;
  final String sessionType;
  final bool compact;

  const FocusTimerWidget({
    super.key,
    required this.elapsedMinutes,
    required this.sessionType,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: compact ? AppSpacing.sm : AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: palette.ink,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(sessionType), color: palette.onInk, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Focus time',
            style: textTheme.bodyMedium?.copyWith(
              color: palette.onInk.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            _format(elapsedMinutes),
            style: textTheme.titleLarge?.copyWith(color: palette.onInk),
          ),
        ],
      ),
    );
  }

  static IconData _icon(String sessionType) =>
      switch (sessionType.toLowerCase()) {
        'stopwatch' => Icons.access_time_rounded,
        'pomodoro' => Icons.schedule_rounded,
        _ => Icons.timer_outlined,
      };

  static String _format(int minutes) {
    if (minutes < 60) return '${minutes}m';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }
}
