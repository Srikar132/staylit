import 'package:flutter/material.dart';
import 'package:pace/core/theme/app_dimens.dart';
import 'package:pace/core/theme/theme_context.dart';
import 'package:pace/presentation/screens/focus/focus_home_data.dart';
import 'package:pace/presentation/widgets/design/app_pill_button.dart';
import 'package:pace/presentation/widgets/design/goal_card.dart';
import 'package:pace/presentation/widgets/design/message_card.dart';
import 'package:pace/presentation/widgets/design/pill_chip.dart';
import 'package:pace/presentation/widgets/design/session_card.dart';

/// The Focus (home) tab: greeting, today's goal, session setup, today's
/// sessions and the start button. Pure presentation: all data and
/// callbacks come from the screen that owns it.
class FocusHomeView extends StatelessWidget {
  const FocusHomeView({
    super.key,
    required this.data,
    required this.onProfile,
    required this.onEditGoal,
    required this.onSetup,
    required this.onStart,
  });

  final FocusHomeData data;

  final VoidCallback onProfile;
  final VoidCallback onEditGoal;
  final VoidCallback onSetup;
  final VoidCallback onStart;

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
                _Greeting(data: data, onProfile: onProfile),
                const SizedBox(height: AppSpacing.xl),
                GoalCard(
                  goalMinutes: data.goalMinutes,
                  todayMinutes: data.todayMinutes,
                  weekMinutes: data.weekMinutes,
                  onEditGoal: onEditGoal,
                ),
                const SizedBox(height: AppSpacing.lg),
                _SetupTile(
                  title: data.setupTitle,
                  subtitle: data.setupSubtitle,
                  onTap: onSetup,
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text("Today's sessions", style: textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.md),
                if (data.sessions.isEmpty)
                  const MessageCard(
                    title: 'No sessions yet today',
                    body: 'Start one and it will show up here.',
                  )
                else
                  for (final session in data.sessions) ...[
                    SessionCard(
                      title: session.title,
                      subtitle: session.subtitle,
                      minutes: session.minutes,
                      icon: session.icon,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
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
            child: AppPillButton(
              label: 'Start Focus Session',
              onPressed: onStart,
            ),
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.data, required this.onProfile});

  final FocusHomeData data;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final initial = data.firstName.isEmpty
        ? '?'
        : data.firstName.characters.first.toUpperCase();

    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Open profile',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onProfile,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: palette.surface,
              backgroundImage: data.photoUrl != null
                  ? NetworkImage(data.photoUrl!)
                  : null,
              child: data.photoUrl == null
                  ? Text(
                      initial,
                      style: textTheme.titleLarge?.copyWith(
                        color: palette.accentText,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello ${data.firstName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.headlineMedium,
              ),
              Text('Ready to focus?', style: textTheme.bodyMedium),
            ],
          ),
        ),
        PillChip(icon: Icons.phone_android_rounded, label: data.usageText),
      ],
    );
  }
}

class _SetupTile extends StatelessWidget {
  const _SetupTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Session setup. $title. $subtitle. Tap to change.',
      excludeSemantics: true,
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: palette.surfaceRaised,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.timer_outlined,
                    color: palette.accentText,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleMedium),
                      Text(subtitle, style: textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.tune_rounded, color: palette.onCanvasMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
