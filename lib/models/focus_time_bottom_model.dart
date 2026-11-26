import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/data/models/installed_app_model.dart';
import 'package:staylit/data/models/user_settings_model.dart';
import 'package:staylit/models/block_app_bottom_model.dart';
import 'package:staylit/models/model_manager.dart';
import 'package:staylit/presentation/providers/app_management_provide.dart';
import 'package:staylit/presentation/providers/blocked_content_provider.dart';
import 'package:staylit/widgets/bottom_sheet_darg_handler.dart';
import 'package:staylit/presentation/providers/auth_provider.dart';
import 'package:staylit/presentation/providers/settings_provider.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';
import 'package:staylit/presentation/widgets/design/icon_circle_button.dart';

// ============================================================================
// OPTIMIZED: Extracted BlockedAppsSection to prevent unnecessary rebuilds
// ============================================================================
class _BlockedAppsSection extends ConsumerWidget {
  const _BlockedAppsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final blockedAppsAsync = user != null
        ? ref.watch(permanentlyBlockedAppsProvider(user.uid))
        : const AsyncValue<List<String>>.data([]);

    final blockedSet = blockedAppsAsync.maybeWhen(
      data: (apps) => Set<String>.from(apps),
      orElse: () => <String>{},
    );

    return GestureDetector(
      onTap: () async {
        // FIXED: Dismiss keyboard before opening new sheet
        FocusScope.of(context).unfocus();

        await BottomSheetManager.show(
          context: context,
          child: const BlockAppsSheet(),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            Text(
              'Blocked apps',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            _BlockedAppsPreview(blockedSet: blockedSet),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.chevron_right_rounded,
              color: context.palette.onCanvasMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// OPTIMIZED: Separate widget for blocked apps preview
// ============================================================================
class _BlockedAppsPreview extends ConsumerWidget {
  final Set<String> blockedSet;

  const _BlockedAppsPreview({required this.blockedSet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAppsAsync = ref.watch(installedAppsProvider);

    return allAppsAsync.when(
      data: (allApps) {
        final blockedAppsList = allApps
            .where((app) => blockedSet.contains(app.packageName))
            .take(3)
            .toList();

        if (blockedAppsList.isEmpty) {
          return Text('None', style: Theme.of(context).textTheme.bodyMedium);
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(child: _AppIconStack(apps: blockedAppsList)),
            const SizedBox(width: 12),
            Text(
              '${blockedSet.length} app${blockedSet.length != 1 ? 's' : ''}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, _) => const SizedBox(),
    );
  }
}

// ============================================================================
// OPTIMIZED: Separate widget for icon stack with RepaintBoundary
// ============================================================================
class _AppIconStack extends StatelessWidget {
  final List<InstalledApp> apps;
  static const double iconSize = 24.0;
  static const double overlap = 14.0;

  const _AppIconStack({required this.apps});

  @override
  Widget build(BuildContext context) {
    final displayApps = apps.take(3).toList();

    return SizedBox(
      height: iconSize,
      width: iconSize + ((displayApps.length - 1) * overlap),
      child: Stack(
        children: List.generate(displayApps.length, (index) {
          final app = displayApps[index];
          return Positioned(
            left: index * overlap,
            child: RepaintBoundary(
              child: _AppIconCircle(
                packageName: app.packageName,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ============================================================================
// OPTIMIZED: Individual icon widget with caching
// ============================================================================
class _AppIconCircle extends ConsumerWidget {
  final String packageName;
  final Color backgroundColor;
  static const double iconSize = 24.0;

  const _AppIconCircle({
    required this.packageName,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconAsync = ref.watch(appIconProvider(packageName));

    return Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: backgroundColor, width: 2),
        color: context.palette.surfaceRaised,
      ),
      child: ClipOval(
        child: iconAsync.when(
          data: (iconBytes) {
            if (iconBytes != null) {
              return Image.memory(
                iconBytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
              );
            }
            return Icon(
              Icons.android,
              size: 12,
              color: context.palette.onCanvas,
            );
          },
          loading: () => const SizedBox(),
          error: (_, _) =>
              Icon(Icons.android, size: 12, color: context.palette.onCanvas),
        ),
      ),
    );
  }
}

// ============================================================================
// MAIN WIDGET - Now handles settings internally
// ============================================================================
class FocusTimeBottomSheet extends ConsumerStatefulWidget {
  final Function() onSave;

  const FocusTimeBottomSheet({super.key, required this.onSave});

  @override
  ConsumerState<FocusTimeBottomSheet> createState() =>
      _FocusTimeBottomSheetState();
}

class _FocusTimeBottomSheetState extends ConsumerState<FocusTimeBottomSheet> {
  late int _duration;
  late int _breaks;
  late bool _blockHomeScreen;
  late bool _strictMode;
  late String _selectedMode;
  bool _isInitialized = false;

  /// Seeds the local fields exactly once: from the real settings when they have
  /// arrived, or from defaults when there are none to wait for (error / no
  /// settings document). Never called while the stream is still loading, so the
  /// sheet cannot show (and then keep) placeholder values.
  void _seed(UserSettingsModel? settings) {
    if (_isInitialized) return;
    _duration = settings?.defaultDuration ?? 25;
    _breaks = settings?.numberOfBreaks ?? 0;
    _blockHomeScreen = settings?.blockPhoneHomeScreen ?? false;
    _strictMode = settings?.strictMode ?? false;
    _selectedMode = settings?.timerMode.toLowerCase() ?? 'timer';
    _isInitialized = true;
  }

  Future<void> _updateSettings({
    int? duration,
    int? breaks,
    bool? blockHome,
    bool? strict,
    String? mode,
  }) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    try {
      // Get current settings to copy from
      final currentSettings = ref.read(userSettingsProvider(user.uid)).value;
      if (currentSettings == null) return;

      final updated = currentSettings.copyWith(
        defaultDuration: duration ?? _duration,
        numberOfBreaks: breaks ?? _breaks,
        blockPhoneHomeScreen: blockHome ?? _blockHomeScreen,
        strictMode: strict ?? _strictMode,
        timerMode: mode ?? _selectedMode,
      );

      // No invalidate: the settings stream is realtime and Firestore fires it
      // for local writes immediately, so the UI stays in sync without tearing
      // the subscription down (which caused a loading flash).
      await ref
          .read(settingsRepositoryProvider)
          .updateSettings(user.uid, updated);
    } catch (e) {
      debugPrint('Failed to update settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    if (user == null) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.3,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const Center(child: Text('Please login first')),
      );
    }

    final settingsAsync = ref.watch(userSettingsProvider(user.uid));

    return settingsAsync.when(
      data: (settings) {
        _seed(settings);
        return _buildContent(context);
      },
      loading: () => Container(
        height: MediaQuery.of(context).size.height * 0.3,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) {
        _seed(null);
        return _buildContent(context);
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      // Fixed height, independent of the keyboard - this sheet hosts
      // BlockAppsSheet as a nested modal on top of itself, and resizing this
      // container on every keyboard-inset frame caused jank.
      height: screenHeight * 0.85,
      decoration: BoxDecoration(
        color: context.palette.canvas,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      child: Column(
        children: [
          const BottomSheetDragHandle(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: keyboardHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Focus session', style: textTheme.displaySmall),
                    const SizedBox(height: AppSpacing.xl),
                    _buildModeSelector(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildDurationSection(),
                    const SizedBox(height: AppSpacing.md),
                    _buildBreaksSection(),
                    const SizedBox(height: AppSpacing.xxl),
                    Text('Block settings', style: textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.md),
                    const _BlockedAppsSection(),
                    const SizedBox(height: AppSpacing.md),
                    _buildToggleOption(
                      title: 'Block phone home screen',
                      value: _blockHomeScreen,
                      onChanged: (value) {
                        setState(() => _blockHomeScreen = value);
                        _updateSettings(blockHome: value);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildStrictModeOption(),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: AppPillButton(
                label: 'Start focus now',
                onPressed: () {
                  Navigator.pop(context);
                  widget.onSave();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          _buildModeButton('Timer', 'timer'),
          _buildModeButton('Stopwatch', 'stopwatch'),
        ],
      ),
    );
  }

  Widget _buildModeButton(String label, String value) {
    final isSelected = _selectedMode == value;
    final palette = context.palette;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() => _selectedMode = value);
            _updateSettings(mode: value);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: isSelected ? palette.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isSelected ? palette.onAccent : palette.onCanvas,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Rounded `surface` card used by every row in this sheet.
  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding:
          padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: child,
    );
  }

  Widget _stepper({
    required String valueText,
    required VoidCallback? onMinus,
    required VoidCallback? onPlus,
    required String label,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconCircleButton(
          icon: Icons.remove_rounded,
          semanticLabel: 'Decrease $label',
          size: 40,
          background: context.palette.surfaceRaised,
          onPressed: onMinus,
        ),
        SizedBox(
          width: 88,
          child: Text(
            valueText,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium,
          ),
        ),
        IconCircleButton(
          icon: Icons.add_rounded,
          semanticLabel: 'Increase $label',
          size: 40,
          background: context.palette.surfaceRaised,
          onPressed: onPlus,
        ),
      ],
    );
  }

  Widget _buildDurationSection() {
    final textTheme = Theme.of(context).textTheme;
    return _card(
      child: Row(
        children: [
          Expanded(child: Text('Duration', style: textTheme.titleMedium)),
          _stepper(
            label: 'duration',
            valueText: '$_duration min',
            onMinus: _duration > 5
                ? () => _changeDuration(_duration - 5)
                : null,
            onPlus: _duration < 180
                ? () => _changeDuration(_duration + 5)
                : null,
          ),
        ],
      ),
    );
  }

  void _changeDuration(int value) {
    final next = value.clamp(5, 180);
    setState(() => _duration = next);
    _updateSettings(duration: next);
  }

  Widget _buildBreaksSection() {
    final textTheme = Theme.of(context).textTheme;
    return _card(
      child: Row(
        children: [
          Expanded(child: Text('Breaks', style: textTheme.titleMedium)),
          _stepper(
            label: 'breaks',
            valueText: '$_breaks',
            onMinus: _breaks > 0 ? () => _changeBreaks(_breaks - 1) : null,
            onPlus: _breaks < 5 ? () => _changeBreaks(_breaks + 1) : null,
          ),
        ],
      ),
    );
  }

  void _changeBreaks(int value) {
    final next = value.clamp(0, 5);
    setState(() => _breaks = next);
    _updateSettings(breaks: next);
  }

  Widget _buildToggleOption({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _card(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildStrictModeOption() {
    final textTheme = Theme.of(context).textTheme;
    return _card(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Strict mode', style: textTheme.titleMedium),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: context.palette.premium,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'PRO',
                  style: textTheme.labelSmall?.copyWith(
                    color: context.palette.onAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Switch(
                value: _strictMode,
                onChanged: (value) {
                  setState(() => _strictMode = value);
                  _updateSettings(strict: value);
                },
              ),
            ],
          ),
          Text('You cannot end your session early', style: textTheme.bodySmall),
        ],
      ),
    );
  }
}
