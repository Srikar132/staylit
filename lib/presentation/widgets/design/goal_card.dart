import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/widgets/design/duration_text.dart';
import 'package:staylit/presentation/widgets/design/week_bar_chart.dart';

/// "Today's Goal" card: goal, a 7-day bar chart with today highlighted, and how
/// much of the goal is done.
class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.goalMinutes,
    required this.todayMinutes,
    required this.weekMinutes,
    required this.onEditGoal,
  });

  /// Daily goal in minutes.
  final int goalMinutes;

  /// Minutes focused today.
  final int todayMinutes;

  /// Minutes per day for the last 7 days, oldest first; the last is today.
  final List<int> weekMinutes;

  final VoidCallback onEditGoal;

  int get _percent => goalMinutes <= 0
      ? 0
      : ((todayMinutes / goalMinutes) * 100).clamp(0, 100).round();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final onCard = palette.onAccent;
    final secondary = onCard.withValues(alpha: 0.75);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: palette.accent,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Goal",
                      style: textTheme.titleMedium?.copyWith(
                        color: onCard,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    DurationText(minutes: goalMinutes, color: onCard),
                  ],
                ),
              ),
              IconCircleButtonOutlined(
                semanticLabel: 'Edit daily goal',
                color: onCard,
                onPressed: onEditGoal,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          WeekBarChart(
            values: weekMinutes,
            highlightIndex: weekMinutes.length - 1,
            tooltip: _tooltip(todayMinutes),
            barColor: palette.ink,
            stripeBaseColor: palette.onInk,
            stripeColor: palette.ink,
            tooltipBackground: palette.onInk,
            tooltipStyle: textTheme.labelMedium!.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w600,
            ),
            semanticsLabel:
                'Focus time for the last ${weekMinutes.length} days. '
                'Today ${DurationText.spoken(todayMinutes)}.',
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                '$_percent% Completed',
                style: textTheme.bodySmall?.copyWith(color: secondary),
              ),
              const Spacer(),
              Text(
                '${_compact(todayMinutes)} / ${_compact(goalMinutes)}',
                style: textTheme.bodySmall?.copyWith(
                  color: onCard,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _tooltip(int minutes) => _compact(minutes);

  static String _compact(int minutes) {
    final total = minutes < 0 ? 0 : minutes;
    final hours = total ~/ 60;
    final mins = total % 60;
    if (hours == 0) return '${mins}min';
    if (mins == 0) return '${hours}hr';
    return '${hours}hr ${mins}min';
  }
}

/// Outlined circular arrow button used on accent cards.
class IconCircleButtonOutlined extends StatelessWidget {
  const IconCircleButtonOutlined({
    super.key,
    required this.semanticLabel,
    required this.color,
    required this.onPressed,
  });

  final String semanticLabel;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        shape: CircleBorder(
          side: BorderSide(color: color.withValues(alpha: 0.4)),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: AppSizes.minTouchTarget,
            height: AppSizes.minTouchTarget,
            child: Icon(Icons.north_east_rounded, color: color, size: 22),
          ),
        ),
      ),
    );
  }
}
