import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:staylit/presentation/providers/auth_provider.dart';
import 'package:staylit/presentation/providers/app_limits_provider.dart';
import 'package:staylit/presentation/providers/blocked_content_provider.dart';
import 'package:staylit/presentation/providers/permission_provider.dart';
import 'package:staylit/presentation/providers/parental_control_provider.dart';
import 'package:staylit/data/models/blocked_content_model.dart';
import 'package:staylit/data/models/app_limit_model.dart';
import 'package:staylit/services/blocks_native_service.dart';
import 'package:staylit/services/app_limit_native_service.dart';
import 'package:staylit/services/native_service.dart';
import 'package:installed_apps/app_info.dart';
import 'package:staylit/widgets/parental_control_dialogs.dart';

import 'dart:async';

import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/core/constants/app_info.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/presentation/providers/app_management_provide.dart'
    show appIconProvider, installedAppsProvider, pickerAppsProvider;
import 'package:staylit/presentation/widgets/design/app_icon_badge.dart';
import 'package:staylit/presentation/widgets/design/app_limit_card.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';
import 'package:staylit/presentation/widgets/design/icon_circle_button.dart';
import 'package:staylit/presentation/widgets/design/limit_setup_sheet.dart';

// Standalone permission check function accessible by all widgets
Future<bool> _checkAndRequestPermissions(
  BuildContext context,
  WidgetRef ref,
) async {
  debugPrint('🔐 Checking accessibility permission...');

  // Check accessibility permission using provider
  final permissionNotifier = ref.read(permissionProvider.notifier);
  await permissionNotifier.checkPermissions();

  final hasAccessibility = ref.read(permissionProvider).accessibilityPermission;
  debugPrint('🔐 Accessibility permission: $hasAccessibility');

  if (!hasAccessibility) {
    if (context.mounted) {
      debugPrint('🔐 Showing permission dialog...');
      final shouldRequest = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: context.palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Accessibility Permission Required',
            style: TextStyle(color: context.palette.onCanvas),
          ),
          content: Text(
            'This feature requires Accessibility Service to block content.\n\n'
            'Please enable "$kAppName" in Accessibility settings.',
            style: TextStyle(color: context.palette.onCanvasSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                debugPrint('🔐 User cancelled permission request');
                Navigator.pop(context, false);
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: context.palette.onCanvasMuted),
              ),
            ),
            TextButton(
              onPressed: () {
                debugPrint('🔐 User accepted - opening settings');
                Navigator.pop(context, true);
              },
              child: Text(
                'Open Settings',
                style: TextStyle(color: context.palette.accentText),
              ),
            ),
          ],
        ),
      );

      if (shouldRequest == true) {
        debugPrint('🔐 Requesting accessibility permission...');
        await permissionNotifier.requestAccessibilityPermission();
        // Wait a bit for user to potentially grant permission
        await Future.delayed(const Duration(seconds: 2));
        // Re-check permission
        await permissionNotifier.checkPermissions();
        final finalPermission = ref
            .read(permissionProvider)
            .accessibilityPermission;
        debugPrint('🔐 Final permission status: $finalPermission');
        return finalPermission;
      } else {
        debugPrint('🔐 User did not request permission');
      }
    }
    return false;
  }

  debugPrint('🔐 Permission already granted');
  return true;
}

// Check and request Usage Stats permission (required for app limits)
Future<bool> _checkAndRequestUsageStatsPermission(BuildContext context) async {
  debugPrint('📊 Checking usage stats permission...');

  final hasPermission = await NativeService.hasUsageStatsPermission();
  debugPrint('📊 Usage stats permission: $hasPermission');

  if (!hasPermission && context.mounted) {
    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(
              Icons.access_time,
              color: context.palette.accentText,
              size: 28,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Usage Access Required',
                style: TextStyle(color: context.palette.onCanvas, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'App Limits require Usage Access permission to track how long you use apps.\n\n'
          'This permission allows $kAppName to:\n'
          '• Monitor app usage time\n'
          '• Enforce daily limits\n'
          '• Show accurate usage statistics\n\n'
          'Please grant "Usage Access" in the next screen.',
          style: TextStyle(
            color: context.palette.onCanvasSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.palette.onCanvasMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.palette.accent,
              foregroundColor: context.palette.onAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );

    if (shouldRequest == true) {
      debugPrint('📊 Opening usage stats settings...');
      await NativeService.requestUsageStatsPermission();
      await Future.delayed(const Duration(seconds: 2));
      final finalPermission = await NativeService.hasUsageStatsPermission();
      debugPrint('📊 Final usage stats permission: $finalPermission');
      return finalPermission;
    }
  }

  return hasPermission;
}

class BlocksScreen extends ConsumerStatefulWidget {
  const BlocksScreen({super.key});

  @override
  ConsumerState<BlocksScreen> createState() => _BlocksScreenState();
}

class _BlocksScreenState extends ConsumerState<BlocksScreen> {
  StreamSubscription<Map<String, dynamic>>? _blockingEventsSubscription;
  final _appLimitNativeService = AppLimitNativeService();

  @override
  void initState() {
    super.initState();
    _setupBlockingEventListener();
    _setupAppLimitEventListener();
    // Initialize permissions when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(permissionProvider.notifier).checkPermissions();
    });
  }

  void _setupAppLimitEventListener() {
    _appLimitNativeService.initLimitEventsHandler((packageName) {
      debugPrint('⚠️ App limit reached for: $packageName');
      if (mounted) {
        _showAppLimitReachedDialog(packageName);
      }
    });
  }

  void _showAppLimitReachedDialog(String packageName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: context.palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.block, color: context.palette.error, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Time Limit Reached',
                style: TextStyle(color: context.palette.onCanvas, fontSize: 20),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You\'ve reached your daily time limit for this app.',
              style: TextStyle(
                color: context.palette.onCanvasSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'Take a break and focus on your goals! 🎯',
              style: TextStyle(color: context.palette.accentText, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: context.palette.accentText, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _setupBlockingEventListener() {
    try {
      final nativeService = ref.read(blocksNativeServiceProvider);
      _blockingEventsSubscription = nativeService.blockingEventsStream.listen(
        (event) => _handleBlockingEvent(event),
        onError: (error) => debugPrint('Blocking events stream error: $error'),
      );
    } catch (e) {
      debugPrint('Error setting up blocking event listener: $e');
    }
  }

  void _handleBlockingEvent(Map<String, dynamic> event) {
    try {
      final eventType = event['type'] as String?;

      if (eventType == 'website_blocked') {
        final url = event['url'] as String?;
        final appName = event['appName'] as String?;
        if (url != null && appName != null) {
          _showWebsiteBlockedSnackBar(url, appName);
        }
      }
    } catch (e) {
      debugPrint('Error handling blocking event: $e');
    }
  }

  void _showWebsiteBlockedSnackBar(String url, String appName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.block, color: context.palette.onCanvas),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🚫 Website Blocked',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.palette.onCanvas,
                    ),
                  ),
                  Text(
                    '$url in $appName',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.palette.onCanvasSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: context.palette.surface,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  void dispose() {
    _blockingEventsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xxxl,
          ),
          children: [
            Text('Blocks', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: AppSpacing.xl),

            // 1. App Limits
            _AppLimitsSection(userId: user.uid),
            const SizedBox(height: AppSpacing.xxxl),

            // 2. Short Form Content
            _ShortFormBlocksSection(userId: user.uid),
            const SizedBox(height: AppSpacing.xxxl),

            // 3. Website Blocking
            _WebsiteBlockingSection(userId: user.uid),
            const SizedBox(height: AppSpacing.xxxl),

            // 4. Notifications
            _NotificationBlockingSection(userId: user.uid),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 1. APP LIMITS SECTION
// ============================================================================

class _AppLimitsSection extends ConsumerWidget {
  final String userId;

  const _AppLimitsSection({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLimitsAsync = ref.watch(appLimitsProvider(userId));

    return _BlockSection(
      title: 'App Limits',
      icon: Icons.timer_outlined,
      description: 'Set daily usage limits for specific apps',
      child: appLimitsAsync.when(
        data: (limits) {
          if (limits.isEmpty) {
            return _EmptyState(
              icon: Icons.timer_off_outlined,
              message: 'No app limits set yet',
              actionLabel: 'Add Limit',
              onAction: () => _showAddAppLimitDialog(context),
            );
          }

          return Column(
            children: [
              ...limits.map(
                (limit) => _AppLimitTile(limit: limit, userId: userId),
              ),
              const SizedBox(height: 12),
              _AddButton(
                label: 'Add App Limit',
                onPressed: () => _showAddAppLimitDialog(context),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(message: 'Could not load limits'),
      ),
    );
  }

  void _showAddAppLimitDialog(BuildContext context) async {
    // Check usage stats permission first
    final hasUsagePermission = await _checkAndRequestUsageStatsPermission(
      context,
    );
    if (!hasUsagePermission) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ Usage Access permission is required for app limits',
            ),
            backgroundColor: context.palette.error,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _AppSelectionDialog(),
    );
  }
}

class _AppLimitTile extends ConsumerStatefulWidget {
  final AppLimitModel limit;
  final String userId;

  const _AppLimitTile({required this.limit, required this.userId});

  @override
  ConsumerState<_AppLimitTile> createState() => _AppLimitTileState();
}

class _AppLimitTileState extends ConsumerState<_AppLimitTile> {
  int _currentUsage = 0;

  @override
  void initState() {
    super.initState();
    _loadUsage();
  }

  Future<void> _syncAllLimitsToNative() async {
    try {
      final appLimitsAsync = ref.read(appLimitsProvider(widget.userId));
      await appLimitsAsync.when(
        data: (limits) async {
          final limitsMap = <String, int>{};
          for (final limit in limits) {
            if (limit.isActive) {
              limitsMap[limit.packageName] = limit.dailyLimit;
            }
          }
          final nativeService = AppLimitNativeService();
          await nativeService.updateLimits(limitsMap);
          debugPrint('✅ Synced ${limitsMap.length} limits to native');
        },
        loading: () async {},
        error: (e, _) async {
          debugPrint('Error syncing limits: $e');
        },
      );
    } catch (e) {
      debugPrint('Error in _syncAllLimitsToNative: $e');
    }
  }

  Future<void> _loadUsage() async {
    if (!widget.limit.isActive) return;

    try {
      final nativeService = AppLimitNativeService();
      final usage = await nativeService.getTodayUsage(widget.limit.packageName);
      if (mounted) {
        setState(() => _currentUsage = usage);
      }
    } catch (e) {
      debugPrint('Error loading usage: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppLimitCard(
        appName: widget.limit.appName,
        usedMinutes: _currentUsage,
        limitMinutes: widget.limit.dailyLimit,
        isActive: widget.limit.isActive,
        onToggle: _handleToggle,
        onMenu: () => _showOptionsMenu(context),
        icon: ref.watch(appIconProvider(widget.limit.packageName)).value,
      ),
    );
  }

  Future<void> _handleToggle(bool value) async {
    // If enabling, check permissions first
    if (value) {
      final hasPermission = await _checkAndRequestPermissions(context, ref);
      if (!hasPermission) return;
      if (!mounted) return;
    }

    // If disabling, check parental control
    if (!value) {
      final parentalControlDoc = await FirebaseFirestore.instance
          .collection('parental_controls')
          .doc(widget.userId)
          .get();

      if (parentalControlDoc.exists) {
        final data = parentalControlDoc.data();
        final isEnabled = data?['isEnabled'] as bool? ?? false;

        if (isEnabled) {
          if (!mounted) return;
          final verified = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => VerifyPasswordDialog(
              title: 'Parental Control',
              description: 'Enter PIN to disable app limit',
              onVerify: (password) async {
                final service = ref.read(parentalControlServiceProvider);
                return await service.verifyPassword(
                  userId: widget.userId,
                  password: password,
                );
              },
            ),
          );

          if (verified != true) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Incorrect PIN or cancelled'),
                backgroundColor: context.palette.error,
                duration: Duration(seconds: 2),
              ),
            );
            return;
          }
        }
      }
    }

    try {
      // Update Firebase
      await ref
          .read(appLimitNotifierProvider.notifier)
          .toggleAppLimitStatus(widget.userId, widget.limit.packageName, value);

      // Sync all active limits to native
      await _syncAllLimitsToNative();

      if (value) {
        _loadUsage(); // Reload usage when enabling
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? '✅ ${widget.limit.appName} limit enabled'
                : '🔓 ${widget.limit.appName} limit disabled',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error toggling limit: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update limit'),
          backgroundColor: context.palette.error,
        ),
      );
    }
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.edit,
                color: context.palette.onCanvasSecondary,
              ),
              title: Text(
                'Edit Limit',
                style: TextStyle(color: context.palette.onCanvas),
              ),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: context.palette.error),
              title: Text(
                'Remove Limit',
                style: TextStyle(color: context.palette.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmRemove();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog() {
    final controller = TextEditingController(
      text: widget.limit.dailyLimit.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Edit ${widget.limit.appName}',
          style: TextStyle(color: context.palette.onCanvas),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(color: context.palette.onCanvas),
          decoration: InputDecoration(
            labelText: 'Daily limit (minutes)',
            labelStyle: TextStyle(
              color: context.palette.onCanvas.withValues(alpha: 0.6),
            ),
            filled: true,
            fillColor: context.palette.onCanvas.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.palette.onCanvasMuted),
            ),
          ),
          TextButton(
            onPressed: () async {
              final newLimit = int.tryParse(controller.text);
              if (newLimit != null && newLimit > 0) {
                try {
                  final updatedLimit = widget.limit.copyWith(
                    dailyLimit: newLimit,
                  );

                  // Update Firebase
                  await ref
                      .read(appLimitNotifierProvider.notifier)
                      .updateAppLimit(widget.userId, updatedLimit);

                  // Sync all limits to native
                  await _syncAllLimitsToNative();

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('✅ Limit updated')));
                  }
                } catch (e) {
                  debugPrint('Error updating limit: $e');
                }
              }
            },
            child: Text(
              'Save',
              style: TextStyle(
                color: context.palette.accentText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRemove() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Remove Limit?',
          style: TextStyle(color: context.palette.onCanvas),
        ),
        content: Text(
          'Remove limit for ${widget.limit.appName}?',
          style: TextStyle(color: context.palette.onCanvasSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.palette.onCanvasMuted),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Remove from Firebase
                await ref
                    .read(appLimitNotifierProvider.notifier)
                    .removeAppLimit(widget.userId, widget.limit.packageName);

                // Sync all limits to native (this will remove it)
                await _syncAllLimitsToNative();

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ ${widget.limit.appName} limit removed'),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Error removing limit: $e');
              }
            },
            child: Text(
              'Remove',
              style: TextStyle(
                color: context.palette.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. SHORT FORM BLOCKS SECTION
// ============================================================================

class _ShortFormBlocksSection extends ConsumerWidget {
  final String userId;

  const _ShortFormBlocksSection({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the blockedContentProvider directly and extract shortFormBlocks
    final contentAsync = ref.watch(blockedContentProvider(userId));

    // The installed list is cached for the session (see installedAppsProvider)
    // but leaves out some preinstalled system apps (e.g. a Facebook that ships
    // with the phone), so an app counts as installed if it is in the list OR
    // the launcher icon lookup finds it. While anything is still loading, or if
    // the scan fails, assume installed so rows are never wrongly disabled.
    final installedApps = ref.watch(installedAppsProvider).value;
    final installedPackages = installedApps == null
        ? null
        : {for (final app in installedApps) app.packageName};
    bool isInstalled(List<String> packages) {
      if (installedPackages == null) return true;
      return packages.any((package) {
        if (installedPackages.contains(package)) return true;
        final icon = ref.watch(appIconProvider(package));
        return icon.isLoading || icon.value != null;
      });
    }

    return _BlockSection(
      title: 'Short Form Content',
      icon: Icons.video_library_outlined,
      description: 'Block addictive short-form feeds',
      child: contentAsync.when(
        data: (content) {
          // Extract blocks directly from the content model
          final blocks = content.shortFormBlocks;

          // Log what we got from Firestore
          debugPrint(
            '📱 ShortFormBlocksSection: Retrieved from Firestore - ${blocks.keys.toList()}',
          );
          blocks.forEach((key, block) {
            debugPrint('   - $key: isBlocked=${block.isBlocked}');
          });

          return Column(
            children: [
              _ShortFormToggle(
                title: 'YouTube Shorts',
                subtitle: 'Block Shorts shelf & feed',
                icon: Icons.play_circle_outline,
                packages: const ['com.google.android.youtube'],
                installed: isInstalled(const ['com.google.android.youtube']),
                isBlocked: blocks['YouTube_Shorts']?.isBlocked ?? false,
                onChanged: (value) => _updateBlock(
                  context,
                  ref,
                  userId,
                  'YouTube',
                  'Shorts',
                  value,
                ),
              ),
              _ShortFormToggle(
                title: 'Instagram Reels',
                subtitle: 'Block Reels tab & feed',
                icon: Icons.camera_alt_outlined,
                packages: const ['com.instagram.android'],
                installed: isInstalled(const ['com.instagram.android']),
                isBlocked: blocks['Instagram_Reels']?.isBlocked ?? false,
                onChanged: (value) => _updateBlock(
                  context,
                  ref,
                  userId,
                  'Instagram',
                  'Reels',
                  value,
                ),
              ),
              _ShortFormToggle(
                title: 'TikTok',
                subtitle: 'Block app entirely',
                icon: Icons.music_note_outlined,
                packages: const [
                  'com.zhiliaoapp.musically',
                  'com.ss.android.ugc.trill',
                ],
                installed: isInstalled(const [
                  'com.zhiliaoapp.musically',
                  'com.ss.android.ugc.trill',
                ]),
                isBlocked: blocks['TikTok_Videos']?.isBlocked ?? false,
                onChanged: (value) => _updateBlock(
                  context,
                  ref,
                  userId,
                  'TikTok',
                  'Videos',
                  value,
                ),
              ),
              _ShortFormToggle(
                title: 'Facebook Reels',
                subtitle: 'Block Reels section',
                icon: Icons.facebook_outlined,
                packages: const ['com.facebook.katana', 'com.facebook.lite'],
                installed: isInstalled(const [
                  'com.facebook.katana',
                  'com.facebook.lite',
                ]),
                isBlocked: blocks['Facebook_Reels']?.isBlocked ?? false,
                onChanged: (value) => _updateBlock(
                  context,
                  ref,
                  userId,
                  'Facebook',
                  'Reels',
                  value,
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) =>
            _ErrorState(message: 'Could not load settings: $e'),
      ),
    );
  }

  Future<void> _updateBlock(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String platform,
    String feature,
    bool isBlocked,
  ) async {
    // If enabling, check permissions first
    if (isBlocked) {
      final hasPermissions = await _checkAndRequestPermissions(context, ref);
      if (!hasPermissions) {
        // Don't update if permissions not granted
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ Accessibility permission required to block content',
              ),
              backgroundColor: context.palette.warning,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    }

    // If disabling, check parental control
    if (!isBlocked) {
      debugPrint(
        '🔐 Checking parental control for disabling $platform $feature',
      );

      // Directly check Firestore for parental control
      final parentalControlDoc = await FirebaseFirestore.instance
          .collection('parental_controls')
          .doc(userId)
          .get();

      if (parentalControlDoc.exists) {
        final data = parentalControlDoc.data();
        final isEnabled = data?['isEnabled'] as bool? ?? false;
        debugPrint('🔐 Parental control found: isEnabled=$isEnabled');

        if (isEnabled) {
          debugPrint('🔐 Showing PIN dialog');
          if (!context.mounted) return;
          // Show PIN verification dialog
          final verified = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => VerifyPasswordDialog(
              title: 'Parental Control',
              description: 'Enter PIN to disable $platform $feature blocking',
              onVerify: (password) async {
                final service = ref.read(parentalControlServiceProvider);
                return await service.verifyPassword(
                  userId: userId,
                  password: password,
                );
              },
            ),
          );

          debugPrint('🔐 PIN verification result: $verified');
          if (verified != true) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Incorrect PIN or cancelled'),
                backgroundColor: context.palette.error,
                duration: Duration(seconds: 2),
              ),
            );
            return;
          }
        } else {
          debugPrint('🔐 Parental control is not enabled, allowing operation');
        }
      } else {
        debugPrint('🔐 No parental control document found, allowing operation');
      }
    }

    try {
      debugPrint('🔄 Updating $platform $feature to $isBlocked');

      // Update native service first
      final nativeService = ref.read(blocksNativeServiceProvider);
      await nativeService.setShortFormBlock(
        platform: platform,
        feature: feature,
        isBlocked: isBlocked,
      );
      debugPrint('✅ Native service updated for $platform $feature');

      // Then call the notifier method to update Firestore
      await ref
          .read(blockedContentNotifierProvider.notifier)
          .toggleShortFormBlockStatus(userId, platform, feature, isBlocked);

      debugPrint(
        '✅ Successfully updated $platform $feature to $isBlocked in Firestore',
      );

      // Show feedback to user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isBlocked
                  ? '🚫 $platform $feature blocked'
                  : '✅ $platform $feature unblocked',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error updating short form block: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update $platform $feature'),
            backgroundColor: context.palette.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class _ShortFormToggle extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isBlocked;
  final ValueChanged<bool> onChanged;

  /// Android packages of the platform, used to show its real launcher icon.
  final List<String> packages;

  /// False when none of [packages] is installed: the row is dimmed and can't
  /// be switched on. A block that was already saved as on can still be switched
  /// off, so an uninstalled app never leaves a stuck toggle.
  final bool installed;

  const _ShortFormToggle({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.packages,
    this.installed = true,
    required this.isBlocked,
    required this.onChanged,
  });

  @override
  State<_ShortFormToggle> createState() => _ShortFormToggleState();
}

class _ShortFormToggleState extends State<_ShortFormToggle> {
  bool? _optimisticValue;
  bool _isUpdating = false;

  @override
  void didUpdateWidget(_ShortFormToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear optimistic value when Firestore confirms the change
    if (oldWidget.isBlocked != widget.isBlocked) {
      debugPrint(
        '🔄 Toggle ${widget.title}: Firestore updated from ${oldWidget.isBlocked} to ${widget.isBlocked}, optimistic was $_optimisticValue',
      );
      if (_optimisticValue != null && _optimisticValue == widget.isBlocked) {
        debugPrint(
          '✅ Toggle ${widget.title}: Clearing optimistic value (confirmed by Firestore)',
        );
        setState(() => _optimisticValue = null);
      } else if (_optimisticValue != null &&
          _optimisticValue != widget.isBlocked) {
        debugPrint(
          '⚠️ Toggle ${widget.title}: Firestore value conflicts with optimistic value',
        );
        // Firestore value is different from what we expected, trust Firestore
        setState(() => _optimisticValue = null);
      }
    }
  }

  void _revertOptimisticValue() {
    if (mounted) {
      setState(() {
        _optimisticValue = null;
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use optimistic value if available, otherwise use actual value
    final displayValue = _optimisticValue ?? widget.isBlocked;
    debugPrint(
      '🎨 Toggle ${widget.title}: Rendering with displayValue=$displayValue (optimistic=$_optimisticValue, firestore=${widget.isBlocked})',
    );

    // Not installed: nothing to block, so don't let it be switched on.
    final canToggle = widget.installed || displayValue;

    return _SurfaceRow(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: _PlatformIcon(
          name: widget.title,
          packages: widget.packages,
          fallback: _RuleIcon(icon: widget.icon, active: displayValue),
          dimmed: !displayValue,
        ),
        title: Text(
          widget.title,
          style: TextStyle(
            color: canToggle
                ? context.palette.onCanvas
                : context.palette.onCanvasMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          widget.installed ? widget.subtitle : 'App not installed',
          style: TextStyle(
            color: context.palette.onCanvas.withValues(alpha: 0.5),
          ),
        ),
        value: displayValue,
        onChanged: (_isUpdating || !canToggle)
            ? null
            : (value) {
                if (_isUpdating) return;

                // Set optimistic value immediately for instant UI feedback
                setState(() {
                  _optimisticValue = value;
                  _isUpdating = true;
                });

                // Call the actual update
                widget.onChanged(value);

                // Set a timeout to revert optimistic value if Firestore doesn't confirm
                Future.delayed(const Duration(seconds: 3)).then((_) {
                  if (mounted && _optimisticValue != null) {
                    // If optimistic value is still set after 3 seconds,
                    // it means the update failed (e.g., PIN was wrong)
                    if (widget.isBlocked != _optimisticValue) {
                      debugPrint(
                        '⚠️ Toggle ${widget.title}: Reverting optimistic value (update not confirmed)',
                      );
                      _revertOptimisticValue();
                    }
                  }
                });

                // Reset updating flag after shorter delay
                Future.delayed(const Duration(milliseconds: 800)).then((_) {
                  if (mounted) {
                    setState(() => _isUpdating = false);
                  }
                });
              },
      ),
    );
  }
}

// ============================================================================
// 3. WEBSITE BLOCKING SECTION
// ============================================================================

class _WebsiteBlockingSection extends ConsumerWidget {
  final String userId;

  const _WebsiteBlockingSection({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final websitesAsync = ref.watch(blockedWebsitesProvider(userId));

    return _BlockSection(
      title: 'Website Blocking',
      icon: Icons.language,
      description: 'Block distracting websites in browsers',
      child: websitesAsync.when(
        data: (websites) {
          if (websites.isEmpty) {
            return _EmptyState(
              icon: Icons.public_off,
              message: 'No websites blocked',
              actionLabel: 'Add Website',
              onAction: () => _showAddWebsiteDialog(context, ref),
            );
          }

          return Column(
            children: [
              ...websites.map(
                (website) => _WebsiteTile(website: website, userId: userId),
              ),
              const SizedBox(height: 12),
              _AddButton(
                label: 'Add Website',
                onPressed: () => _showAddWebsiteDialog(context, ref),
              ),
              const SizedBox(height: 8),
              _DiagnosticsButton(
                onPressed: () => _runWebsiteBlockingDiagnostics(context, ref),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(message: 'Could not load websites'),
      ),
    );
  }

  void _showAddWebsiteDialog(BuildContext context, WidgetRef ref) {
    final urlController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Block Website',
          style: TextStyle(color: context.palette.onCanvas),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: context.palette.onCanvas),
              decoration: InputDecoration(
                labelText: 'Website Name',
                hintText: 'e.g. Facebook',
                labelStyle: TextStyle(
                  color: context.palette.onCanvas.withValues(alpha: 0.6),
                ),
                hintStyle: TextStyle(
                  color: context.palette.onCanvas.withValues(alpha: 0.3),
                ),
                filled: true,
                fillColor: context.palette.onCanvas.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              style: TextStyle(color: context.palette.onCanvas),
              decoration: InputDecoration(
                labelText: 'Website URL',
                hintText: 'e.g. facebook.com',
                labelStyle: TextStyle(
                  color: context.palette.onCanvas.withValues(alpha: 0.6),
                ),
                hintStyle: TextStyle(
                  color: context.palette.onCanvas.withValues(alpha: 0.3),
                ),
                filled: true,
                fillColor: context.palette.onCanvas.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.palette.onCanvasMuted),
            ),
          ),
          TextButton(
            onPressed: () async {
              // Native and Firestore both store the bare host.
              final url = normalizeBlockedHost(urlController.text);
              final name = nameController.text.trim();
              if (url.isNotEmpty && name.isNotEmpty) {
                // Check permissions first
                final hasPermission = await _checkAndRequestPermissions(
                  context,
                  ref,
                );
                if (!context.mounted) return;
                if (!hasPermission) {
                  Navigator.pop(context);
                  return;
                }

                final nativeService = ref.read(blocksNativeServiceProvider);
                final website = BlockedWebsite(
                  url: url,
                  name: name,
                  isActive: true,
                );

                try {
                  // Add to native service first
                  await nativeService.addBlockedWebsite(
                    url: url,
                    name: name,
                    isActive: true,
                  );

                  // Then add to Firebase
                  await ref
                      .read(blockedContentNotifierProvider.notifier)
                      .addBlockedWebsite(userId, website);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('✅ $name blocked')));
                  }
                } catch (e) {
                  debugPrint('❌ Error adding blocked website: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to block website'),
                        backgroundColor: context.palette.error,
                      ),
                    );
                  }
                }
              }
            },
            child: Text(
              'Block',
              style: TextStyle(
                color: context.palette.accentText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WebsiteTile extends ConsumerWidget {
  final BlockedWebsite website;
  final String userId;

  const _WebsiteTile({required this.website, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SurfaceRow(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _RuleIcon(
          icon: Icons.public_off_rounded,
          active: website.isActive,
        ),
        title: Text(
          website.url,
          style: TextStyle(color: context.palette.onCanvas),
        ),
        subtitle: Text(
          website.name,
          style: TextStyle(
            color: context.palette.onCanvas.withValues(alpha: 0.5),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: website.isActive,
                onChanged: (value) async {
                  // If enabling, check permissions first
                  if (value) {
                    final hasPermission = await _checkAndRequestPermissions(
                      context,
                      ref,
                    );
                    if (!hasPermission) {
                      return;
                    }
                    if (!context.mounted) return;
                  }

                  // If disabling, check parental control
                  if (!value) {
                    // Directly check Firestore for parental control
                    final parentalControlDoc = await FirebaseFirestore.instance
                        .collection('parental_controls')
                        .doc(userId)
                        .get();

                    if (parentalControlDoc.exists) {
                      final data = parentalControlDoc.data();
                      final isEnabled = data?['isEnabled'] as bool? ?? false;

                      if (isEnabled) {
                        if (!context.mounted) return;
                        final verified = await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => VerifyPasswordDialog(
                            title: 'Parental Control',
                            description: 'Enter PIN to disable website block',
                            onVerify: (password) async {
                              final service = ref.read(
                                parentalControlServiceProvider,
                              );
                              return await service.verifyPassword(
                                userId: userId,
                                password: password,
                              );
                            },
                          ),
                        );

                        if (verified != true) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('❌ Incorrect PIN or cancelled'),
                                backgroundColor: context.palette.error,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                          return;
                        }
                      }
                    }
                  }

                  final nativeService = ref.read(blocksNativeServiceProvider);

                  try {
                    // Update native service
                    await nativeService.addBlockedWebsite(
                      url: website.url,
                      name: website.name,
                      isActive: value,
                    );

                    // Update Firebase
                    await ref
                        .read(blockedContentNotifierProvider.notifier)
                        .toggleWebsiteBlockStatus(userId, website.url, value);
                  } catch (e) {
                    debugPrint('❌ Error toggling website: $e');
                  }
                },
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: context.palette.onCanvas.withValues(alpha: 0.4),
              ),
              onPressed: () async {
                final nativeService = ref.read(blocksNativeServiceProvider);

                try {
                  // Remove from native service
                  await nativeService.removeBlockedWebsite(website.url);

                  // Remove from Firebase
                  await ref
                      .read(blockedContentNotifierProvider.notifier)
                      .removeBlockedWebsite(userId, website.url);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ ${website.name} unblocked')),
                    );
                  }
                } catch (e) {
                  debugPrint('❌ Error removing website: $e');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 4. NOTIFICATION BLOCKING SECTION
// ============================================================================

class _NotificationBlockingSection extends ConsumerStatefulWidget {
  final String userId;

  const _NotificationBlockingSection({required this.userId});

  @override
  ConsumerState<_NotificationBlockingSection> createState() =>
      _NotificationBlockingSectionState();
}

class _NotificationBlockingSectionState
    extends ConsumerState<_NotificationBlockingSection> {
  // TODO: Move this state to a provider for persistence
  bool _blockAllNotifications = false;

  @override
  Widget build(BuildContext context) {
    return _BlockSection(
      title: 'Notifications',
      icon: Icons.notifications_off_outlined,
      description: 'Control notification access globally',
      child: Column(
        children: [
          _SurfaceRow(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              secondary: _RuleIcon(
                icon: Icons.notifications_off_rounded,
                active: _blockAllNotifications,
              ),
              title: Text(
                'Block All Notifications',
                style: TextStyle(color: context.palette.onCanvas),
              ),
              subtitle: Text(
                'Silence all app notifications',
                style: TextStyle(
                  color: context.palette.onCanvas.withValues(alpha: 0.5),
                ),
              ),
              value: _blockAllNotifications,
              onChanged: (value) {
                setState(() => _blockAllNotifications = value);
                // TODO: Save to backend via provider
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SHARED WIDGETS
// ============================================================================

/// Rounded `surface` background for a ListTile / SwitchListTile row.
///
/// A [Material] (not a decorated Container): ListTile paints its background
/// and ink splashes on the nearest Material, so a colored DecoratedBox above it
/// would hide them (and trips a framework assertion).
class _SurfaceRow extends StatelessWidget {
  const _SurfaceRow({required this.child, this.margin = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class _BlockSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final Widget child;
  const _BlockSection({
    required this.title,
    required this.icon,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.palette.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: context.palette.accentText, size: 20),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.headlineSmall),
                  Text(description, style: textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        child,
      ],
    );
  }
}

// Diagnostics button widget
class _DiagnosticsButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _DiagnosticsButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return AppPillButton(
      label: 'Run diagnostics',
      icon: Icons.bug_report_outlined,
      variant: PillButtonVariant.outline,
      onPressed: onPressed,
    );
  }
}

// Website blocking diagnostics method
Future<void> _runWebsiteBlockingDiagnostics(
  BuildContext context,
  WidgetRef ref,
) async {
  try {
    final nativeService = ref.read(blocksNativeServiceProvider);

    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Running diagnostics...'),
        duration: Duration(seconds: 1),
      ),
    );

    // Get diagnostics
    final diagnostics = await nativeService.getWebsiteBlockingDiagnostics();
    final supportedBrowsers = await nativeService.getSupportedBrowsers();

    final result = StringBuffer();
    result.writeln('🔍 Website Blocking Diagnostics\n');

    // Service status
    final accessibilityEnabled =
        diagnostics['accessibilityServiceEnabled'] as bool? ?? false;
    // Native does not report this today, so only show the line when it does.
    final serviceRunning = diagnostics['serviceRunning'] as bool?;

    if (!accessibilityEnabled) {
      result.writeln('⚠️ Accessibility Service: DISABLED');
      result.writeln('   Website blocking requires accessibility service');
      result.writeln('');
      result.writeln('📋 Enable Steps:');
      result.writeln('1. Go to Android Settings');
      result.writeln('2. Accessibility > $kAppName');
      result.writeln('3. Toggle ON');
      result.writeln('');
    } else {
      result.writeln('✅ Accessibility Service: ENABLED');
      if (serviceRunning != null) {
        result.writeln('✅ Service Running: ${serviceRunning ? "YES" : "NO"}');
      }
    }

    // Active blocked websites. Native sends `activeBlockedWebsites` as a COUNT
    // (an int) and the websites themselves in `blockedWebsites` (maps), so read
    // them as that - casting the count to a List threw "int is not a subtype of
    // List".
    final activeWebsites = [
      for (final site in diagnostics['blockedWebsites'] as List? ?? const [])
        if (site is Map && site['isActive'] == true) site,
    ];
    final activeCount =
        (diagnostics['activeBlockedWebsites'] as num?)?.toInt() ??
        activeWebsites.length;
    result.writeln('');
    result.writeln('🚫 Active Blocked Websites: $activeCount');
    if (activeWebsites.isNotEmpty) {
      for (final website in activeWebsites) {
        result.writeln('   • ${website['name'] ?? website['url']}');
      }
    } else if (activeCount == 0) {
      result.writeln('   No websites currently blocked');
    }

    // Supported browsers
    result.writeln('');
    result.writeln('🌐 Installed Supported Browsers:');
    if (supportedBrowsers.isNotEmpty) {
      for (var browser in supportedBrowsers) {
        result.writeln('   ✓ $browser');
      }
    } else {
      result.writeln('   No supported browsers found');
    }

    // Testing instructions
    result.writeln('');
    result.writeln('🧪 Testing Instructions:');
    result.writeln('');
    result.writeln('1. Add a website to block (e.g., "facebook.com")');
    result.writeln('2. Open any supported browser');
    result.writeln('3. Navigate to the blocked website');
    result.writeln('4. You should see:');
    result.writeln('   • Blocking overlay appears');
    result.writeln('   • Browser navigates back automatically');
    result.writeln('');

    if (!accessibilityEnabled) {
      result.writeln('⚠️ Next Steps:');
      result.writeln('1. Enable Accessibility Service (see above)');
      result.writeln('2. Add websites to block');
      result.writeln('3. Test in any supported browser');
    } else if (activeCount == 0) {
      result.writeln('💡 Next Steps:');
      result.writeln('1. Add websites to block above');
      result.writeln('2. Open a browser');
      result.writeln('3. Blocking should activate automatically');
    } else {
      result.writeln('✅ Ready to Test:');
      result.writeln('1. Open any supported browser');
      result.writeln('2. Try visiting a blocked website');
      result.writeln('3. Blocking should work automatically');
    }

    // Show results
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: context.palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Diagnostics Report',
            style: TextStyle(color: context.palette.onCanvas),
          ),
          content: SingleChildScrollView(
            child: Text(
              result.toString(),
              style: TextStyle(
                color: context.palette.onCanvas,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: TextStyle(color: context.palette.accentText),
              ),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    debugPrint('❌ Diagnostics error: $e');
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: context.palette.surface,
          title: Text(
            'Error',
            style: TextStyle(color: context.palette.onCanvas),
          ),
          content: Text(
            'Failed to run diagnostics: $e',
            style: TextStyle(color: context.palette.onCanvasSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: TextStyle(color: context.palette.accentText),
              ),
            ),
          ],
        ),
      );
    }
  }
}

/// The real launcher icon of the first installed app in [packages]; [fallback]
/// while loading or when none is installed.
class _PlatformIcon extends ConsumerWidget {
  const _PlatformIcon({
    required this.name,
    required this.packages,
    required this.fallback,
    this.dimmed = false,
  });

  final String name;
  final List<String> packages;
  final Widget fallback;
  final bool dimmed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    for (final package in packages) {
      final icon = ref.watch(appIconProvider(package)).value;
      if (icon != null && icon.isNotEmpty) {
        return AppIconBadge(name: name, icon: icon, size: 40, dimmed: dimmed);
      }
    }
    return fallback;
  }
}

/// Round icon badge leading a rule row; accent when the rule is on.
class _RuleIcon extends StatelessWidget {
  const _RuleIcon({required this.icon, required this.active});

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: active ? palette.accentSoft : palette.surfaceTrack,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 20,
        color: active ? palette.accentText : palette.onCanvasMuted,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: context.palette.onCanvasDisabled),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          _AddButton(label: actionLabel, onPressed: onAction),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: context.palette.error),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.palette.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _AddButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return AppPillButton(
      label: label,
      icon: Icons.add_rounded,
      variant: PillButtonVariant.outline,
      onPressed: onPressed,
    );
  }
}

// ============================================================================
// APP SELECTION DIALOG
// ============================================================================

class _AppSelectionDialog extends ConsumerStatefulWidget {
  const _AppSelectionDialog();

  @override
  ConsumerState<_AppSelectionDialog> createState() =>
      _AppSelectionDialogState();
}

class _AppSelectionDialogState extends ConsumerState<_AppSelectionDialog> {
  String _query = '';
  final _searchController = TextEditingController();

  Future<void> _syncAllLimitsToNative(String userId) async {
    try {
      final appLimitsAsync = ref.read(appLimitsProvider(userId));
      await appLimitsAsync.when(
        data: (limits) async {
          final limitsMap = <String, int>{};
          for (final limit in limits) {
            if (limit.isActive) {
              limitsMap[limit.packageName] = limit.dailyLimit;
            }
          }
          final nativeService = AppLimitNativeService();
          await nativeService.updateLimits(limitsMap);
          debugPrint('✅ Synced ${limitsMap.length} limits to native');
        },
        loading: () async {},
        error: (e, _) async {
          debugPrint('Error syncing limits: $e');
        },
      );
    } catch (e) {
      debugPrint('Error in _syncAllLimitsToNative: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterApps(String query) => setState(() => _query = query);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    // The app list is cached for the session in pickerAppsProvider, so
    // reopening the picker is instant instead of rescanning every time.
    final appsAsync = ref.watch(pickerAppsProvider);
    final isLoading = appsAsync.isLoading && !appsAsync.hasValue;
    final allApps = appsAsync.value ?? const <AppInfo>[];
    final q = _query.toLowerCase();
    final filteredApps = q.isEmpty
        ? allApps
        : allApps
              .where(
                (app) =>
                    app.name.toLowerCase().contains(q) ||
                    app.packageName.toLowerCase().contains(q),
              )
              .toList();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Choose an app', style: textTheme.titleLarge),
                ),
                IconCircleButton(
                  icon: Icons.close_rounded,
                  semanticLabel: 'Close',
                  size: 40,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _searchController,
              onChanged: _filterApps,
              textInputAction: TextInputAction.search,
              style: textTheme.bodyLarge?.copyWith(color: palette.onCanvas),
              decoration: InputDecoration(
                hintText: 'Search apps',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: palette.onCanvasMuted,
                ),
                filled: true,
                fillColor: palette.surface,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredApps.isEmpty
                  ? Center(
                      child: Text('No apps found', style: textTheme.bodyMedium),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                      itemCount: filteredApps.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final app = filteredApps[index];
                        return _AppListItem(
                          app: app,
                          onTap: () => _showLimitDialog(app),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLimitDialog(AppInfo app) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => LimitSetupSheet(
        appName: app.name,
        appIcon: AppIconBadge(name: app.name, icon: app.icon, size: 44),
        onSubmit: (minutes, action) async {
          await _addAppLimit(app, minutes, action);
          if (sheetContext.mounted) {
            Navigator.pop(sheetContext); // close the limit sheet
          }
          if (mounted) {
            Navigator.pop(context); // close the app picker
          }
        },
      ),
    );
  }

  Future<void> _addAppLimit(
    AppInfo app,
    int limitMinutes,
    String action,
  ) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    // Check permissions first
    final hasPermission = await _checkAndRequestPermissions(context, ref);
    if (!hasPermission) return;

    try {
      final limit = AppLimitModel(
        packageName: app.packageName,
        appName: app.name,
        dailyLimit: limitMinutes,
        weeklyLimit: 0,
        isActive: true,
        actionOnExceed: action,
      );

      // Add to Firebase
      await ref
          .read(appLimitNotifierProvider.notifier)
          .addAppLimit(user.uid, limit);

      // Sync all limits to native
      await _syncAllLimitsToNative(user.uid);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('✅ Limit added for ${app.name}')));
    } catch (e) {
      debugPrint('Error adding limit: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add limit'),
          backgroundColor: context.palette.error,
        ),
      );
    }
  }
}

class _AppListItem extends StatelessWidget {
  final AppInfo app;
  final VoidCallback onTap;

  const _AppListItem({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              AppIconBadge(name: app.name, icon: app.icon, size: 40),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  app.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.onCanvasMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// APP LIMIT EXCEEDED OVERLAY
// ============================================================================

class AppLimitExceededOverlay extends StatelessWidget {
  final String appName;
  final int usedMinutes;
  final int limitMinutes;
  final bool canDismiss;

  const AppLimitExceededOverlay({
    super.key,
    required this.appName,
    required this.usedMinutes,
    required this.limitMinutes,
    this.canDismiss = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.onAccent,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.palette.error.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.block,
                    size: 80,
                    color: context.palette.error,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Time Limit Reached',
                  style: TextStyle(
                    color: context.palette.onCanvas,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'You\'ve used $usedMinutes minutes of $appName today.',
                  style: TextStyle(
                    color: context.palette.onCanvas.withValues(alpha: 0.7),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Daily limit: $limitMinutes minutes',
                  style: TextStyle(
                    color: context.palette.onCanvas.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 48),
                if (canDismiss)
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.palette.accent,
                      foregroundColor: context.palette.onAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'I Understand',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      Icon(Icons.lock, color: context.palette.error, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'This app is blocked for today',
                        style: TextStyle(
                          color: context.palette.onCanvas.withValues(
                            alpha: 0.5,
                          ),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
