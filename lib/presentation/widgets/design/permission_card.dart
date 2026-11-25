import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';

/// One permission: round icon, name, what it is for, and either an "Allow"
/// pill (with a spinner while the request runs) or an "Allowed" tick.
class PermissionCard extends StatefulWidget {
  const PermissionCard({
    super.key,
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

  /// Runs the request; the card shows a spinner until it completes.
  final Future<void> Function() onAllow;

  @override
  State<PermissionCard> createState() => _PermissionCardState();
}

class _PermissionCardState extends State<PermissionCard> {
  bool _busy = false;

  Future<void> _allow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onAllow();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final granted = widget.granted;

    return Semantics(
      button: !granted,
      label:
          '${widget.title}. ${widget.description}. '
          '${granted ? 'Allowed' : 'Not allowed yet. Double tap to allow.'}',
      excludeSemantics: true,
      onTap: granted ? null : _allow,
      child: Material(
        color: granted ? palette.surface : palette.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: granted
              ? BorderSide.none
              : BorderSide(color: palette.border, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: granted ? null : _allow,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: granted ? palette.accentSoft : palette.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    granted ? Icons.check_rounded : widget.icon,
                    color: granted ? palette.accentText : palette.onCanvasMuted,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(widget.description, style: textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                if (granted)
                  Text(
                    'Allowed',
                    style: textTheme.labelMedium?.copyWith(
                      color: palette.accentText,
                    ),
                  )
                else if (_busy)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      'Allow',
                      style: textTheme.titleSmall?.copyWith(
                        color: palette.onAccent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
