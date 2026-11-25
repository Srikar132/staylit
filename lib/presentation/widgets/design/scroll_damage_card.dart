import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/screens/focus/scroll_mood.dart';
import 'package:staylit/presentation/widgets/design/week_bar_chart.dart';

/// Home card for Scroll damage: a calm `surface` card. Off, it is one slim row
/// inviting the user to turn it on; on, it shows today's count, a five-step
/// meter and a small 7-day chart.
class ScrollDamageCard extends StatelessWidget {
  const ScrollDamageCard({
    super.key,
    required this.enabled,
    required this.onTap,
    this.todayCount = 0,
    this.week = const [],
    this.trendText,
    this.trendGood = true,
  });

  /// False shows the slim "Turn on" row.
  final bool enabled;
  final VoidCallback onTap;

  final int todayCount;

  /// Items per day for the last 7 days, oldest first.
  final List<int> week;
  final String? trendText;
  final bool trendGood;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      label: enabled
          ? 'Scroll damage. $todayCount items today. Tap for details.'
          : 'Scroll damage. Off. Tap to learn more and turn on.',
      excludeSemantics: true,
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: enabled
                ? _On(
                    count: todayCount,
                    week: week,
                    trendText: trendText,
                    trendGood: trendGood,
                  )
                : const _Off(),
          ),
        ),
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.swipe_vertical_rounded,
        size: 20,
        color: palette.accentText,
      ),
    );
  }
}

class _Off extends StatelessWidget {
  const _Off();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        const _IconPill(),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Scroll damage', style: textTheme.titleMedium),
              Text('See how far you scroll', style: textTheme.bodySmall),
            ],
          ),
        ),
        Text(
          'Turn on',
          style: textTheme.titleSmall?.copyWith(color: palette.accentText),
        ),
        Icon(Icons.chevron_right_rounded, color: palette.accentText),
      ],
    );
  }
}

class _On extends StatelessWidget {
  const _On({
    required this.count,
    required this.week,
    required this.trendText,
    required this.trendGood,
  });

  final int count;
  final List<int> week;
  final String? trendText;
  final bool trendGood;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final mood = ScrollMood.forCount(count);
    final collecting = week.isEmpty && count == 0;
    final meterColor = mood.level >= 4 ? palette.error : palette.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _IconPill(),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text('Scroll damage', style: textTheme.titleMedium),
            ),
            if (trendText != null) _Trend(text: trendText!, good: trendGood),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$count', style: textTheme.displaySmall),
            const SizedBox(width: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text('items today', style: textTheme.bodySmall),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                collecting ? 'Collecting...' : mood.label,
                style: textTheme.labelMedium?.copyWith(
                  color: palette.accentText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (var i = 0; i < ScrollMood.values.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < mood.level ? meterColor : palette.surfaceTrack,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (week.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          WeekBarChart(
            values: week,
            highlightIndex: week.length - 1,
            tooltip: '',
            height: 52,
            barColor: palette.accent,
            stripeBaseColor: palette.accent,
            stripeColor: palette.surface,
            tooltipBackground: palette.ink,
            tooltipStyle: textTheme.labelSmall!,
            semanticsLabel: 'Scroll damage, last ${week.length} days',
          ),
        ],
      ],
    );
  }
}

class _Trend extends StatelessWidget {
  const _Trend({required this.text, required this.good});

  final String text;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = good ? palette.success : palette.error;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
