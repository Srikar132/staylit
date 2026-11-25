import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/data/models/group_memeber_model.dart';
import 'package:staylit/data/models/group_model.dart';
import 'package:staylit/presentation/providers/group_provider.dart';
import 'package:staylit/presentation/providers/auth_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/core/constants/app_info.dart';

/// Detailed view of a specific group with members and leaderboard
class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: context.palette.canvas,
      body: groupAsync.when(
        data: (group) {
          if (group == null) return _buildErrorState('Group not found');

          final isAdmin = user != null && group.isAdmin(user.uid);
          final isMember = user != null && group.isMember(user.uid);
          final isCreator = user != null && group.isCreator(user.uid);

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  stretch: true,
                  backgroundColor: context.palette.canvas,
                  leading: IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: context.palette.onCanvas,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    if (isMember)
                      IconButton(
                        icon: Icon(
                          Icons.share,
                          color: context.palette.onCanvas,
                        ),
                        onPressed: () => _shareGroup(group),
                      ),
                    if (isAdmin)
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: context.palette.onCanvas,
                        ),
                        color: context.palette.surfaceRaised,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          if (value == 'delete' && isCreator) {
                            _deleteGroup(group);
                          }
                        },
                        itemBuilder: (context) => [
                          if (isCreator)
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    color: context.palette.error,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete Group',
                                    style: TextStyle(
                                      color: context.palette.onCanvas,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.palette.accent.withValues(alpha: 0.3),
                            context.palette.canvas,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        context.palette.groupColor(group.name),
                                        context.palette
                                            .groupColor(group.name)
                                            .withValues(alpha: 0.7),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.palette
                                            .groupColor(group.name)
                                            .withValues(alpha: 0.4),
                                        blurRadius: 15,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      group.name.isNotEmpty
                                          ? group.name[0].toUpperCase()
                                          : 'G',
                                      style: TextStyle(
                                        color: context.palette.onCanvas,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  group.name,
                                  style: TextStyle(
                                    color: context.palette.onCanvas,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.palette.onCanvas
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.people,
                                            color: context.palette.onCanvas,
                                            size: 12,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${group.memberIds.length} members',
                                            style: TextStyle(
                                              color: context.palette.onCanvas,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (group.settings.isPublic)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: context.palette.accent
                                              .withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.public,
                                              color: context.palette.accentText,
                                              size: 12,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Public',
                                              style: TextStyle(
                                                color:
                                                    context.palette.accentText,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.access_time,
                            label: 'Total Focus',
                            value: group.getFormattedFocusTime(),
                            color: context.palette.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.emoji_events,
                            label: 'Daily Goal',
                            value: group.settings.focusGoalMinutes > 0
                                ? '${group.settings.focusGoalMinutes}m'
                                : 'None',
                            color: context.palette.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.palette.surfaceRaised,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.palette.onCanvas.withValues(
                            alpha: 0.1,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: context.palette.accent.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.description,
                                  color: context.palette.accentText,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'About',
                                style: TextStyle(
                                  color: context.palette.onCanvas,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            group.description,
                            style: TextStyle(
                              color: context.palette.onCanvasSecondary,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ];
            },
            body: membersAsync.when(
              data: (members) {
                return Column(
                  children: [
                    Container(
                      color: context.palette.canvas,
                      child: TabBar(
                        controller: _tabController,
                        labelColor: context.palette.accentText,
                        unselectedLabelColor: context.palette.onCanvasMuted,
                        indicatorColor: context.palette.accent,
                        indicatorWeight: 3,
                        tabs: const [
                          Tab(
                            icon: Icon(Icons.people, size: 20),
                            text: 'Members',
                          ),
                          Tab(
                            icon: Icon(Icons.emoji_events, size: 20),
                            text: 'Leaderboard',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildMembersTab(members, group),
                          _buildLeaderboardTab(members, group),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(color: context.palette.accent),
              ),
              error: (error, stack) =>
                  _buildErrorState('Error loading members: $error'),
            ),
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: context.palette.accent),
        ),
        error: (error, stack) => _buildErrorState('Error: $error'),
      ),
      bottomNavigationBar: groupAsync.whenData((group) {
        if (group == null) return null;
        final user = ref.watch(authStateProvider).value;
        if (user == null) return null;

        final isMember = group.isMember(user.uid);
        final isCreator = group.isCreator(user.uid);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: isMember
                ? (isCreator ? null : _buildLeaveButton(group))
                : _buildJoinButton(group),
          ),
        );
      }).value,
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: context.palette.onCanvas,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: context.palette.onCanvasMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersTab(List<GroupMemberModel> members, GroupModel group) {
    if (members.isEmpty) {
      return Center(
        child: Text(
          'No members yet',
          style: TextStyle(color: context.palette.onCanvasMuted),
        ),
      );
    }

    return ListView.builder(
      scrollCacheExtent: ScrollCacheExtent.pixels(500),
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        final isAdmin = group.isAdmin(member.userId);
        final isCreator = group.isCreator(member.userId);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.palette.surfaceRaised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCreator
                  ? context.palette.accent.withValues(alpha: 0.3)
                  : context.palette.onCanvas.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: context.palette.accent.withValues(
                      alpha: 0.2,
                    ),
                    child: Text(
                      member.displayName[0].toUpperCase(),
                      style: TextStyle(
                        color: context.palette.accentText,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (isCreator)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: context.palette.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.palette.surfaceRaised,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.star,
                          color: context.palette.onAccent,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.displayName,
                            style: TextStyle(
                              color: context.palette.onCanvas,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCreator) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.palette.accent.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'CREATOR',
                              style: TextStyle(
                                color: context.palette.accentText,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ] else if (isAdmin) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.palette.warning.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ADMIN',
                              style: TextStyle(
                                color: context.palette.warning,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: context.palette.onCanvasMuted,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${member.getFormattedFocusTime()} focused',
                          style: TextStyle(
                            color: context.palette.onCanvasMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeaderboardTab(
    List<GroupMemberModel> members,
    GroupModel group,
  ) {
    if (!group.settings.showLeaderboard) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.visibility_off,
              size: 64,
              color: context.palette.onCanvas.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Leaderboard is disabled',
              style: TextStyle(
                color: context.palette.onCanvasMuted,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    final sortedMembers = List<GroupMemberModel>.from(members);

    if (sortedMembers.isEmpty) {
      return Center(
        child: Text(
          'No members yet',
          style: TextStyle(color: context.palette.onCanvasMuted),
        ),
      );
    }

    return ListView.builder(
      scrollCacheExtent: ScrollCacheExtent.pixels(500),
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: sortedMembers.length,
      itemBuilder: (context, index) {
        final member = sortedMembers[index];
        final rank = index + 1;
        final medal = member.getMedalEmoji();

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.palette.surfaceRaised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: rank <= 3
                  ? (rank == 1
                        ? context.palette.warning.withValues(alpha: 0.5)
                        : rank == 2
                        ? context.palette.onCanvasMuted.withValues(alpha: 0.5)
                        : context.palette.premium.withValues(alpha: 0.5))
                  : context.palette.onCanvas.withValues(alpha: 0.1),
              width: rank <= 3 ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: rank <= 3
                      ? (rank == 1
                            ? context.palette.warning.withValues(alpha: 0.2)
                            : rank == 2
                            ? context.palette.onCanvasMuted.withValues(
                                alpha: 0.2,
                              )
                            : context.palette.premium.withValues(alpha: 0.2))
                      : context.palette.accent.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: medal != null
                      ? Text(medal, style: const TextStyle(fontSize: 20))
                      : Text(
                          '#$rank',
                          style: TextStyle(
                            color: context.palette.accentText,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName,
                      style: TextStyle(
                        color: context.palette.onCanvas,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: context.palette.accentText,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          member.getFormattedFocusTime(),
                          style: TextStyle(
                            color: context.palette.accentText,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (rank <= 3)
                Icon(
                  Icons.emoji_events,
                  color: rank == 1
                      ? context.palette.warning
                      : rank == 2
                      ? context.palette.onCanvasMuted
                      : context.palette.premium,
                  size: 24,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJoinButton(GroupModel group) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: () => _joinGroup(group),
        style: ElevatedButton.styleFrom(
          backgroundColor: context.palette.accent,
          foregroundColor: context.palette.onAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_add, color: context.palette.onAccent, size: 20),
            SizedBox(width: 8),
            Text(
              'Join Group',
              style: TextStyle(
                color: context.palette.onAccent,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveButton(GroupModel group) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: () => _leaveGroup(group),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: context.palette.error, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.exit_to_app, color: context.palette.error, size: 20),
            SizedBox(width: 8),
            Text(
              'Leave Group',
              style: TextStyle(
                color: context.palette.error,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: context.palette.error.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              style: TextStyle(color: context.palette.onCanvas),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.palette.accent,
              foregroundColor: context.palette.onAccent,
            ),
            child: Text(
              'Go Back',
              style: TextStyle(color: context.palette.onAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _shareGroup(GroupModel group) {
    SharePlus.instance.share(
      ShareParams(
        text:
            '🎯 Join my focus group "${group.name}" on $kAppName!\n\n'
            '${group.description}\n\n'
            '👥 ${group.memberIds.length} members\n'
            '⏱️ ${group.getFormattedFocusTime()} total focus time\n\n'
            'Group ID: ${group.id}',
        subject: 'Join my focus group: ${group.name}',
      ),
    );
  }

  Future<void> _joinGroup(GroupModel group) async {
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      final groupActions = ref.read(groupActionsProvider);
      await groupActions.joinGroup(
        group.id,
        user.uid,
        user.displayName ?? user.email?.split('@')[0] ?? 'User',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: context.palette.onCanvas),
                const SizedBox(width: 12),
                Expanded(child: Text('Successfully joined "${group.name}"!')),
              ],
            ),
            backgroundColor: context.palette.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: context.palette.error,
          ),
        );
      }
    }
  }

  Future<void> _leaveGroup(GroupModel group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.palette.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Leave Group?',
          style: TextStyle(color: context.palette.onCanvas),
        ),
        content: Text(
          'Are you sure you want to leave "${group.name}"?\n\nYour focus time contributions will remain.',
          style: TextStyle(color: context.palette.onCanvasSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.palette.error),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      final groupActions = ref.read(groupActionsProvider);
      await groupActions.leaveGroup(group.id, user.uid);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Left group successfully'),
            backgroundColor: context.palette.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: context.palette.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteGroup(GroupModel group) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: context.palette.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.palette.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_forever,
                color: context.palette.error,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Delete Group?',
              style: TextStyle(
                color: context.palette.onCanvas,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.palette.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.palette.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: context.palette.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone!',
                      style: TextStyle(
                        color: context.palette.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'All group data, members, and focus time records will be permanently deleted.',
              style: TextStyle(
                color: context.palette.onCanvasSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.palette.onCanvas.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${group.name}"',
                style: TextStyle(
                  color: context.palette.accentText,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: context.palette.onCanvasSecondary,
                fontSize: 15,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.palette.error,
              foregroundColor: context.palette.onError,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Delete Forever',
              style: TextStyle(
                color: context.palette.onCanvas,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      ),
    );

    if (confirm != true) return;

    try {
      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.palette.surfaceRaised,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: context.palette.accent),
                  SizedBox(height: 16),
                  Text(
                    'Deleting group...',
                    style: TextStyle(color: context.palette.onCanvas),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      final groupActions = ref.read(groupActionsProvider);
      await groupActions.deleteGroup(group.id);

      if (mounted) {
        // Close loading dialog
        Navigator.pop(context);

        // Navigate back to groups tab with smooth animation
        Navigator.pop(context);

        // Show success message
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: context.palette.onCanvas),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Group "${group.name}" deleted successfully'),
                    ),
                  ],
                ),
                backgroundColor: context.palette.accent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        // Close loading dialog if open
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: context.palette.onCanvas),
                const SizedBox(width: 12),
                Expanded(child: Text('Error deleting group: $e')),
              ],
            ),
            backgroundColor: context.palette.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }
}
