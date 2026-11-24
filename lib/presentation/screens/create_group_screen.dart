import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pace/data/models/group_model.dart';
import 'package:pace/presentation/providers/group_provider.dart';
import 'package:pace/presentation/providers/auth_provider.dart';
import 'package:pace/core/theme/theme_context.dart';

/// Screen for creating a new group
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

  void _showShareDialog(
    BuildContext context,
    String groupId,
    String groupName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.palette.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.palette.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.share,
                color: context.palette.accentText,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Invite Friends!',
                style: TextStyle(color: context.palette.onCanvas, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your group "$groupName" is ready! Share it with friends to get them started.',
              style: TextStyle(
                color: context.palette.onCanvasSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.palette.onCanvas.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.palette.onCanvas.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.link, color: context.palette.accentText, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Group ID: $groupId',
                      style: TextStyle(
                        color: context.palette.onCanvasMuted,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Later',
              style: TextStyle(color: context.palette.onCanvasMuted),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _shareToWhatsApp(groupId, groupName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(
                0xFF25D366,
              ), // WhatsApp brand color, not app theme
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Icon(Icons.send, color: context.palette.onCanvas, size: 18),
            label: Text(
              'Share via WhatsApp',
              style: TextStyle(
                color: context.palette.onCanvas,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _shareToWhatsApp(String groupId, String groupName) {
    final message =
        '🎯 Join my focus group: "$groupName"!\n\n'
        '📚 Let\'s stay focused and productive together.\n'
        '🏆 Track progress on the leaderboard.\n\n'
        '👉 Open Pace app and search for this group:\n'
        'Group ID: $groupId\n\n'
        '💪 Let\'s achieve our goals together!';

    SharePlus.instance.share(
      ShareParams(text: message, subject: 'Join my focus group: $groupName'),
    );
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('User not logged in');

      final groupActions = ref.read(groupActionsProvider);

      final createdGroupId = await groupActions.createGroup(
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

      if (mounted) {
        final groupName = _nameController.text;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: context.palette.onCanvas),
                const SizedBox(width: 12),
                Expanded(child: Text('Group "$groupName" created!')),
              ],
            ),
            backgroundColor: context.palette.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context);

        // Show share dialog after successful creation
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showShareDialog(context, createdGroupId, groupName);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: context.palette.onCanvas),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: context.palette.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.canvas,
      appBar: AppBar(
        backgroundColor: context.palette.canvas,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: context.palette.onCanvas),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Group',
          style: TextStyle(
            color: context.palette.onCanvas,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.palette.accent,
                      context.palette.accent.withValues(alpha: 0.6),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: context.palette.accent.withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.group,
                  size: 40,
                  color: context.palette.onCanvas,
                ),
              ),
            ),
            const SizedBox(height: 32),

            _buildTextField(
              controller: _nameController,
              label: 'Group Name',
              hint: 'e.g., Study Squad, Gym Warriors',
              icon: Icons.groups,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a group name';
                }
                if (value.length < 3) {
                  return 'Name must be at least 3 characters';
                }
                if (value.length > 50) {
                  return 'Name must be less than 50 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'What is this group about?',
              icon: Icons.description,
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                if (value.length < 10) {
                  return 'Description must be at least 10 characters';
                }
                if (value.length > 200) {
                  return 'Description must be less than 200 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: context.palette.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Group Settings',
                  style: TextStyle(
                    color: context.palette.onCanvas,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildSwitchTile(
              title: 'Public Group',
              subtitle: 'Anyone can find and join',
              icon: Icons.public,
              value: _isPublic,
              onChanged: (value) => setState(() => _isPublic = value),
            ),

            _buildSwitchTile(
              title: 'Member Invites',
              subtitle: 'Allow members to invite others',
              icon: Icons.person_add,
              value: _allowMemberInvites,
              onChanged: (value) => setState(() => _allowMemberInvites = value),
            ),

            _buildSwitchTile(
              title: 'Leaderboard',
              subtitle: 'Show member rankings',
              icon: Icons.emoji_events,
              value: _showLeaderboard,
              onChanged: (value) => setState(() => _showLeaderboard = value),
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.palette.surfaceRaised,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: context.palette.accent.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.palette.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.flag,
                          color: context.palette.accentText,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Daily Focus Goal',
                        style: TextStyle(
                          color: context.palette.onCanvas,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _focusGoalMinutes.toDouble(),
                          min: 0,
                          max: 480,
                          divisions: 48,
                          activeColor: context.palette.accent,
                          inactiveColor: context.palette.onCanvasDisabled,
                          onChanged: (value) {
                            setState(() => _focusGoalMinutes = value.toInt());
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: context.palette.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _focusGoalMinutes == 0
                              ? 'None'
                              : _focusGoalMinutes < 60
                              ? '${_focusGoalMinutes}m'
                              : '${_focusGoalMinutes ~/ 60}h ${_focusGoalMinutes % 60}m',
                          style: TextStyle(
                            color: context.palette.accentText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.palette.accent,
                  foregroundColor: context.palette.onAccent,
                  disabledBackgroundColor: context.palette.accent.withValues(
                    alpha: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: context.palette.ink,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle,
                            color: context.palette.onAccent,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Create Group',
                            style: TextStyle(
                              color: context.palette.onAccent,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: context.palette.accentText, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: context.palette.onCanvas,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: TextStyle(color: context.palette.onCanvas, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: context.palette.onCanvasDisabled),
            filled: true,
            fillColor: context.palette.surfaceRaised,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.palette.accent, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.palette.error, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? context.palette.accent.withValues(alpha: 0.3)
              : context.palette.onCanvas.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.palette.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: context.palette.accentText, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.palette.onCanvas,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.palette.onCanvasMuted,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: context.palette.accent,
            activeTrackColor: context.palette.accent.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
