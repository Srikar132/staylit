import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/data/models/group_model.dart';
import 'package:staylit/presentation/providers/auth_provider.dart';
import 'package:staylit/presentation/providers/group_provider.dart';
import 'package:staylit/presentation/screens/create_group_screen.dart';
import 'package:staylit/presentation/screens/group_detail_screen.dart';
import 'package:staylit/presentation/screens/groups/groups_view.dart';
import 'package:staylit/presentation/widgets/design/group_card.dart';
import 'package:staylit/presentation/widgets/design/message_card.dart';

GroupTileData _tile(GroupModel group) => GroupTileData(
  id: group.id,
  name: group.name,
  memberCount: group.memberIds.length,
  focusTimeText: group.getFormattedFocusTime(),
);

void _openGroup(BuildContext context, String groupId) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: groupId)),
  );
}

/// The Groups tab: wires providers into [GroupsView].
class GroupScreen extends ConsumerWidget {
  const GroupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      return const Center(child: Text('Please sign in to view groups'));
    }

    final groups = ref.watch(userGroupsProvider(user.uid));
    final suggested = ref.watch(suggestedGroupsProvider(user.uid));

    return GroupsView(
      loading: groups.isLoading && !groups.hasValue,
      error: groups.hasError && !groups.hasValue ? '${groups.error}' : null,
      yourGroups: [
        for (final g in groups.value ?? const <GroupModel>[]) _tile(g),
      ],
      suggested: [
        for (final g in suggested.value ?? const <GroupModel>[]) _tile(g),
      ],
      onSearch: () =>
          showSearch(context: context, delegate: GroupSearchDelegate()),
      onCreate: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
      ),
      onOpen: (id) => _openGroup(context, id),
    );
  }
}

/// Search delegate for finding public groups.
class GroupSearchDelegate extends SearchDelegate<String> {
  @override
  String get searchFieldLabel => 'Search public groups';

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: 'Clear',
        icon: const Icon(Icons.clear_rounded),
        onPressed: () => query = '',
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    tooltip: 'Back',
    icon: const Icon(Icons.arrow_back_rounded),
    onPressed: () => close(context, ''),
  );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    return ColoredBox(
      color: context.palette.canvas,
      child: Consumer(
        builder: (context, ref, _) {
          if (query.trim().isEmpty) {
            return const _Hint('Search for public groups');
          }
          final results = ref.watch(groupSearchProvider(query));
          return results.when(
            data: (groups) {
              if (groups.isEmpty) return const _Hint('No groups found');
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  for (final group in groups) ...[
                    GroupCard(
                      name: group.name,
                      memberCount: group.memberIds.length,
                      focusTimeText: group.getFormattedFocusTime(),
                      onTap: () => _openGroup(context, group.id),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const _Hint("Couldn't search right now"),
          );
        },
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Align(
        alignment: Alignment.topCenter,
        child: MessageCard(title: text),
      ),
    );
  }
}
