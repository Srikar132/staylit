import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/providers/theme_mode_provider.dart';

/// Opens the System / Light / Dark chooser.
Future<void> showAppearanceSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const AppearanceSheet(),
  );
}

/// Profile row that shows the current mode and opens [AppearanceSheet].
class AppearanceTile extends ConsumerWidget {
  const AppearanceTile({super.key});

  static String labelFor(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: 'Appearance, ${labelFor(mode)}',
      excludeSemantics: true,
      child: ListTile(
        onTap: () => showAppearanceSheet(context),
        leading: Icon(Icons.brightness_6_outlined, color: palette.accentText),
        title: Text('Appearance', style: textTheme.titleMedium),
        subtitle: Text(labelFor(mode), style: textTheme.bodySmall),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: palette.onCanvasMuted,
        ),
      ),
    );
  }
}

/// Bottom sheet content for choosing the theme mode. Applies immediately.
class AppearanceSheet extends ConsumerWidget {
  const AppearanceSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Appearance', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('System'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Dark'),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (selection) => ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(selection.single),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              "System follows your phone's light or dark setting.",
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
