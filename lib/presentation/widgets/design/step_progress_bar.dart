import 'package:flutter/material.dart';
import 'package:staylit/core/theme/theme_context.dart';

/// Segmented progress for multi-step flows: one rounded segment per step,
/// filled up to and including [currentStep] (zero-based).
class StepProgressBar extends StatelessWidget {
  const StepProgressBar({
    super.key,
    required this.currentStep,
    required this.stepCount,
    this.filledCount,
  }) : assert(stepCount > 0);

  final int currentStep;
  final int stepCount;

  /// When set, exactly this many segments are filled (0 fills none) and
  /// [currentStep] is ignored.
  final int? filledCount;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final step = currentStep.clamp(0, stepCount - 1);
    return Semantics(
      label: filledCount != null
          ? '$filledCount of $stepCount'
          : 'Step ${step + 1} of $stepCount',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < stepCount; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 6,
                decoration: BoxDecoration(
                  color: (filledCount != null ? i < filledCount! : i <= step)
                      ? palette.accent
                      : palette.surfaceTrack,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
