import 'package:flutter/material.dart';
import 'package:pace/core/theme/theme_context.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback onGoHome;
  final VoidCallback onEndSession;
  final VoidCallback? onShowEducation;

  const ActionButtons({
    super.key,
    required this.onGoHome,
    required this.onEndSession,
    this.onShowEducation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onGoHome,
                icon: const Icon(Icons.home),
                label: const Text('Go Home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.palette.success.withValues(
                    alpha: 0.2,
                  ),
                  foregroundColor: context.palette.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: context.palette.success.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
            if (onShowEducation != null) ...[
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onShowEducation,
                  icon: const Icon(Icons.school),
                  label: const Text('Learn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.palette.info.withValues(
                      alpha: 0.2,
                    ),
                    foregroundColor: context.palette.info,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: context.palette.info.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onEndSession,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('End Focus Session'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.palette.error,
              side: BorderSide(
                color: context.palette.error.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
