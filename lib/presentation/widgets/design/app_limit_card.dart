import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';

/// Where an app is against its daily limit.
enum AppLimitStatus { off, ok, near, exceeded }

/// One app limit: a colored initial, the app name with how much time is left,
/// an on/off switch, a menu, and (when on) a progress bar with used / limit.
///
/// Layout is two rows so a long app name never fights the controls for width.
class AppLimitCard extends StatelessWidget {
  const AppLimitCard({
    super.key,
    required this.appName,
    required this.usedMinutes,
    required this.limitMinutes,
    required this.isActive,
    required this.onToggle,
    required this.onMenu,
  });

  final String appName;
  final int usedMinutes;
  final int limitMinutes;
  final bool isActive;
  final ValueChanged<bool> onToggle;
  final VoidCallback onMenu;

  double get _progress =>
      limitMinutes <= 0 ? 0 : (usedMinutes / limitMinutes).clamp(0.0, 1.0);

  AppLimitStatus get status {
    if (!isActive) return AppLimitStatus.off;
    if (_progress >= 1) return AppLimitStatus.exceeded;
    if (_progress >= 0.75) return AppLimitStatus.near;
    return AppLimitStatus.ok;
  }

  /// "1h 5m" / "45m".
  static String format(int minutes) {
    final total = minutes < 0 ? 0 : minutes;
    final h = total ~/ 60;
    final m = total % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  String get _statusText {
    switch (status) {
      case AppLimitStatus.off:
        return 'Off · ${format(limitMinutes)} a day';
      case AppLimitStatus.exceeded:
        return 'Limit reached';
      case AppLimitStatus.near:
      case AppLimitStatus.ok:
        return '${format(limitMinutes - usedMinutes)} left today';
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    final statusColor = switch (status) {
      AppLimitStatus.exceeded => palette.error,
      AppLimitStatus.near => palette.warning,
      _ => palette.onCanvasMuted,
    };
    final barColor = switch (status) {
      AppLimitStatus.exceeded => palette.error,
      AppLimitStatus.near => palette.warning,
      _ => palette.accent,
    };
    final initial = appName.trim().isEmpty
        ? '?'
        : appName.trim()[0].toUpperCase();
    final avatar = palette.groupColor(appName);
    final onAvatar =
        ThemeData.estimateBrightnessForColor(avatar) == Brightness.dark
        ? palette.onInk
        : palette.ink;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Opacity(
                opacity: isActive ? 1 : 0.5,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: avatar,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initial,
                    style: textTheme.titleLarge?.copyWith(color: onAvatar),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(color: statusColor),
                    ),
                  ],
                ),
              ),
              Switch(value: isActive, onChanged: onToggle),
              IconButton(
                tooltip: 'More options for $appName',
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: palette.onCanvasMuted,
                ),
                onPressed: onMenu,
              ),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Semantics(
                label: '${format(usedMinutes)} used of ${format(limitMinutes)}',
                excludeSemantics: true,
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 6,
                        backgroundColor: palette.surfaceTrack,
                        valueColor: AlwaysStoppedAnimation(barColor),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${format(usedMinutes)} used',
                          style: textTheme.bodySmall,
                        ),
                        Text(format(limitMinutes), style: textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
