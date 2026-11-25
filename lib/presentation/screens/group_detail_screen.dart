import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:staylit/core/constants/app_info.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/data/models/group_model.dart';
import 'package:staylit/presentation/providers/auth_provider.dart';
import 'package:staylit/presentation/providers/group_provider.dart';
import 'package:staylit/presentation/screens/groups/group_detail_view.dart';
import 'package:staylit/presentation/widgets/confirm_sheet.dart';
import 'package:staylit/presentation/widgets/design/app_limit_card.dart';
import 'package:staylit/presentation/widgets/design/message_card.dart';

/// Group detail: wires providers into [GroupDetailView] and owns join / leave
/// / delete / share.
class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupProvider(widget.groupId));
    final members = ref.watch(groupMembersProvider(widget.groupId)).value;
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      body: groupAsync.when(
        data: (group) {
          if (group == null) return _message('Group not found');

          final goal = group.settings.focusGoalMinutes;
          return GroupDetailView(
            data: GroupDetailData(
              name: group.name,
              description: group.description,
              memberCount: group.memberIds.length,
              totalFocusText: group.getFormattedFocusTime(),
              goalText: goal > 0 ? AppLimitCard.format(goal) : null,
              isPublic: group.settings.isPublic,
              isMember: user != null && group.isMember(user.uid),
              isCreator: user != null && group.isCreator(user.uid),
              showLeaderboard: group.settings.showLeaderboard,
              members: [
                for (final m in members ?? const [])
                  MemberTileData(
                    name: m.displayName,
                    focusText: m.getFormattedFocusTime(),
                    isAdmin: m.isAdmin,
                    isMe: user != null && m.userId == user.uid,
                    photoUrl: m.photoUrl,
                  ),
              ],
            ),
            onBack: () => Navigator.pop(context),
            onShare: () => _shareGroup(group),
            onDelete: () => _deleteGroup(group),
            onJoin: () => _joinGroup(group),
            onLeave: () => _leaveGroup(group),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _message("Couldn't load this group"),
      ),
    );
  }

  Widget _message(String text) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BackButton(onPressed: () => Navigator.pop(context)),
          const SizedBox(height: 16),
          MessageCard(title: text),
        ],
      ),
    ),
  );

  void _shareGroup(GroupModel group) {
    SharePlus.instance.share(
      ShareParams(
        text:
            'Join my focus group "${group.name}" on $kAppName.\n\n'
            '${group.description}\n\n'
            '${group.memberIds.length} members, '
            '${group.getFormattedFocusTime()} focused together.\n\n'
            'Group ID: ${group.id}',
        subject: 'Join my focus group: ${group.name}',
      ),
    );
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    final palette = context.palette;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? palette.error : palette.accent,
      ),
    );
  }

  Future<void> _joinGroup(GroupModel group) async {
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;
      await ref
          .read(groupActionsProvider)
          .joinGroup(
            group.id,
            user.uid,
            user.displayName ?? user.email?.split('@')[0] ?? 'User',
          );
      _snack('You joined "${group.name}"');
    } catch (e) {
      _snack("Couldn't join: $e", error: true);
    }
  }

  Future<void> _leaveGroup(GroupModel group) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'Leave group?',
      message:
          'You will leave "${group.name}". Your focus time stays in the '
          'group total.',
      confirmLabel: 'Leave group',
      cancelLabel: 'Stay',
    );
    if (!confirmed) return;

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;
      await ref.read(groupActionsProvider).leaveGroup(group.id, user.uid);
      if (mounted) Navigator.pop(context);
      _snack('You left the group');
    } catch (e) {
      _snack("Couldn't leave: $e", error: true);
    }
  }

  Future<void> _deleteGroup(GroupModel group) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'Delete group?',
      message:
          '"${group.name}", its members and all focus records will be '
          'permanently deleted. This cannot be undone.',
      confirmLabel: 'Delete forever',
      cancelLabel: 'Keep group',
    );
    if (!confirmed) return;

    try {
      await ref.read(groupActionsProvider).deleteGroup(group.id);
      if (mounted) Navigator.pop(context);
      _snack('"${group.name}" was deleted');
    } catch (e) {
      _snack("Couldn't delete: $e", error: true);
    }
  }
}
