import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';
import 'package:staylit/presentation/widgets/design/icon_circle_button.dart';
import 'package:staylit/presentation/widgets/design/message_card.dart';

/// One member row, already resolved from a member document.
@immutable
class MemberTileData {
  const MemberTileData({
    required this.name,
    required this.focusText,
    required this.isAdmin,
    required this.isMe,
    this.photoUrl,
  });

  final String name;
  final String focusText;
  final bool isAdmin;
  final bool isMe;
  final String? photoUrl;
}

/// Everything the group detail screen shows.
@immutable
class GroupDetailData {
  const GroupDetailData({
    required this.name,
    required this.description,
    required this.memberCount,
    required this.totalFocusText,
    required this.goalText,
    required this.isPublic,
    required this.isMember,
    required this.isCreator,
    required this.showLeaderboard,
    required this.members,
  });

  final String name;
  final String description;
  final int memberCount;
  final String totalFocusText;

  /// e.g. "2h a day", or null when the group has no goal.
  final String? goalText;
  final bool isPublic;
  final bool isMember;
  final bool isCreator;
  final bool showLeaderboard;

  /// Sorted by focus time, best first.
  final List<MemberTileData> members;
}

/// The group detail screen. Pure presentation.
class GroupDetailView extends StatefulWidget {
  const GroupDetailView({
    super.key,
    required this.data,
    required this.onBack,
    required this.onShare,
    required this.onDelete,
    required this.onJoin,
    required this.onLeave,
  });

  final GroupDetailData data;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback onJoin;
  final VoidCallback onLeave;

  @override
  State<GroupDetailView> createState() => _GroupDetailViewState();
}

class _GroupDetailViewState extends State<GroupDetailView> {
  bool _showLeaderboard = false;

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final leaderboard = _showLeaderboard && data.showLeaderboard;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
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
                      icon: Icons.arrow_back_ios_new_rounded,
                      semanticLabel: 'Back',
                      onPressed: widget.onBack,
                    ),
                    const Spacer(),
                    if (data.isMember)
                      IconCircleButton(
                        icon: Icons.ios_share_rounded,
                        semanticLabel: 'Share group',
                        onPressed: widget.onShare,
                      ),
                    if (data.isCreator) ...[
                      const SizedBox(width: AppSpacing.sm),
                      IconCircleButton(
                        icon: Icons.delete_outline_rounded,
                        semanticLabel: 'Delete group',
                        foreground: palette.error,
                        onPressed: widget.onDelete,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    _Avatar(
                      name: data.name,
                      size: 56,
                      color: palette.groupColor(data.name),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.name,
                            style: textTheme.displaySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            data.isPublic ? 'Public group' : 'Private group',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (data.description.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(data.description, style: textTheme.bodyLarge),
                ],
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        label: 'Members',
                        value: '${data.memberCount}',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _Stat(
                        label: 'Focused',
                        value: data.totalFocusText,
                      ),
                    ),
                    if (data.goalText != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _Stat(label: 'Goal', value: data.goalText!),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                if (data.showLeaderboard) ...[
                  _Segments(
                    leaderboard: _showLeaderboard,
                    onChanged: (v) => setState(() => _showLeaderboard = v),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ] else ...[
                  Text('Members', style: textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (data.members.isEmpty)
                  const MessageCard(title: 'No members yet')
                else
                  for (var i = 0; i < data.members.length; i++) ...[
                    _MemberRow(
                      member: data.members[i],
                      rank: leaderboard ? i + 1 : null,
                      medal: leaderboard && i < _medals.length
                          ? _medals[i]
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
              ],
            ),
          ),
          if (!data.isMember)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: AppPillButton(
                label: 'Join group',
                icon: Icons.group_add_rounded,
                onPressed: widget.onJoin,
              ),
            )
          else if (!data.isCreator)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: AppPillButton(
                label: 'Leave group',
                variant: PillButtonVariant.outline,
                onPressed: widget.onLeave,
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.size, required this.color});

  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final letter = name.trim().isEmpty ? 'G' : name.trim()[0].toUpperCase();
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? palette.onInk
        : palette.ink;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        letter,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: onColor),
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
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: textTheme.headlineMedium),
            ),
            Text(label, style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({required this.leaderboard, required this.onChanged});

  final bool leaderboard;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget segment(String label, bool value) {
      final selected = leaderboard == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: selected ? palette.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? palette.onAccent : palette.onCanvas,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [segment('Members', false), segment('Leaderboard', true)],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, this.rank, this.medal});

  final MemberTileData member;
  final int? rank;
  final String? medal;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: member.isMe ? palette.accentSoft : palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          if (rank != null) ...[
            SizedBox(
              width: 28,
              child: medal != null
                  ? Text(medal!, style: const TextStyle(fontSize: 20))
                  : Text('$rank', style: textTheme.titleMedium),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          _Avatar(
            name: member.name,
            size: 36,
            color: palette.groupColor(member.name),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    member.isMe ? '${member.name} (you)' : member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                ),
                if (member.isAdmin) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surfaceTrack,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text('Admin', style: textTheme.labelSmall),
                  ),
                ],
              ],
            ),
          ),
          Text(
            member.focusText,
            style: textTheme.titleMedium?.copyWith(color: palette.accentText),
          ),
        ],
      ),
    );
  }
}
