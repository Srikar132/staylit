import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/providers/auth_provider.dart';
import 'package:staylit/presentation/providers/daily_stats_provider.dart';
import 'package:staylit/presentation/providers/parental_control_provider.dart';
import 'package:staylit/presentation/providers/theme_mode_provider.dart';
import 'package:staylit/presentation/screens/debug/design_gallery_screen.dart';
import 'package:staylit/presentation/screens/profile/profile_view.dart';
import 'package:staylit/presentation/widgets/appearance_sheet.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';
import 'package:staylit/widgets/bottom_sheet_darg_handler.dart';
import 'package:staylit/widgets/parental_control_dialogs.dart';

/// Profile: wires providers into [ProfileView] and owns the side effects
/// (parental mode passwords, sign out).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final parental = ref.watch(parentalControlProvider(user.uid)).value;
    final streak = ref.watch(streakProvider(user.uid)).value;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      body: ProfileView(
        data: ProfileData(
          name: user.displayName ?? 'You',
          email: user.email,
          photoUrl: user.photoURL,
          focusMinutes: user.totalFocusTime,
          sessions: user.totalSessions,
          currentStreak: streak?.current ?? 0,
          parentalEnabled: parental?.isEnabled ?? false,
          appearanceLabel: AppearanceTile.labelFor(themeMode),
        ),
        onBack: () => context.pop(),
        onAppearance: () => showAppearanceSheet(context),
        onParentalChanged: (value) =>
            _toggleParental(context, ref, user.uid, value),
        onChangePassword: () => _changePassword(context, ref, user.uid),
        onSignOut: () => _confirmSignOut(context, ref),
        extra: kDebugMode ? const DesignGalleryTile() : null,
      ),
    );
  }

  void _snack(ScaffoldMessengerState messenger, String message, Color color) {
    messenger.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _toggleParental(
    BuildContext context,
    WidgetRef ref,
    String userId,
    bool enable,
  ) async {
    final service = ref.read(parentalControlServiceProvider);
    final palette = context.palette;
    final messenger = ScaffoldMessenger.of(context);

    if (enable) {
      final hasPassword = await service.hasPassword(userId);
      if (!hasPassword) {
        if (!context.mounted) return;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => CreatePasswordDialog(
            onConfirm: (password) async {
              try {
                await service.setupParentalControl(
                  userId: userId,
                  password: password,
                );
                _snack(messenger, 'Parental mode enabled', palette.accent);
              } catch (e) {
                _snack(messenger, 'Error: $e', palette.error);
              }
            },
          ),
        );
      } else {
        await service.enableParentalMode(userId);
      }
      return;
    }

    // Turning it off needs the password.
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => VerifyPasswordDialog(
        title: 'Turn off parental mode',
        description: 'Enter your parental control password to continue',
        onVerify: (password) async {
          final isValid = await service.verifyPassword(
            userId: userId,
            password: password,
          );
          if (isValid) {
            await service.disableParentalMode(userId);
            _snack(messenger, 'Parental mode disabled', palette.warning);
          } else {
            _snack(messenger, 'Incorrect password', palette.error);
          }
          return isValid;
        },
      ),
    );
  }

  Future<void> _changePassword(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final service = ref.read(parentalControlServiceProvider);
    final palette = context.palette;
    final messenger = ScaffoldMessenger.of(context);

    if (!await service.hasPassword(userId)) {
      _snack(messenger, 'Turn on parental mode first', palette.warning);
      return;
    }
    if (!context.mounted) return;

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => VerifyPasswordDialog(
        title: 'Verify it is you',
        description: 'Enter your current password',
        onVerify: (password) =>
            service.verifyPassword(userId: userId, password: password),
      ),
    );

    if (verified == true && context.mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => CreatePasswordDialog(
          onConfirm: (newPassword) async {
            try {
              await service.changePassword(
                userId: userId,
                newPassword: newPassword,
              );
              _snack(messenger, 'Password changed', palette.accent);
            } catch (e) {
              _snack(messenger, 'Error: $e', palette.error);
            }
          },
        ),
      );
    }
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final textTheme = Theme.of(sheetContext).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BottomSheetDragHandle(),
                const SizedBox(height: 12),
                Text('Sign out?', style: textTheme.displaySmall),
                const SizedBox(height: 8),
                Text(
                  'You can sign back in anytime.',
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                AppPillButton(
                  label: 'Stay signed in',
                  onPressed: () => Navigator.pop(sheetContext),
                ),
                const SizedBox(height: 10),
                AppPillButton(
                  label: 'Sign out',
                  variant: PillButtonVariant.outline,
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await ref.read(authNotifierProvider.notifier).signOut();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
