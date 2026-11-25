import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/presentation/providers/onboarding_provider.dart';
import 'package:staylit/presentation/screens/onboarding/onboarding_layout.dart';
import 'package:staylit/presentation/widgets/design/option_card.dart';

class DistractionQuestionScreen extends ConsumerWidget {
  const DistractionQuestionScreen({super.key});

  static const _distractions = <({String id, String text, IconData icon})>[
    (
      id: 'reels',
      text: 'I keep scrolling reels & shorts',
      icon: Icons.video_library_outlined,
    ),
    (
      id: 'notifications',
      text: 'I get distracted by notifications',
      icon: Icons.notifications_outlined,
    ),
    (
      id: 'texting',
      text: 'I keep texting on my phone',
      icon: Icons.message_outlined,
    ),
    (
      id: 'games',
      text: 'I play a lot of games',
      icon: Icons.sports_esports_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return OnboardingQuestionLayout(
      title: "What's your biggest distraction when you're trying to focus?",
      hint: 'You can change this inside the app later.',
      actionLabel: 'Continue',
      onAction: state.distractions.isNotEmpty ? notifier.nextPage : null,
      children: [
        for (final item in _distractions)
          OptionCard(
            multiSelect: true,
            title: item.text,
            leading: Icon(item.icon),
            selected: state.distractions.contains(item.id),
            onTap: () => notifier.toggleDistraction(item.id),
          ),
      ],
    );
  }
}
