import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';

/// Shared layout of the onboarding question screens: a large question, the
/// answer cards (scrollable), an optional hint, and a pinned action button.
class OnboardingQuestionLayout extends StatelessWidget {
  const OnboardingQuestionLayout({
    super.key,
    required this.title,
    required this.children,
    required this.actionLabel,
    required this.onAction,
    this.hint,
  });

  final String title;

  /// The answer cards (and anything else between the question and the button).
  final List<Widget> children;

  /// Small note under the answers, e.g. "You can change this later".
  final String? hint;
  final String actionLabel;

  /// Null disables the action (no answer chosen yet).
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xxl,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            children: [
              Text(title, style: textTheme.displaySmall),
              const SizedBox(height: AppSpacing.xxl),
              for (final child in children) ...[
                child,
                const SizedBox(height: AppSpacing.md),
              ],
              if (hint != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: palette.onCanvasMuted,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(hint!, style: textTheme.bodySmall)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: AppPillButton(label: actionLabel, onPressed: onAction),
        ),
      ],
    );
  }
}
