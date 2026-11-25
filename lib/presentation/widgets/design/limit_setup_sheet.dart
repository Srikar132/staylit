import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/widgets/design/app_icon_badge.dart';
import 'package:staylit/presentation/widgets/design/app_limit_card.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';
import 'package:staylit/presentation/widgets/design/icon_circle_button.dart';
import 'package:staylit/presentation/widgets/design/option_card.dart';

/// What happens when an app's daily limit is reached.
enum LimitAction {
  warn('warn', 'Warn me', 'A reminder you can dismiss'),
  block('block', 'Block the app', 'No more time today, no way around it'),
  notify('notify', 'Just notify', 'A quiet notification, nothing blocked');

  const LimitAction(this.value, this.title, this.subtitle);

  /// Stored in Firestore as `actionOnExceed`.
  final String value;
  final String title;
  final String subtitle;
}

/// Bottom-sheet body for choosing a daily limit and what happens at the limit.
/// Pure: [onSubmit] receives the choice; the caller saves it.
class LimitSetupSheet extends StatefulWidget {
  const LimitSetupSheet({
    super.key,
    required this.appName,
    required this.onSubmit,
    this.appIcon,
    this.initialMinutes = 60,
  });

  final String appName;

  /// The app's launcher icon, if known.
  final Widget? appIcon;
  final int initialMinutes;
  final void Function(int minutes, String action) onSubmit;

  static const presets = [15, 30, 60, 120];
  static const step = 5;
  static const minMinutes = 5;
  static const maxMinutes = 24 * 60;

  @override
  State<LimitSetupSheet> createState() => _LimitSetupSheetState();
}

class _LimitSetupSheetState extends State<LimitSetupSheet> {
  late int _minutes = widget.initialMinutes.clamp(
    LimitSetupSheet.minMinutes,
    LimitSetupSheet.maxMinutes,
  );
  LimitAction _action = LimitAction.warn;

  void _set(int minutes) => setState(
    () => _minutes = minutes.clamp(
      LimitSetupSheet.minMinutes,
      LimitSetupSheet.maxMinutes,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                widget.appIcon ?? AppIconBadge(name: widget.appName),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily limit', style: textTheme.bodySmall),
                      Text(
                        widget.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconCircleButton(
                  icon: Icons.remove_rounded,
                  semanticLabel: 'Decrease limit by 5 minutes',
                  onPressed: _minutes > LimitSetupSheet.minMinutes
                      ? () => _set(_minutes - LimitSetupSheet.step)
                      : null,
                ),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    label: 'Limit ${AppLimitCard.format(_minutes)} a day',
                    excludeSemantics: true,
                    child: Text(
                      AppLimitCard.format(_minutes),
                      textAlign: TextAlign.center,
                      style: textTheme.displayMedium,
                    ),
                  ),
                ),
                IconCircleButton(
                  icon: Icons.add_rounded,
                  semanticLabel: 'Increase limit by 5 minutes',
                  onPressed: _minutes < LimitSetupSheet.maxMinutes
                      ? () => _set(_minutes + LimitSetupSheet.step)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final preset in LimitSetupSheet.presets)
                  _PresetChip(
                    label: AppLimitCard.format(preset),
                    selected: _minutes == preset,
                    onTap: () => _set(preset),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text('When the limit is reached', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            for (final action in LimitAction.values) ...[
              OptionCard(
                title: action.title,
                subtitle: action.subtitle,
                selected: _action == action,
                onTap: () => setState(() => _action = action),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
            AppPillButton(
              label: 'Add limit',
              onPressed: () => widget.onSubmit(_minutes, _action.value),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? palette.accentSoft : palette.surface,
        shape: StadiumBorder(
          side: selected
              ? BorderSide(color: palette.accent, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: selected ? palette.accentText : palette.onCanvas,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
