import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/widgets/design/week_bar_chart.dart';

/// A compact stat card for the Home "numbers" row: icon pill, big value, an
/// optional trend tag and a mini bar chart with the last bar striped.
///
/// With [offLabel] set the card is in its "not collecting yet" state: flat
/// bars and a call to action instead of a value.
class MiniStatCard extends StatelessWidget {
  const MiniStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.caption,
    this.values = const [],
    this.trendText,
    this.trendGood = true,
    this.offLabel,
    this.semanticsLabel,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Big number, e.g. "87" or "4 days".
  final String? value;

  /// Small line under [value].
  final String? caption;

  /// Mini chart values, oldest first; the last bar is the highlighted one.
  final List<num> values;

  /// e.g. "↓ 12% vs yesterday".
  final String? trendText;

  /// Colors the trend green (true) or red (false).
  final bool trendGood;

  /// When non-null the card shows this call to action instead of data.
  final String? offLabel;

  final String? semanticsLabel;

  static const _chartHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final off = offLabel != null;

    return Semantics(
      button: true,
      label:
          semanticsLabel ??
          (off
              ? '$label. $caption. $offLabel'
              : '$label: $value. ${caption ?? ''}'),
      excludeSemantics: true,
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: palette.surfaceRaised,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 16, color: palette.accentText),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          color: palette.onCanvas,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (off) ...[
                  Text(
                    caption ?? '',
                    style: textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _FlatBars(),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Text(
                        offLabel!,
                        style: textTheme.titleSmall?.copyWith(
                          color: palette.accentText,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: palette.accentText,
                      ),
                    ],
                  ),
                ] else ...[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value ?? '-', style: textTheme.displaySmall),
                  ),
                  if (caption != null)
                    Text(caption!, style: textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.sm),
                  if (trendText != null)
                    _Trend(text: trendText!, good: trendGood)
                  else
                    const SizedBox(height: 22),
                  const SizedBox(height: AppSpacing.sm),
                  WeekBarChart(
                    values: values,
                    highlightIndex: values.isEmpty ? 0 : values.length - 1,
                    tooltip: '',
                    height: _chartHeight,
                    barColor: palette.accent,
                    stripeBaseColor: palette.accent,
                    stripeColor: palette.surface,
                    tooltipBackground: palette.ink,
                    tooltipStyle: textTheme.labelSmall!,
                    semanticsLabel: '$label, last ${values.length} days',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Seven short, equal bars: the chart's resting state.
class _FlatBars extends StatelessWidget {
  const _FlatBars();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 24,
              decoration: BoxDecoration(
                color: palette.surfaceTrack,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
