import 'package:flutter/material.dart';

/// Lit, the Staylit flame, with the determined face.
///
/// Used only where the user is focusing or something is being blocked (the
/// active session screen and the blocked overlays). The friendly smiling face
/// lives on the welcome and onboarding screens.
class LitBadge extends StatelessWidget {
  const LitBadge({super.key, required this.size, this.asset = focusedAsset});

  /// Height of the flame (it is about 0.65x as wide).
  final double size;

  /// Which pose to show; defaults to the determined face.
  final String asset;

  static const String focusedAsset = 'assets/images/lit_focused.webp';

  /// The scowling pose used for Scroll damage.
  static const String scrollAsset = 'assets/images/lit_scroll.webp';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'Lit, your focus flame',
    );
  }
}
