import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pace/presentation/providers/auth_provider.dart';
import 'package:pace/presentation/providers/onboarding_provider.dart';
import 'package:pace/core/theme/theme_context.dart';

class WelcomeBackScreen extends ConsumerWidget {
  const WelcomeBackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider).value;
    final displayName = currentUser?.displayName?.split(' ').first ?? 'there';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),

          // Welcome message
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Welcome back $displayName!',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: context.palette.onCanvas,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 40),

          const Spacer(),

          // Continue button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ref.read(onboardingProvider.notifier).nextPage();
              },
              child: const Text('Continue'),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
