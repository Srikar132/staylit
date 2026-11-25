import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Clips a box so its bottom edge is a row of rounded scallops that hang down.
///
/// The box must be [depth] taller than the content it should hold.
class ScallopedBottomClipper extends CustomClipper<Path> {
  const ScallopedBottomClipper({this.toothWidth = 28, this.depth = 10});

  /// Approximate width of one scallop.
  final double toothWidth;

  /// How far the scallops hang below the straight edge.
  final double depth;

  @override
  Path getClip(Size size) {
    final teeth = math.max(1, (size.width / toothWidth).round());
    final width = size.width / teeth;
    final edge = size.height - depth;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, edge);
    for (var i = 0; i < teeth; i++) {
      final right = size.width - i * width;
      path.arcToPoint(
        Offset(right - width, edge),
        radius: Radius.elliptical(width / 2, depth),
      );
    }
    return path..close();
  }

  @override
  bool shouldReclip(ScallopedBottomClipper oldClipper) =>
      oldClipper.toothWidth != toothWidth || oldClipper.depth != depth;
}

/// Horizontal progress strip with a scalloped top edge: [fillColor] up to
/// [progress], [trackColor] for the rest.
class ScallopedProgressStrip extends StatelessWidget {
  const ScallopedProgressStrip({
    super.key,
    required this.progress,
    required this.fillColor,
    required this.trackColor,
    this.height = 22,
  });

  /// 0..1.
  final double progress;
  final Color fillColor;
  final Color trackColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Session progress',
      value: '${(progress.clamp(0.0, 1.0) * 100).round()}%',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _StripPainter(
            progress: progress.clamp(0.0, 1.0),
            fillColor: fillColor,
            trackColor: trackColor,
          ),
        ),
      ),
    );
  }
}

class _StripPainter extends CustomPainter {
  const _StripPainter({
    required this.progress,
    required this.fillColor,
    required this.trackColor,
  });

  final double progress;
  final Color fillColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const bump = 7.0;
    final teeth = math.max(1, (size.width / (bump * 2)).round());
    final step = size.width / teeth;

    final shape = Path()
      ..addRect(Rect.fromLTWH(0, bump, size.width, size.height - bump));
    for (var i = 0; i < teeth; i++) {
      shape.addOval(
        Rect.fromCenter(
          center: Offset(step * (i + 0.5), bump),
          width: step,
          height: bump * 2,
        ),
      );
    }

    canvas.save();
    canvas.clipPath(shape);
    canvas.drawRect(Offset.zero & size, Paint()..color = trackColor);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * progress, size.height),
      Paint()..color = fillColor,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StripPainter old) =>
      old.progress != progress ||
      old.fillColor != fillColor ||
      old.trackColor != trackColor;
}
