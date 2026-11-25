import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';
import 'package:staylit/widgets/bottom_sheet_darg_handler.dart';

/// Confirmation shown before a focus session is ended early. Pops `true` when
/// the user confirms; dismissing the sheet (or "Keep going") leaves it null.
class EndSessionBottomSheet extends StatelessWidget {
  const EndSessionBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
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
            Text(
              'Stop focusing?',
              style: textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Take a deep breath before you decide. '
              'Your time so far still counts.',
              style: textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppPillButton(
              label: 'Keep going',
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(height: AppSpacing.md),
            AppPillButton(
              label: 'Stop focusing',
              variant: PillButtonVariant.outline,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
  }
}
