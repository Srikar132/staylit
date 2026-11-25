import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/core/constants/app_info.dart';
import 'package:staylit/core/constants/images.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/providers/auth_provider.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';
import 'package:staylit/widgets/bottom_sheet_darg_handler.dart';

/// Sign-in sheet shown from the welcome screen.
class AuthActionsBottomModel extends ConsumerWidget {
  const AuthActionsBottomModel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final authState = ref.watch(authNotifierProvider);
    final authNotifier = ref.read(authNotifierProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BottomSheetDragHandle(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Welcome to $kAppName',
              style: textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            if (authState.isSigningIn)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              AppPillButton(
                label: 'Continue with Google',
                variant: PillButtonVariant.outline,
                leading: Image.asset(kGoogleLogoImage, height: 20),
                onPressed: () async {
                  await authNotifier.signInWithGoogle();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            if (authState.hasError)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(
                  'Sign in failed. Please try again.',
                  style: textTheme.bodySmall?.copyWith(color: palette.error),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'By continuing, you agree to our Terms of Service and '
              'Privacy Policy.',
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
