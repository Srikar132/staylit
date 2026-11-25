import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/data/models/installed_app_model.dart';
import 'package:staylit/presentation/providers/app_management_provide.dart';
import 'package:staylit/core/theme/theme_context.dart';

class AllowedAppsDrawer extends ConsumerWidget {
  final String userId;

  const AllowedAppsDrawer({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowedAppsAsync = ref.watch(allowedAppsProvider(userId));
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.palette.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Icon(
                  Icons.apps_rounded,
                  size: 28,
                  color: context.palette.accentText,
                ),
                const SizedBox(width: 12),
                Text('Allowed Apps', style: theme.textTheme.headlineMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    foregroundColor: context.palette.onCanvasSecondary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          // Apps Grid
          Expanded(
            child: allowedAppsAsync.when(
              data: (apps) {
                if (apps.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: context.palette.surfaceRaised,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.block_rounded,
                            size: 48,
                            color: context.palette.onCanvasMuted,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'All apps are blocked',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: context.palette.onCanvasSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No apps available during focus session',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: context.palette.onCanvasMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: apps.length,
                  itemBuilder: (context, index) {
                    final app = apps[index];
                    return _AppIconTile(app: app);
                  },
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(color: context.palette.accent),
              ),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: context.palette.surfaceRaised,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: context.palette.error,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Error loading apps',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: context.palette.onCanvasSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        error.toString(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.palette.onCanvasMuted,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppIconTile extends ConsumerWidget {
  final InstalledApp app;

  const _AppIconTile({required this.app});

  Future<void> _launchApp(BuildContext context, WidgetRef ref) async {
    if (!app.canLaunch) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot launch ${app.appName}'),
          backgroundColor: context.palette.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    try {
      // TODO: Replace with your actual app launch logic
      // For example, using a method channel or package like android_intent
      // await AndroidIntent(
      //   action: 'android.intent.action.MAIN',
      //   package: app.packageName,
      // ).launch();

      // For now, showing a placeholder message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening ${app.appName}...'),
            backgroundColor: context.palette.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to launch ${app.appName}'),
            backgroundColor: context.palette.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconAsync = ref.watch(appIconProvider(app.packageName));
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _launchApp(context, ref),
      borderRadius: BorderRadius.circular(16),
      splashColor: context.palette.accent.withValues(alpha: 0.1),
      highlightColor: context.palette.accent.withValues(alpha: 0.05),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // App Icon Container
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: context.palette.surfaceRaised,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.palette.border, width: 1),
            ),
            child: iconAsync.when(
              data: (iconBytes) {
                if (iconBytes != null && iconBytes.isNotEmpty) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(
                      iconBytes,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultIcon(context);
                      },
                    ),
                  );
                }
                return _buildDefaultIcon(context);
              },
              loading: () => Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.palette.accent.withValues(alpha: 0.5),
                  ),
                ),
              ),
              error: (error, stack) => _buildDefaultIcon(context),
            ),
          ),
          const SizedBox(height: 8),
          // App Name
          Text(
            app.appName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.palette.onCanvasSecondary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultIcon(BuildContext context) {
    return Center(
      child: Icon(
        Icons.android_rounded,
        size: 32,
        color: context.palette.onCanvasMuted,
      ),
    );
  }
}
