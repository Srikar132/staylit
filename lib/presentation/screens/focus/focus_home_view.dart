import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/screens/focus/focus_home_data.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';
import 'package:staylit/presentation/widgets/design/goal_card.dart';
import 'package:staylit/presentation/widgets/design/duration_text.dart';
import 'package:staylit/presentation/widgets/design/mini_stat_card.dart';
import 'package:staylit/presentation/widgets/design/pill_chip.dart';

/// The Focus (home) tab: today at a glance and one big action. Pure
/// presentation: all data and callbacks come from the screen that owns it.
class FocusHomeView extends StatelessWidget {
  const FocusHomeView({
    super.key,
    required this.data,
    required this.onProfile,
    required this.onEditGoal,
    required this.onSetup,
    required this.onStart,
    required this.onScrollDamage,
    required this.onSeeAll,
  });

  final FocusHomeData data;

  final VoidCallback onProfile;
  final VoidCallback onEditGoal;
  final VoidCallback onSetup;
  final VoidCallback onStart;
  final VoidCallback onScrollDamage;
  final VoidCallback onSeeAll;

  static const _axis = ['12a', '6a', '12p', '6p'];

  static String _compact(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}hr';
    return '${h}hr ${m}min';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = context.palette;
    final bucketMinutes = data.currentBucket < data.todayBuckets.length
        ? data.todayBuckets[data.currentBucket]
        : 0;
    final scroll = data.scrollDamage;

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
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PillChip(
                    icon: Icons.timer_outlined,
                    label: data.setupLabel,
                    showChevron: true,
                    onTap: onSetup,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                GoalCard(
                  goalMinutes: data.goalMinutes,
                  todayMinutes: data.todayMinutes,
                  weekMinutes: data.todayBuckets,
                  chartHeight: 100,
                  highlightIndex: data.currentBucket,
                  tooltipText: bucketMinutes > 0 ? _compact(bucketMinutes) : '',
                  axisLabels: _axis,
                  chartDescription:
                      'Focus time today by time of day. '
                      '${DurationText.spoken(data.todayMinutes)} so far.',
                  onEditGoal: onEditGoal,
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your numbers',
                        style: textTheme.headlineSmall,
                      ),
                    ),
                    TextButton(
                      onPressed: onSeeAll,
                      child: Text(
                        'See all',
                        style: textTheme.bodyMedium?.copyWith(
                          color: palette.onCanvasSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: scroll == null
                            ? MiniStatCard(
                                icon: Icons.swipe_vertical_rounded,
                                label: 'Scroll damage',
                                caption: 'Counts the shorts you scroll past',
                                offLabel: 'Turn on',
                                onTap: onScrollDamage,
                              )
                            : MiniStatCard(
                                icon: Icons.swipe_vertical_rounded,
                                label: 'Scroll damage',
                                value: '${scroll.todayCount}',
                                caption: 'items today',
                                trendText: scroll.trendText,
                                trendGood: scroll.trendGood,
                                values: scroll.week,
                                onTap: onScrollDamage,
                              ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: MiniStatCard(
                          icon: Icons.local_fire_department_rounded,
                          label: 'Streak',
                          value: '${data.streak}',
                          caption: data.streak == 1 ? 'day' : 'days',
                          trendText: data.streak == 0
                              ? 'Finish a session today'
                              : null,
                          values: data.streakWeek,
                          onTap: onSeeAll,
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
