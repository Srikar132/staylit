import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';

/// Title, a small status pill and an optional line of explanation, shared by
/// every block overlay so they read as one family.
class BlockHeader extends StatelessWidget {
  const BlockHeader({
    super.key,
    required this.title,
    this.chip,
    this.message,
    this.danger = false,
  });

  final String title;

  /// Short pill under the title (app name, domain, "Focus mode active").
  final String? chip;

  /// One sentence of context under the pill.
  final String? message;

  /// Tints the pill with the error color instead of the accent.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: textTheme.displaySmall, textAlign: TextAlign.center),
        if (chip != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: danger
                  ? palette.error.withValues(alpha: 0.12)
                  : palette.accentSoft,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              chip!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleMedium?.copyWith(
                color: danger ? palette.error : palette.accentText,
              ),
            ),
          ),
        ],
        if (message != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            message!,
            style: textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
