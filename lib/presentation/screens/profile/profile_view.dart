import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';
import 'package:staylit/presentation/widgets/design/icon_circle_button.dart';

/// Everything the Profile screen shows.
@immutable
class ProfileData {
  const ProfileData({
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.focusMinutes,
    required this.sessions,
    required this.currentStreak,
    required this.parentalEnabled,
    required this.appearanceLabel,
  });

  final String name;
  final String email;
  final String? photoUrl;
  final int focusMinutes;
  final int sessions;
  final int currentStreak;
  final bool parentalEnabled;

  /// "System" / "Light" / "Dark".
  final String appearanceLabel;
}

/// The Profile screen: who you are, your totals, settings, sign out.
/// Pure presentation; the screen owns navigation and side effects.
class ProfileView extends StatelessWidget {
  const ProfileView({
    super.key,
    required this.data,
    required this.onBack,
    required this.onAppearance,
    required this.onParentalChanged,
    required this.onChangePassword,
    required this.onSignOut,
    this.extra,
  });

  final ProfileData data;
  final VoidCallback onBack;
  final VoidCallback onAppearance;
  final ValueChanged<bool> onParentalChanged;
  final VoidCallback onChangePassword;
  final VoidCallback onSignOut;

  /// Optional extra row at the end of Settings (debug tools).
  final Widget? extra;

  /// "2h 5m" / "45m".
  static String formatMinutes(int minutes) {
    final total = minutes < 0 ? 0 : minutes;
    final h = total ~/ 60;
    final m = total % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xxxl,
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconCircleButton(
              icon: Icons.arrow_back_ios_new_rounded,
              semanticLabel: 'Back',
              onPressed: onBack,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Header(data: data),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Focused',
                  value: formatMinutes(data.focusMinutes),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatTile(label: 'Sessions', value: '${data.sessions}'),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatTile(
                  label: 'Streak',
                  value: '${data.currentStreak}d',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text('Settings', style: textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          _Group(
            children: [
              _Row(
                icon: Icons.brightness_6_outlined,
                title: 'Appearance',
                subtitle: data.appearanceLabel,
                onTap: onAppearance,
              ),
              _Row(
                icon: Icons.lock_outline_rounded,
                title: 'Parental mode',
                subtitle: data.parentalEnabled
                    ? 'On · apps are blocked'
                    : 'Off',
                trailing: Switch(
                  value: data.parentalEnabled,
                  onChanged: onParentalChanged,
                ),
              ),
              _Row(
                icon: Icons.key_rounded,
                title: 'Change password',
                subtitle: 'For parental mode',
                onTap: onChangePassword,
              ),
              ?extra,
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppPillButton(
            label: 'Sign out',
            icon: Icons.logout_rounded,
            variant: PillButtonVariant.outline,
            onPressed: onSignOut,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data});

  final ProfileData data;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final initial = data.name.trim().isEmpty
        ? '?'
        : data.name.trim()[0].toUpperCase();

    return Column(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: palette.accentSoft,
          backgroundImage: data.photoUrl != null
              ? NetworkImage(data.photoUrl!)
              : null,
          child: data.photoUrl == null
              ? Text(
                  initial,
                  style: textTheme.displaySmall?.copyWith(
                    color: palette.accentText,
                  ),
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          data.name,
          style: textTheme.displaySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(data.email, style: textTheme.bodyMedium),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: textTheme.headlineMedium),
            ),
            const SizedBox(height: 2),
            Text(label, style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Rounded surface holding rows separated by hairlines.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: AppSpacing.xl + 40 + AppSpacing.lg,
                color: palette.divider,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: palette.surfaceRaised,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: palette.accentText),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  if (subtitle != null)
                    Text(subtitle!, style: textTheme.bodySmall),
                ],
              ),
            ),
            trailing ??
                (onTap != null
                    ? Icon(
                        Icons.chevron_right_rounded,
                        color: palette.onCanvasMuted,
                      )
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
