import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bars for the last N days. One bar is highlighted with diagonal stripes and a
/// tooltip pill above it.
///
/// Colors are passed in so the chart works on any card.
class WeekBarChart extends StatelessWidget {
  const WeekBarChart({
    super.key,
    required this.values,
    required this.highlightIndex,
    required this.tooltip,
    required this.barColor,
    required this.stripeBaseColor,
    required this.stripeColor,
    required this.tooltipBackground,
    required this.tooltipStyle,
    required this.semanticsLabel,
    this.height = 128,
  });

  /// One value per bar (any unit); the tallest fills the chart.
  final List<num> values;

  /// Index of the striped bar.
  final int highlightIndex;
  final String tooltip;
  final Color barColor;
  final Color stripeBaseColor;
  final Color stripeColor;
  final Color tooltipBackground;
  final TextStyle tooltipStyle;
  final String semanticsLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _WeekBarChartPainter(
            values: values,
            highlightIndex: highlightIndex,
            tooltip: tooltip,
            barColor: barColor,
            stripeBaseColor: stripeBaseColor,
            stripeColor: stripeColor,
            tooltipBackground: tooltipBackground,
            tooltipStyle: tooltipStyle,
          ),
        ),
      ),
    );
  }
}

class _WeekBarChartPainter extends CustomPainter {
  _WeekBarChartPainter({
    required this.values,
    required this.highlightIndex,
    required this.tooltip,
    required this.barColor,
    required this.stripeBaseColor,
    required this.stripeColor,
    required this.tooltipBackground,
    required this.tooltipStyle,
  });

  final List<num> values;
  final int highlightIndex;
  final String tooltip;
  final Color barColor;
  final Color stripeBaseColor;
  final Color stripeColor;
  final Color tooltipBackground;
  final TextStyle tooltipStyle;

  static const double _gap = 8;
  static const double _tooltipSpace = 38;
  static const double _minBarHeight = 14;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final chartHeight = size.height - _tooltipSpace;
    final barWidth = (size.width - _gap * (values.length - 1)) / values.length;
    final maxValue = values.fold<num>(1, (a, b) => math.max(a, b));
    final radius = Radius.circular(math.min(barWidth * 0.4, 16));

    Rect? highlightRect;
    for (var i = 0; i < values.length; i++) {
      final barHeight = math.max(
        _minBarHeight,
        values[i] / maxValue * chartHeight,
      );
      final rect = Rect.fromLTWH(
        i * (barWidth + _gap),
        size.height - barHeight,
        barWidth,
        barHeight,
      );
      final rrect = RRect.fromRectAndRadius(rect, radius);

      if (i == highlightIndex) {
        highlightRect = rect;
        canvas.save();
        canvas.clipRRect(rrect);
        canvas.drawRect(rect, Paint()..color = stripeBaseColor);
        final stripe = Paint()
          ..color = stripeColor
          ..strokeWidth = 4;
        for (var dx = -rect.height; dx < rect.width + rect.height; dx += 9) {
          canvas.drawLine(
            Offset(rect.left + dx, rect.bottom),
            Offset(rect.left + dx + rect.height, rect.top),
            stripe,
          );
        }
        canvas.restore();
      } else {
        canvas.drawRRect(rrect, Paint()..color = barColor);
      }
    }

    if (highlightRect != null && tooltip.isNotEmpty) {
      _paintTooltip(canvas, size, highlightRect);
    }
  }

  void _paintTooltip(Canvas canvas, Size size, Rect bar) {
    final painter = TextPainter(
      text: TextSpan(text: tooltip, style: tooltipStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    const padX = 10.0;
    const pillHeight = 26.0;
    final width = painter.width + padX * 2;
    final left = (bar.center.dx - width / 2).clamp(0.0, size.width - width);
    final top = math.max(0.0, bar.top - 8 - pillHeight);
    final pill = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, pillHeight),
      const Radius.circular(pillHeight / 2),
    );

    final paint = Paint()..color = tooltipBackground;
    canvas.drawRRect(pill, paint);
    canvas.drawPath(
      Path()
        ..moveTo(bar.center.dx - 5, pill.bottom - 1)
        ..lineTo(bar.center.dx + 5, pill.bottom - 1)
        ..lineTo(bar.center.dx, pill.bottom + 5)
        ..close(),
      paint,
    );
    painter.paint(
      canvas,
      Offset(left + padX, top + (pillHeight - painter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(_WeekBarChartPainter old) =>
      old.values != values ||
      old.highlightIndex != highlightIndex ||
      old.tooltip != tooltip ||
      old.barColor != barColor ||
      old.stripeBaseColor != stripeBaseColor ||
      old.stripeColor != stripeColor ||
      old.tooltipBackground != tooltipBackground ||
      old.tooltipStyle != tooltipStyle;
}
