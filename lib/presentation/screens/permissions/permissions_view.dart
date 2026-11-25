import 'package:flutter/material.dart';
import 'package:staylit/core/constants/app_info.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';
import 'package:staylit/presentation/widgets/design/permission_card.dart';
import 'package:staylit/presentation/widgets/design/step_progress_bar.dart';

/// One permission row on the setup screen.
@immutable
class PermissionItem {
  const PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
    required this.onAllow,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool granted;
  final Future<void> Function() onAllow;
}

/// The permission setup screen. Pure presentation: requests and the final
/// "complete" check are callbacks owned by the screen.
class PermissionsView extends StatelessWidget {
  const PermissionsView({
    super.key,
    required this.items,
    required this.onComplete,
    required this.onWhy,
  });

  final List<PermissionItem> items;
  final VoidCallback onComplete;
  final VoidCallback onWhy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final granted = items.where((i) => i.granted).length;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              children: [
                Text('Set up $kAppName', style: textTheme.displaySmall),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Allow these so $kAppName can block distractions and keep '
                  'you focused.',
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Text(
                      '$granted of ${items.length} allowed',
                      style: textTheme.titleMedium?.copyWith(
                        color: palette.accentText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                StepProgressBar(
                  currentStep: granted == 0 ? 0 : granted - 1,
                  stepCount: items.isEmpty ? 1 : items.length,
                  filledCount: granted,
                ),
                const SizedBox(height: AppSpacing.xl),
                for (final item in items) ...[
                  PermissionCard(
                    icon: item.icon,
                    title: item.title,
                    description: item.description,
                    granted: item.granted,
                    onAllow: item.onAllow,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextButton.icon(
                  onPressed: onWhy,
                  icon: const Icon(Icons.help_outline_rounded, size: 20),
                  label: const Text('Why do you need these?'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: AppPillButton(
              label: 'Complete setup',
              onPressed: onComplete,
            ),
          ),
        ],
      ),
    );
  }
}
