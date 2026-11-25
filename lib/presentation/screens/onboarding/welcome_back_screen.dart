import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/presentation/providers/auth_provider.dart';
import 'package:staylit/presentation/providers/onboarding_provider.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';

class WelcomeBackScreen extends ConsumerWidget {
  const WelcomeBackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final currentUser = ref.watch(currentUserProvider).value;
    final displayName = currentUser?.displayName?.split(' ').first ?? 'there';

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          const Spacer(),
          Text(
            'Welcome back, $displayName!',
            style: textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "Let's finish setting up so Staylit fits you.",
            style: textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          AppPillButton(
            label: 'Continue',
            onPressed: ref.read(onboardingProvider.notifier).nextPage,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
