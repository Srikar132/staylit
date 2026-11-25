import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';
import 'package:staylit/presentation/widgets/design/duration_text.dart';

/// Bottom sheet for choosing the daily focus goal. Pops with the chosen
/// minutes, or null when dismissed.
Future<int?> showGoalSheet(
  BuildContext context, {
  required int initialMinutes,
}) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => GoalSheet(initialMinutes: initialMinutes),
  );
}

class GoalSheet extends StatefulWidget {
  const GoalSheet({super.key, required this.initialMinutes});

  final int initialMinutes;

  /// Smallest and largest selectable goal, and the step between choices.
  static const int minMinutes = 15;
  static const int maxMinutes = 480;
  static const int stepMinutes = 15;

  @override
  State<GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<GoalSheet> {
  late double _minutes = widget.initialMinutes
      .clamp(GoalSheet.minMinutes, GoalSheet.maxMinutes)
      .toDouble();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final minutes = _minutes.round();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily goal', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'How long do you want to focus each day?',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: DurationText(
                minutes: minutes,
                color: palette.onCanvas,
                fontSize: 38,
              ),
            ),
            Slider(
              value: _minutes,
              min: GoalSheet.minMinutes.toDouble(),
              max: GoalSheet.maxMinutes.toDouble(),
              divisions:
                  (GoalSheet.maxMinutes - GoalSheet.minMinutes) ~/
                  GoalSheet.stepMinutes,
              label: DurationText.spoken(minutes),
              semanticFormatterCallback: (value) =>
                  DurationText.spoken(value.round()),
              onChanged: (value) => setState(() => _minutes = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPillButton(
              label: 'Save goal',
              onPressed: () => Navigator.of(context).pop(minutes),
            ),
          ],
        ),
      ),
    );
  }
}
