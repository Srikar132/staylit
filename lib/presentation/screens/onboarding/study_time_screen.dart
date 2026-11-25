import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/presentation/providers/onboarding_provider.dart';
import 'package:staylit/presentation/screens/onboarding/onboarding_layout.dart';
import 'package:staylit/presentation/widgets/design/option_card.dart';

class StudyTimeScreen extends ConsumerWidget {
  const StudyTimeScreen({super.key});

  static const _studyTimes =
      <({String id, String title, String time, String emoji})>[
        (
          id: 'early_bird',
          title: 'Early Bird',
          time: '5:00 AM - 9:00 AM',
          emoji: '🌅',
        ),
        (
          id: 'morning',
          title: 'Morning Person',
          time: '9:00 AM - 12:00 PM',
          emoji: '☀️',
        ),
        (
          id: 'afternoon',
          title: 'Afternoon Focus',
          time: '12:00 PM - 5:00 PM',
          emoji: '🌤️',
        ),
        (
          id: 'evening',
          title: 'Evening Owl',
          time: '5:00 PM - 9:00 PM',
          emoji: '🌆',
        ),
        (
          id: 'night',
          title: 'Night Owl',
          time: '9:00 PM - 1:00 AM',
          emoji: '🌙',
        ),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return OnboardingQuestionLayout(
      title: "What's your preferred study time?",
      hint: 'You can change this inside the app later.',
      actionLabel: 'Continue',
      onAction: state.preferredStudyTime == null ? null : notifier.nextPage,
      children: [
        for (final item in _studyTimes)
          OptionCard(
            title: item.title,
            subtitle: item.time,
            leading: Text(item.emoji, style: const TextStyle(fontSize: 26)),
            selected: state.preferredStudyTime == item.id,
            onTap: () => notifier.setPreferredStudyTime(item.id),
          ),
      ],
    );
  }
}
