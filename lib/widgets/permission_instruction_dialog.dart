import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';
import 'package:staylit/widgets/bottom_sheet_darg_handler.dart';

/// Bottom sheet explaining how to grant a special Android permission, with a
/// numbered list of steps and an Allow button.
class PermissionInstructionDialog extends StatelessWidget {
  final String title;
  final String description;
  final List<String> steps;
  final VoidCallback onAllowPressed;
  final String allowButtonText;

  const PermissionInstructionDialog({
    super.key,
    required this.title,
    required this.description,
    required this.steps,
    required this.onAllowPressed,
    this.allowButtonText = 'Allow',
  });

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BottomSheetDragHandle(),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: textTheme.displaySmall),
            const SizedBox(height: AppSpacing.sm),
            Text(description, style: textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.xl),
            for (var i = 0; i < steps.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.accentSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: textTheme.labelMedium?.copyWith(
                        color: palette.accentText,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        steps[i],
                        style: textTheme.bodyLarge?.copyWith(
                          color: palette.onCanvas,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            const SizedBox(height: AppSpacing.md),
            AppPillButton(
              label: allowButtonText,
              onPressed: () {
                Navigator.pop(context);
                onAllowPressed();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Shows the sheet.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String description,
    required List<String> steps,
    required VoidCallback onAllowPressed,
    String allowButtonText = 'Allow',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => PermissionInstructionDialog(
        title: title,
        description: description,
        steps: steps,
        onAllowPressed: onAllowPressed,
        allowButtonText: allowButtonText,
      ),
    );
  }
}
