import 'package:flutter/material.dart';
import 'package:pace/core/theme/app_dimens.dart';
import 'package:pace/core/theme/theme_context.dart';

/// Rounded `surface` card with a title and a muted body, used for short
/// messages. With a [leading] widget the text is left-aligned beside it,
/// otherwise it is centered.
class MessageCard extends StatelessWidget {
  const MessageCard({
    super.key,
    required this.title,
    this.body,
    this.leading,
    this.onTap,
  });

  final String title;
  final String? body;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final align = leading == null ? TextAlign.center : TextAlign.start;

    final text = Column(
      crossAxisAlignment: leading == null
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: textTheme.titleLarge, textAlign: align),
        if (body != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(body!, style: textTheme.bodyMedium, textAlign: align),
        ],
      ],
    );

    return Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.lg),
              ],
              Expanded(child: text),
            ],
          ),
        ),
      ),
    );
  }
}
