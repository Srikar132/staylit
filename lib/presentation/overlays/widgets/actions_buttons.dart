import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';

/// One secondary action under the primary button.
class BlockAction {
  const BlockAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}

/// The action stack of a block overlay: one primary pill, outlined secondary
/// pills side by side, and an optional quiet "end session" link.
class BlockActions extends StatelessWidget {
  const BlockActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIcon = Icons.home_rounded,
    this.secondary = const [],
    this.onEndSession,
  });

  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onPrimary;
  final List<BlockAction> secondary;
  final VoidCallback? onEndSession;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppPillButton(
          label: primaryLabel,
          icon: primaryIcon,
          onPressed: onPrimary,
        ),
        if (secondary.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (var i = 0; i < secondary.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppPillButton(
                    label: secondary[i].label,
                    icon: secondary[i].icon,
                    variant: PillButtonVariant.outline,
                    onPressed: secondary[i].onPressed,
                  ),
                ),
              ],
            ],
          ),
        ],
        if (onEndSession != null) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onEndSession,
            style: TextButton.styleFrom(foregroundColor: palette.error),
            child: const Text('End focus session'),
          ),
        ],
      ],
    );
  }
}

/// The original three-button stack, kept for the blocked-app overlay.
class ActionButtons extends StatelessWidget {
  final VoidCallback onGoHome;
  final VoidCallback onEndSession;
  final VoidCallback? onShowEducation;

  const ActionButtons({
    super.key,
    required this.onGoHome,
    required this.onEndSession,
    this.onShowEducation,
  });

  @override
  Widget build(BuildContext context) {
    return BlockActions(
      primaryLabel: 'Go home',
      onPrimary: onGoHome,
      secondary: [
        if (onShowEducation != null)
          BlockAction(
            label: 'Why it works',
            icon: Icons.school_outlined,
            onPressed: onShowEducation!,
          ),
      ],
      onEndSession: onEndSession,
    );
  }
}
