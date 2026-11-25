import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/presentation/providers/auth_provider.dart';
import 'package:staylit/presentation/providers/onboarding_provider.dart';
import 'package:staylit/presentation/screens/onboarding/distraction_question_screen.dart';
import 'package:staylit/presentation/screens/onboarding/procrastination_screen.dart';
import 'package:staylit/presentation/screens/onboarding/study_time_screen.dart';
import 'package:staylit/presentation/screens/onboarding/welcome_back_screen.dart';
import 'package:staylit/presentation/widgets/design/step_progress_bar.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingState = ref.watch(onboardingProvider);
    final currentUser = ref.watch(currentUserProvider).value;

    // Check if user is returning (has some data)
    final isReturningUser =
        currentUser?.hasCompletedOnboarding == false &&
        (currentUser?.procrastinationLevel != null ||
            currentUser?.distractions?.isNotEmpty == true);

    final screens = [
      if (isReturningUser) const WelcomeBackScreen(),
      const DistractionQuestionScreen(),
      const StudyTimeScreen(),
      const ProcrastinationScreen(),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                0,
              ),
              child: StepProgressBar(
                currentStep: onboardingState.currentPage,
                stepCount: screens.length,
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: onboardingState.currentPage,
                children: screens,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
