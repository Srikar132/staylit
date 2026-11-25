import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';
import 'package:staylit/presentation/widgets/design/lit_badge.dart';
import 'package:staylit/widgets/bottom_sheet_darg_handler.dart';

/// Short explainer for Scroll damage: Lit, one sentence, a Turn on button.
/// Pure: the caller decides what the buttons do.
class ScrollDamageSheet extends StatelessWidget {
  const ScrollDamageSheet({
    super.key,
    required this.enabled,
    required this.accessibilityGranted,
    required this.onTurnOn,
    required this.onTurnOff,
    required this.onAllowAccessibility,
    required this.onClose,
  });

  final bool enabled;

  /// The feature reads scroll events through the accessibility service.
  final bool accessibilityGranted;
  final VoidCallback onTurnOn;
  final VoidCallback onTurnOff;
  final VoidCallback onAllowAccessibility;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BottomSheetDragHandle(),
            const SizedBox(height: AppSpacing.lg),
            const LitBadge(size: 96),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Scroll damage',
              style: textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Lit counts the shorts and reels you scroll past, and tells you '
              'when it is time to stop.',
              style: textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            if (enabled) ...[
              AppPillButton(label: 'Done', onPressed: onClose),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: onTurnOff,
                style: TextButton.styleFrom(foregroundColor: palette.error),
                child: const Text('Turn off'),
              ),
            ] else ...[
              if (!accessibilityGranted) ...[
                Text(
                  'Needs the accessibility permission first.',
                  style: textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppPillButton(
                label: accessibilityGranted ? 'Turn on' : 'Allow accessibility',
                onPressed: accessibilityGranted
                    ? onTurnOn
                    : onAllowAccessibility,
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(onPressed: onClose, child: const Text('Not now')),
            ],
          ],
        ),
      ),
    );
  }
}
