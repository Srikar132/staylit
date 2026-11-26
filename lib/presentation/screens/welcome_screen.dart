import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/models/auth_actions_bottom_model.dart';
import 'package:staylit/models/model_manager.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';
import 'package:staylit/presentation/widgets/design/hero_panel.dart';
import 'package:staylit/presentation/widgets/design/staylit_wordmark.dart';

/// Height reserved for the wordmark above the character.
const double _wordmarkBand = 44;

const String _brainPink = 'assets/images/brain-pink.webp';
const String _brainYellow = 'assets/images/brain-yellow.webp';

/// How far the character hangs below the hero panel's bottom edge.
const double _seamOverlap = 28;

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _getStarted(BuildContext context) {
    BottomSheetManager.show(
      context: context,
      child: const AuthActionsBottomModel(),
      isDismissible: false,
      enableDrag: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 11,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: HeroPanel(
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          const SizedBox(height: AppSpacing.xl),
                          StaylitWordmark(
                            fontSize: 30,
                            stayColor: palette.onAccent,
                            litColor: palette.onInk,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // The character stands on the hero and steps over its
                // scalloped bottom edge, like the reference design.
                Positioned(
                  left: AppSpacing.xl,
                  right: AppSpacing.xl,
                  top: topInset + AppSpacing.xl + _wordmarkBand,
                  bottom: -_seamOverlap,
                  child: const _WelcomeCharacter(),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 9,
            child: Stack(
              // Fill the width (a Column would otherwise let it shrink to its
              // content), and clip the brains at the screen edge.
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                // Soft pastel brains behind the copy, as in the reference.
                Positioned(
                  left: AppSpacing.xl,
                  top: _seamOverlap - 8,
                  child: const _Brain(asset: _brainPink, width: 40),
                ),
                Positioned(
                  right: -44,
                  top: _seamOverlap + 8,
                  child: const _Brain(
                    asset: _brainPink,
                    width: 150,
                    opacity: 0.3,
                  ),
                ),
                Positioned(
                  // Half of it sits off the left edge, like the reference.
                  left: -56,
                  bottom: 16,
                  child: const _Brain(
                    asset: _brainYellow,
                    width: 112,
                    opacity: 0.3,
                  ),
                ),
                Padding(
                  // Top padding leaves room for the character's shoe.
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl,
                    _seamOverlap + AppSpacing.md,
                    AppSpacing.xxl,
                    AppSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Focus Better\n'),
                            TextSpan(
                              text: 'Learn Faster',
                              style: TextStyle(color: palette.accent),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: textTheme.displayMedium?.copyWith(
                          fontSize: 36,
                          height: 1.1,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Build deep work habits & eliminate\n'
                        'distractions effortlessly',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: palette.onCanvas,
                        ),
                      ),
                      const Spacer(),
                      // Narrower and taller than a full-width button, to
                      // match the reference.
                      FractionallySizedBox(
                        widthFactor: 0.84,
                        child: SizedBox(
                          height: 56,
                          child: AppPillButton(
                            label: 'Start Your Focus Journey',
                            onPressed: () => _getStarted(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The welcome character on a dark disc, sized to fit the space it is given
/// while keeping the artwork's aspect ratio.
class _WelcomeCharacter extends StatelessWidget {
  const _WelcomeCharacter();

  // welcome.webp is 1084 x 1451.
  static const _aspect = 1084 / 1451;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(
          constraints.maxWidth,
          constraints.maxHeight * _aspect,
        );
        final height = width / _aspect;
        final disc = width * 0.78;

        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                Positioned(
                  left: (width - disc) / 2,
                  top: height * 0.1,
                  width: disc,
                  height: disc,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.palette.ink,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/welcome.webp',
                    fit: BoxFit.contain,
                    semanticLabel:
                        'A cheerful explorer pointing the way, '
                        'with Lit, the Staylit flame',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A soft brain illustration used as background decoration.
class _Brain extends StatelessWidget {
  const _Brain({required this.asset, required this.width, this.opacity = 1});

  final String asset;
  final double width;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Opacity(
        opacity: opacity,
        child: Image.asset(asset, width: width, fit: BoxFit.contain),
      ),
    );
  }
}
