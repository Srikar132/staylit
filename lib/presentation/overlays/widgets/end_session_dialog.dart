import 'package:flutter/material.dart';
import 'package:staylit/core/theme/theme_context.dart';

/// "End focus session?" confirmation shared by the block overlays. Calls
/// [onConfirm] only when the user confirms.
Future<void> showEndSessionDialog(
  BuildContext context, {
  required VoidCallback onConfirm,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final textTheme = Theme.of(dialogContext).textTheme;
      return AlertDialog(
        title: Text('End focus session?', style: textTheme.titleLarge),
        content: Text(
          'Your progress so far is saved, but you will lose your momentum.',
          style: textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Keep focusing'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onConfirm();
            },
            style: TextButton.styleFrom(
              foregroundColor: dialogContext.palette.error,
            ),
            child: const Text('End session'),
          ),
        ],
      );
    },
  );
}
