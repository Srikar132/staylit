import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pace/core/theme/app_dimens.dart';
import 'package:pace/core/theme/app_typography.dart';
import 'package:pace/core/theme/theme_context.dart';

/// Concentric ring timer: a soft track, an accent progress arc, and a near-black
/// disc in the middle holding the time.
class FocusRingTimer extends StatelessWidget {
  const FocusRingTimer({
    super.key,
    required this.progress,
    required this.timeText,
    required this.label,
    this.chipText,
    this.paused = false,
    this.size = 250,
  });

  /// 0..1.
  final double progress;
  final String timeText;

  /// Small caption above the time (e.g. "Focus Time").
  final String label;

  /// Optional chip under the time (e.g. "Pomodoro 1 of 4", "Paused").
  final String? chipText;
  final bool paused;
  final double size;

  static const double _ringWidth = 22;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final clamped = progress.clamp(0.0, 1.0);
    final discSize = size - 2 * (_ringWidth + _gap);

    return Semantics(
      label: '$label $timeText${chipText == null ? '' : ', $chipText'}',
      value: '${(clamped * 100).round()}% complete',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RingPainter(
                  progress: clamped,
                  trackColor: palette.accentSoft.withValues(alpha: 0.55),
                  progressColor: paused
                      ? palette.accent.withValues(alpha: 0.5)
                      : palette.accent,
                  strokeWidth: _ringWidth,
                ),
              ),
            ),
            Container(
              width: discSize,
              height: discSize,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: palette.ink,
                shape: BoxShape.circle,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: textTheme.labelLarge?.copyWith(
                      color: palette.onInk.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      timeText,
                      style: textTheme.displayMedium?.copyWith(
                        color: palette.onInk,
                        fontSize: 44,
                        fontWeight: FontWeight.w500,
                        fontFeatures: AppTypography.tabularFigures,
                      ),
                    ),
                  ),
                  if (chipText != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _StatusChip(text: chipText!, dotColor: palette.accent),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text, required this.dotColor});

  final String text;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: palette.onInk.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: palette.onInk,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = progressColor
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor ||
      old.strokeWidth != strokeWidth;
}
