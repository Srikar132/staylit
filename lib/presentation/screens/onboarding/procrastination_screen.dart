import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:staylit/core/router/app_router.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/providers/auth_provider.dart';
import 'package:staylit/presentation/providers/onboarding_provider.dart';
import 'package:staylit/presentation/screens/onboarding/onboarding_layout.dart';
import 'package:staylit/presentation/widgets/design/option_card.dart';

class ProcrastinationScreen extends ConsumerWidget {
  const ProcrastinationScreen({super.key});

  static const _levels = <({String id, String text, IconData icon})>[
    (
      id: 'struggle',
      text: 'I struggle to get started',
      icon: Icons.hourglass_empty_rounded,
    ),
    (
      id: 'few_bad_days',
      text: 'I have a few bad days',
      icon: Icons.wb_cloudy_outlined,
    ),
    (
      id: 'consistent',
      text: "I'm fairly consistent",
      icon: Icons.trending_up_rounded,
    ),
  ];

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: context.palette.error),
    );
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    await user.when(
      data: (user) async {
        if (user == null) {
          _showError(context, 'User not found. Please sign in again.');
          return;
        }
        try {
          await ref
              .read(onboardingProvider.notifier)
              .completeOnboarding(user.uid);
          // Route back through /splash so the router's redirect logic decides
          // where to land next.
          if (context.mounted) context.go(splashRoute);
        } catch (e) {
          if (context.mounted) _showError(context, 'Error: $e');
        }
      },
      loading: () async {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Loading user data...')));
      },
      error: (error, stack) async =>
          _showError(context, 'Error loading user: $error'),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return OnboardingQuestionLayout(
      title: 'How often do you procrastinate before you start focusing?',
      actionLabel: 'Continue',
      onAction: state.procrastinationLevel == null
          ? null
          : () => _complete(context, ref),
      children: [
        for (final level in _levels)
          OptionCard(
            title: level.text,
            leading: Icon(level.icon),
            selected: state.procrastinationLevel == level.id,
            onTap: () => notifier.setProcrastinationLevel(level.id),
          ),
      ],
    );
  }
}
