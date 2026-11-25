import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';
import 'package:staylit/presentation/widgets/design/choice_pill.dart';
import 'package:staylit/presentation/widgets/design/duration_text.dart';
import 'package:staylit/presentation/widgets/design/lit_badge.dart';

/// What the Save screen shows, resolved from the finished session.
@immutable
class SaveSessionData {
  const SaveSessionData({
    required this.focusMinutes,
    required this.plannedMinutes,
    required this.interruptions,
    required this.timeRange,
    required this.autoCompleted,
  });

  final int focusMinutes;
  final int plannedMinutes;
  final int interruptions;

  /// e.g. "9:10 AM - 9:35 AM".
  final String timeRange;

  /// The timer ran out by itself: the session is already recorded, so this
  /// screen only adds a tag and a note (nothing to discard).
  final bool autoCompleted;
}

/// The Save session screen. Pure presentation.
class SaveSessionView extends StatelessWidget {
  const SaveSessionView({
    super.key,
    required this.data,
    required this.notesController,
    required this.tags,
    required this.selectedTag,
    required this.onTag,
    required this.saving,
    required this.onSave,
    required this.onDiscard,
  });

  final SaveSessionData data;
  final TextEditingController notesController;
  final List<String> tags;
  final String? selectedTag;
  final ValueChanged<String?> onTag;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              children: [
                if (data.autoCompleted) ...[
                  const Center(child: LitBadge(size: 88)),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Text(
                  data.autoCompleted ? 'Session complete' : 'Save session',
                  style: textTheme.displaySmall,
                  textAlign: data.autoCompleted
                      ? TextAlign.center
                      : TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  data.timeRange,
                  style: textTheme.bodyMedium,
                  textAlign: data.autoCompleted
                      ? TextAlign.center
                      : TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.xl),
                _FocusCard(data: data),
                const SizedBox(height: AppSpacing.xxl),
                Text('Tag', style: textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final tag in tags)
                      ChoicePill(
                        label: tag,
                        selected: selectedTag == tag,
                        onTap: () => onTag(selectedTag == tag ? null : tag),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text('Note', style: textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: notesController,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  style: textTheme.bodyLarge?.copyWith(color: palette.onCanvas),
                  decoration: InputDecoration(
                    hintText: 'What did you work on?',
                    filled: true,
                    fillColor: palette.surface,
                    contentPadding: const EdgeInsets.all(AppSpacing.lg),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      borderSide: BorderSide.none,
                    ),
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
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppPillButton(
                  label: saving ? 'Saving...' : 'Save',
                  onPressed: saving ? null : onSave,
                ),
                if (!data.autoCompleted) ...[
                  const SizedBox(height: AppSpacing.xs),
                  TextButton(
                    onPressed: saving ? null : onDiscard,
                    style: TextButton.styleFrom(foregroundColor: palette.error),
                    child: const Text('Discard session'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.data});

  final SaveSessionData data;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final onCard = palette.onAccent;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: palette.accent,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total focus',
            style: textTheme.titleMedium?.copyWith(color: onCard),
          ),
          const SizedBox(height: AppSpacing.xs),
          DurationText(minutes: data.focusMinutes, color: onCard),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _Stat(label: 'Planned', value: '${data.plannedMinutes}m'),
              const SizedBox(width: AppSpacing.xxl),
              _Stat(label: 'Interruptions', value: '${data.interruptions}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: palette.onAccent.withValues(alpha: 0.75),
          ),
        ),
        Text(
          value,
          style: textTheme.titleLarge?.copyWith(color: palette.onAccent),
        ),
      ],
    );
  }
}
