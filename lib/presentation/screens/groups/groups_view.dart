import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';
import 'package:staylit/presentation/widgets/design/group_card.dart';
import 'package:staylit/presentation/widgets/design/icon_circle_button.dart';
import 'package:staylit/presentation/widgets/design/message_card.dart';

/// One row of the Groups lists, already resolved from a group document.
@immutable
class GroupTileData {
  const GroupTileData({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.focusTimeText,
  });

  final String id;
  final String name;
  final int memberCount;
  final String focusTimeText;
}

/// The Groups tab: your groups, suggested public groups and a create button.
/// Pure presentation; the screen owns data and navigation.
class GroupsView extends StatelessWidget {
  const GroupsView({
    super.key,
    required this.yourGroups,
    required this.suggested,
    required this.onSearch,
    required this.onCreate,
    required this.onOpen,
    this.loading = false,
    this.error,
  });

  final List<GroupTileData> yourGroups;
  final List<GroupTileData> suggested;
  final bool loading;
  final String? error;

  final VoidCallback onSearch;
  final VoidCallback onCreate;
  final void Function(String groupId) onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Groups', style: textTheme.displaySmall),
                    ),
                    IconCircleButton(
                      icon: Icons.search_rounded,
                      onPressed: onSearch,
                      semanticLabel: 'Search public groups',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.xxxl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (error != null)
                  MessageCard(
                    title: "Couldn't load groups",
                    body: 'Check your connection and try again.',
                    leading: const Icon(Icons.error_outline_rounded),
                  )
                else ...[
                  Text('Your groups', style: textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.md),
                  if (yourGroups.isEmpty)
                    const MessageCard(
                      title: 'No groups yet',
                      body: 'Create one, or join a public group to focus together.',
                    )
                  else
                    for (final group in yourGroups) ...[
                      _card(group),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  if (suggested.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxl),
                    Text('Suggested', style: textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.md),
                    for (final group in suggested) ...[
                      _card(group),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ],
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
              label: 'Create group',
              icon: Icons.add_rounded,
              onPressed: onCreate,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(GroupTileData group) => GroupCard(
    name: group.name,
    memberCount: group.memberCount,
    focusTimeText: group.focusTimeText,
    onTap: () => onOpen(group.id),
  );
}
