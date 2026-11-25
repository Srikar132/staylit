import 'package:flutter/material.dart';
import 'package:pace/core/theme/app_dimens.dart';
import 'package:pace/core/theme/theme_context.dart';
import 'package:pace/presentation/widgets/design/duration_text.dart';

/// One focus session in a list: icon, title (its tag), subtitle (time and
/// result) and the focused duration.
class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.minutes,
    this.icon = Icons.check_circle_outline_rounded,
  });

  final String title;
  final String subtitle;
  final int minutes;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.surfaceRaised,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: palette.accentText, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium,
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          DurationText(minutes: minutes, color: palette.onCanvas, fontSize: 20),
        ],
      ),
    );
  }
}
