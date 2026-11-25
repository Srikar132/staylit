import 'package:flutter/material.dart';

/// A duration in minutes drawn as large numerals with small units, e.g.
/// "2hr 30min". The pattern used for every duration in the design system.
class DurationText extends StatelessWidget {
  const DurationText({
    super.key,
    required this.minutes,
    required this.color,
    this.fontSize = 30,
    this.fontWeight = FontWeight.w700,
  });

  final int minutes;
  final Color color;

  /// Size of the numerals; units are drawn at 55% of it.
  final double fontSize;
  final FontWeight fontWeight;

  /// Spoken form, e.g. "2 hours 30 minutes".
  static String spoken(int minutes) {
    final total = minutes < 0 ? 0 : minutes;
    final hours = total ~/ 60;
    final mins = total % 60;
    final parts = <String>[
      if (hours > 0) '$hours ${hours == 1 ? 'hour' : 'hours'}',
      if (mins > 0 || hours == 0) '$mins ${mins == 1 ? 'minute' : 'minutes'}',
    ];
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final total = minutes < 0 ? 0 : minutes;
    final hours = total ~/ 60;
    final mins = total % 60;

    final numberStyle = TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: 1.1,
      letterSpacing: -0.5,
    );
    final unitStyle = numberStyle.copyWith(
      fontSize: fontSize * 0.55,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: color.withValues(alpha: 0.8),
    );

    return Semantics(
      label: spoken(total),
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            if (hours > 0) ...[
              TextSpan(text: '$hours', style: numberStyle),
              TextSpan(text: 'hr ', style: unitStyle),
            ],
            if (mins > 0 || hours == 0) ...[
              TextSpan(text: '$mins', style: numberStyle),
              TextSpan(text: 'min', style: unitStyle),
            ],
          ],
        ),
      ),
    );
  }
}
