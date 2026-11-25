import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';
import 'package:staylit/widgets/bottom_sheet_darg_handler.dart';

/// Asks the user to confirm an action in a bottom sheet. Returns true only when
/// they tap the confirm button; dismissing or cancelling returns false.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    builder: (sheetContext) {
      final textTheme = Theme.of(sheetContext).textTheme;
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
                title,
                style: textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                style: textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppPillButton(
                label: cancelLabel,
                onPressed: () => Navigator.pop(sheetContext, false),
              ),
              const SizedBox(height: AppSpacing.md),
              AppPillButton(
                label: confirmLabel,
                variant: PillButtonVariant.outline,
                onPressed: () => Navigator.pop(sheetContext, true),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}
