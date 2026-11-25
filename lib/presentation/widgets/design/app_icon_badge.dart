import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';

/// An app's launcher icon in a rounded square. Without an icon it falls back
/// to a colored circle with the app's initial, so a list never has holes.
///
/// The bitmap is decoded at display size ([size] x device pixel ratio), which
/// keeps long app lists light on memory.
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    required this.name,
    this.icon,
    this.size = 44,
    this.dimmed = false,
  });

  final String name;

  /// PNG/JPEG bytes of the launcher icon, when known.
  final Uint8List? icon;
  final double size;

  /// Fades the badge (e.g. for a turned-off limit).
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();

    final Widget child;
    if (icon != null && icon!.isNotEmpty) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Image.memory(
          icon!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: pixels,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => _initial(context),
        ),
      );
    } else {
      child = _initial(context);
    }

    return Opacity(
      opacity: dimmed ? 0.5 : 1,
      child: SizedBox(width: size, height: size, child: child),
    );
  }

  Widget _initial(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final color = palette.groupColor(name);
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? palette.onInk
        : palette.ink;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        letter,
        style: textTheme.titleLarge?.copyWith(color: onColor),
      ),
    );
  }
}
