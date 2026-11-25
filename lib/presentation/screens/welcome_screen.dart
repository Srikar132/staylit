import 'package:flutter/material.dart';
import 'package:staylit/core/theme/app_dimens.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/models/auth_actions_bottom_model.dart';
import 'package:staylit/models/model_manager.dart';
import 'package:staylit/presentation/widgets/design/app_pill_button.dart';
import 'package:staylit/presentation/widgets/design/hero_panel.dart';
import 'package:staylit/presentation/widgets/design/staylit_wordmark.dart';

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

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 11,
            child: SizedBox(
              width: double.infinity,
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
                      Expanded(
                        child: Center(
                          // Lit sits on a white disc: an orange flame would
                          // vanish on the orange panel.
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              margin: const EdgeInsets.all(AppSpacing.xxl),
                              padding: const EdgeInsets.all(
                                AppSpacing.xxxl + 8,
                              ),
                              decoration: BoxDecoration(
                                color: palette.surfaceRaised,
                                shape: BoxShape.circle,
                              ),
                              child: Image.asset(
                                'assets/images/lit.webp',
                                fit: BoxFit.contain,
                                semanticLabel: 'Lit, the Staylit flame',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 9,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.xxl,
                AppSpacing.xxl,
                AppSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Focus Better\n'),
                        TextSpan(
                          text: 'Stay in Flow',
                          style: TextStyle(color: palette.accentText),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: textTheme.displayMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Block distractions and build deep work habits, '
                    'effortlessly.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge,
                  ),
                  const Spacer(),
                  AppPillButton(
                    label: 'Get Started',
                    onPressed: () => _getStarted(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
