import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:staylit/core/router/app_router.dart';
import 'package:staylit/presentation/providers/permission_provider.dart';
import 'package:staylit/presentation/providers/auth_provider.dart';
import 'package:staylit/widgets/permission_instruction_dialog.dart';
import 'package:staylit/models/model_manager.dart';
import 'package:staylit/core/constants/app_info.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/presentation/screens/permissions/permissions_view.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';
import 'package:staylit/widgets/bottom_sheet_darg_handler.dart';

class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key});

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Add lifecycle observer to detect when user returns from settings
    WidgetsBinding.instance.addObserver(this);

    // Initial permission check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(permissionProvider.notifier).checkPermissions();
      }
    });
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app returns to foreground, recheck all permissions with a delay
    if (state == AppLifecycleState.resumed && mounted) {
      // Add a delay to ensure the app is fully resumed before checking
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          ref.read(permissionProvider.notifier).checkPermissions();
        }
      });
    }
  }

  Future<void> _showPermissionInstructionDialog({
    required String title,
    required String description,
    required List<String> steps,
    required String permissionType,
    required VoidCallback onRequestPermission,
  }) async {
    await BottomSheetManager.show(
      context: context,
      child: PermissionInstructionDialog(
        title: title,
        description: description,
        steps: steps,
        onAllowPressed: () async {
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
          onRequestPermission();

          // Show confirmation dialog after user returns
          if (mounted) {
            await Future.delayed(const Duration(milliseconds: 1000));
            if (mounted) {
              await _showPermissionConfirmationDialog(permissionType);
            }
          }
        },
        allowButtonText: 'Open Settings',
      ),
    );
  }

  Future<void> _showPermissionConfirmationDialog(String permissionType) async {
    if (!mounted) return;

    final permissionNotifier = ref.read(permissionProvider.notifier);
    String permissionName = permissionType == 'overlay'
        ? 'Display Over Other Apps'
        : 'Display Popup Windows';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Enabled?'),
        content: Text(
          'Have you enabled the $permissionName permission? We\'ll check if it\'s working now.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted) {
                await permissionNotifier.checkPermissions();
              }
            },
            child: const Text('Yes, I enabled it'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAllPermissionsConfirmationDialog() async {
    if (!mounted) return;

    final authState = ref.read(authStateProvider);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirm All Permissions'),
        content: const Text(
          'Have you granted all the required permissions? This will complete your setup.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }

              // Recheck permissions first
              await ref.read(permissionProvider.notifier).checkPermissions();

              // Wait a bit for state to update
              await Future.delayed(const Duration(milliseconds: 300));

              if (!mounted) return;

              final updatedPermissionState = ref.read(permissionProvider);

              debugPrint('Updated Permission State: $updatedPermissionState');

              // Check if all permissions are granted
              if (updatedPermissionState.allGranted) {
                // Complete permissions
                await authState.when(
                  data: (user) async {
                    if (user != null) {
                      try {
                        await ref
                            .read(permissionProvider.notifier)
                            .completePermissions(user.uid);

                        // Route back through /splash so the router's
                        // redirect logic (single source of truth) decides
                        // where to actually land, instead of duplicating
                        // that decision here.
                        if (!context.mounted) return;

                        context.go(splashRoute);
                      } catch (e) {
                        if (mounted) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: theme.colorScheme.error,
                            ),
                          );
                        }
                      }
                    }
                  },
                  loading: () {},
                  error: (error, stack) {},
                );
              } else {
                // Show error - not all permissions granted
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Please grant all permissions before continuing. Missing: ${_getMissingPermissions(updatedPermissionState)}',
                      ),
                      backgroundColor: theme.colorScheme.error,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              }
            },
            child: const Text('Yes, Complete Setup'),
          ),
        ],
      ),
    );
  }

  String _getMissingPermissions(PermissionState state) {
    final missing = <String>[];
    if (!state.usagePermission) missing.add('Usage Stats');
    if (!state.backgroundPermission) missing.add('Background');
    if (!state.overlayPermission) missing.add('Overlay');
    if (!state.displayPopupPermission) missing.add('Display Popup');
    if (!state.accessibilityPermission) missing.add('Accessibility');
    return missing.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final permissionState = ref.watch(permissionProvider);
    final permissionNotifier = ref.read(permissionProvider.notifier);
    debugPrint('Permission State Changed: $permissionState');

    // Listen for permission changes but DO NOT auto-navigate
    // User must manually confirm completion via the button
    ref.listen(permissionProvider, (previous, current) {
      if (!mounted) return;

      // Log permission status for debugging
      debugPrint('Permissions updated - All granted: ${current.allGranted}');
      debugPrint('  Usage: ${current.usagePermission}');
      debugPrint('  Background: ${current.backgroundPermission}');
      debugPrint('  Overlay: ${current.overlayPermission}');
      debugPrint('  Display Popup: ${current.displayPopupPermission}');
      debugPrint('  Accessibility: ${current.accessibilityPermission}');
      debugPrint('  Notification: ${current.notificationPermission}');
    });

    final permissions = [
      {
        'title': 'Usage access',
        'icon': Icons.bar_chart_rounded,
        'description': 'This allows us to track your app usage.',
        'granted': permissionState.usagePermission,
        'onTap': () async {
          await permissionNotifier.requestUsagePermission();
          // Recheck after a short delay to allow settings to update
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            await permissionNotifier.checkPermissions();
          }
        },
      },
      {
        'title': 'Run in background',
        'icon': Icons.battery_charging_full_rounded,
        'description':
            'Keep the app running in the background for continuous monitoring.',
        'granted': permissionState.backgroundPermission,
        'onTap': () async {
          await permissionNotifier.requestBackgroundPermission();
          // Recheck after a short delay
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            await permissionNotifier.checkPermissions();
          }
        },
      },
      {
        'title': 'Notifications',
        'icon': Icons.notifications_none_rounded,
        'description': 'Allow the app to send you notifications.',
        'granted': permissionState.notificationPermission,
        'onTap': () async {
          await permissionNotifier.requestNotificationPermission();
          // Recheck after a short delay
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            await permissionNotifier.checkPermissions();
          }
        },
      },
      {
        'title': 'Display over other apps',
        'icon': Icons.layers_outlined,
        'description': 'Show blocking screens when you open distracting apps.',
        'granted': permissionState.overlayPermission,
        'onTap': () => _showPermissionInstructionDialog(
          title: 'Display Over Other Apps Permission',
          description:
              'This permission allows $kAppName to display blocking screens over other apps when you try to open distracting apps.',
          steps: const [
            'Tap "Open Settings" below',
            'Find "$kAppName" in the app list',
            'Toggle "Allow display over other apps" ON',
            'Return to this app',
          ],
          permissionType: 'overlay',
          onRequestPermission: permissionNotifier.requestOverlayPermission,
        ),
      },
      {
        'title': 'Pop-up windows',
        'icon': Icons.web_asset_rounded,
        'description': 'Show focus reminders and motivational popups.',
        'granted': permissionState.displayPopupPermission,
        'onTap': () => _showPermissionInstructionDialog(
          title: 'Display Popup Windows Permission',
          description:
              'This permission allows $kAppName to show popup reminders and motivational messages to help you stay focused.',
          steps: const [
            'Tap "Open Settings" below',
            'Find "$kAppName" in the Special App Access list',
            'Look for "Display pop-up windows" or similar option',
            'Toggle the permission ON',
            'Return to this app',
          ],
          permissionType: 'displayPopup',
          onRequestPermission: permissionNotifier.requestDisplayPopupPermission,
        ),
      },
      {
        'title': 'Accessibility',
        'icon': Icons.accessibility_new_rounded,
        'description': 'Enable advanced app blocking capabilities.',
        'granted': permissionState.accessibilityPermission,
        'onTap': () async {
          await permissionNotifier.requestAccessibilityPermission();
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            await permissionNotifier.checkPermissions();
          }
        },
      },
    ];

    return Scaffold(
      body: PermissionsView(
        items: [
          for (final permission in permissions)
            PermissionItem(
              icon: permission['icon'] as IconData,
              title: permission['title'] as String,
              description: permission['description'] as String,
              granted: permission['granted'] as bool,
              onAllow: permission['onTap'] as Future<void> Function(),
            ),
        ],
        onComplete: _showAllPermissionsConfirmationDialog,
        onWhy: () => _showPermissionInfoSheet(context),
      ),
    );
  }
}

/// Explains each permission in plain words, in a bottom sheet.
void _showPermissionInfoSheet(BuildContext context) {
  const entries = [
    (
      'Usage access',
      'Shows which apps take your time, so limits and blocks fit you.',
    ),
    (
      'Display over other apps',
      'Lets $kAppName show a blocking screen when you open a blocked app.',
    ),
    ('Notifications', 'Focus reminders and session summaries.'),
    (
      'Accessibility',
      'Detects blocked apps, websites and short-form feeds so they can be '
          'stopped. $kAppName does not read or store what you type.',
    ),
    (
      'Background',
      'Keeps blocking running when the phone tries to save battery.',
    ),
    ('Pop-up windows', 'Lets focus reminders appear on top of other apps.'),
  ];

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final textTheme = Theme.of(sheetContext).textTheme;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: BottomSheetDragHandle()),
              const SizedBox(height: AppSpacing.lg),
              Text('Why these permissions?', style: textTheme.displaySmall),
              const SizedBox(height: AppSpacing.xl),
              for (final entry in entries) ...[
                Text(entry.$1, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(entry.$2, style: textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.lg),
              ],
              AppPillButton(
                label: 'Got it',
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      );
    },
  );
}
