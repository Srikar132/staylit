import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:staylit/core/constants/app_info.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/data/models/group_model.dart';
import 'package:staylit/presentation/providers/auth_provider.dart';
import 'package:staylit/presentation/providers/group_provider.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';
import 'package:staylit/presentation/widgets/design/icon_circle_button.dart';
import 'package:staylit/presentation/widgets/design/switch_row_card.dart';
import 'package:staylit/widgets/bottom_sheet_darg_handler.dart';

/// Screen for creating a new group.
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isPublic = false;
  bool _allowMemberInvites = true;
  bool _showLeaderboard = true;
  int _focusGoalMinutes = 0;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  static String _goalText(int minutes) {
    if (minutes == 0) return 'No goal';
    if (minutes < 60) return '${minutes}m a day';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h a day' : '${h}h ${m}m a day';
  }

  void _shareGroup(String groupId, String groupName) {
    final message =
        'Join my focus group "$groupName" on $kAppName.\n\n'
        'Open the app, search for the group and enter this ID:\n'
        '$groupId';
    SharePlus.instance.share(
      ShareParams(text: message, subject: 'Join my focus group: $groupName'),
    );
  }

  void _showShareSheet(BuildContext context, String groupId, String name) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final palette = sheetContext.palette;
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
                  'Invite your friends',
                  style: textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '"$name" is ready. Share it so they can join.',
                  style: textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.link_rounded, color: palette.accentText),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          groupId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppPillButton(
                  label: 'Share',
                  icon: Icons.ios_share_rounded,
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _shareGroup(groupId, name);
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Later'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('User not logged in');

      final createdGroupId = await ref
          .read(groupActionsProvider)
          .createGroup(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            creatorId: user.uid,
            creatorDisplayName:
                user.displayName ?? user.email?.split('@')[0] ?? 'User',
            settings: GroupSettings(
              isPublic: _isPublic,
              allowMemberInvites: _allowMemberInvites,
              focusGoalMinutes: _focusGoalMinutes,
              showLeaderboard: _showLeaderboard,
            ),
          );

      if (!mounted) return;
      final groupName = _nameController.text.trim();
      final navigator = Navigator.of(context);
      final rootContext = navigator.context;
      navigator.pop();

      // Offer to share once the screen has closed.
      Future.delayed(const Duration(milliseconds: 400), () {
        if (rootContext.mounted) {
          _showShareSheet(rootContext, createdGroupId, groupName);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Couldn't create the group: $e"),
            backgroundColor: context.palette.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _decoration(String label, {String? hint}) {
    final palette = context.palette;
    OutlineInputBorder border([Color? color]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      borderSide: color == null ? BorderSide.none : BorderSide(color: color),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: palette.surface,
      contentPadding: const EdgeInsets.all(AppSpacing.lg),
      border: border(),
      enabledBorder: border(),
      errorBorder: border(palette.error),
      focusedErrorBorder: border(palette.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.xl,
                    AppSpacing.lg,
                  ),
                  children: [
                    Row(
                      children: [
                        IconCircleButton(
                          icon: Icons.close_rounded,
                          semanticLabel: 'Close',
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Text(
                            'New group',
                            style: textTheme.displaySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      maxLength: 40,
                      style: textTheme.bodyLarge?.copyWith(
                        color: palette.onCanvas,
                      ),
                      decoration: _decoration('Group name'),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Give your group a name';
                        if (text.length < 3) return 'Use at least 3 letters';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 200,
                      style: textTheme.bodyLarge?.copyWith(
                        color: palette.onCanvas,
                      ),
                      decoration: _decoration(
                        'Description',
                        hint: 'What is this group for?',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text('Settings', style: textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.md),
                    SwitchRowCard(
                      icon: Icons.public_rounded,
                      title: 'Public group',
                      subtitle: 'Anyone can find and join',
                      value: _isPublic,
                      onChanged: (v) => setState(() => _isPublic = v),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SwitchRowCard(
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'Member invites',
                      subtitle: 'Members can invite others',
                      value: _allowMemberInvites,
                      onChanged: (v) => setState(() => _allowMemberInvites = v),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SwitchRowCard(
                      icon: Icons.emoji_events_outlined,
                      title: 'Leaderboard',
                      subtitle: 'Show member rankings',
                      value: _showLeaderboard,
                      onChanged: (v) => setState(() => _showLeaderboard = v),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Daily focus goal',
                                  style: textTheme.titleMedium,
                                ),
                              ),
                              Text(
                                _goalText(_focusGoalMinutes),
                                style: textTheme.titleMedium?.copyWith(
                                  color: palette.accentText,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: _focusGoalMinutes.toDouble(),
                            max: 480,
                            divisions: 48,
                            label: _goalText(_focusGoalMinutes),
                            onChanged: (value) => setState(
                              () => _focusGoalMinutes = value.toInt(),
                            ),
                          ),
                        ],
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
                  AppSpacing.xl,
                ),
                child: AppPillButton(
                  label: _isLoading ? 'Creating...' : 'Create group',
                  onPressed: _isLoading ? null : _createGroup,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
