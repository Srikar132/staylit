import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:staylit/core/router/app_router.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/providers/focus_session_provider.dart';
import 'package:staylit/presentation/screens/save_session/save_session_view.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';
import 'package:staylit/widgets/bottom_sheet_darg_handler.dart';

/// Shown after a session ends (manually, or when the timer runs out) so the
/// user can tag it and add a note.
class SaveSessionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> sessionData;

  const SaveSessionScreen({super.key, required this.sessionData});

  @override
  ConsumerState<SaveSessionScreen> createState() => _SaveSessionScreenState();
}

class _SaveSessionScreenState extends ConsumerState<SaveSessionScreen> {
  static const _tags = ['Study', 'Work', 'Reading', 'Coding', 'Other'];

  final TextEditingController _notesController = TextEditingController();
  String? _selectedTag;
  bool _isSaving = false;

  // Captured once so the screen does not drift while it is open.
  late final DateTime _endedAt = DateTime.now();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  SaveSessionData get _data {
    final elapsedSeconds = widget.sessionData['elapsedSeconds'] as int? ?? 0;
    final focusMinutes =
        widget.sessionData['focusMinutes'] as int? ?? elapsedSeconds ~/ 60;
    final started =
        widget.sessionData['startTime'] as DateTime? ??
        _endedAt.subtract(Duration(seconds: elapsedSeconds));
    final time = DateFormat('h:mm a');
    return SaveSessionData(
      focusMinutes: focusMinutes,
      plannedMinutes: widget.sessionData['plannedDuration'] as int? ?? 0,
      interruptions: widget.sessionData['interruptionCount'] as int? ?? 0,
      timeRange: '${time.format(started)} - ${time.format(_endedAt)}',
      autoCompleted: widget.sessionData['autoCompleted'] as bool? ?? false,
    );
  }

  Future<void> _saveSession() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(focusSessionProvider.notifier)
          .completeSessionWithNotes(
            notes: _notesController.text.trim(),
            tag: _selectedTag,
          );
      // Route back through /splash so the router's redirect logic decides
      // where to land.
      if (mounted) context.go(splashRoute);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save session: $e'),
            backgroundColor: context.palette.error,
          ),
        );
      }
    }
  }

  void _confirmDiscard() {
    final screenContext = context;
    showModalBottomSheet<void>(
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
                Text('Discard this session?', style: textTheme.displaySmall),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  "It won't count towards your totals. This can't be undone.",
                  style: textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppPillButton(
                  label: 'Keep session',
                  onPressed: () => Navigator.pop(sheetContext),
                ),
                const SizedBox(height: AppSpacing.md),
                AppPillButton(
                  label: 'Discard',
                  variant: PillButtonVariant.outline,
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    ref.read(focusSessionProvider.notifier).discardSession();
                    screenContext.go(splashRoute);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SaveSessionView(
          data: _data,
          notesController: _notesController,
          tags: _tags,
          selectedTag: _selectedTag,
          onTag: (tag) => setState(() => _selectedTag = tag),
          saving: _isSaving,
          onSave: _saveSession,
          onDiscard: _confirmDiscard,
        ),
      ),
    );
  }
}
