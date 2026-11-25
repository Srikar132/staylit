import 'package:flutter/material.dart' hide OverlayState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/presentation/overlays/providers/overlay_provider.dart';
import 'package:staylit/presentation/overlays/widgets/actions_buttons.dart';
import 'package:staylit/presentation/overlays/widgets/focus_timer_widget.dart';
import 'package:staylit/presentation/overlays/widgets/motivational_message.dart';
import 'package:staylit/presentation/overlays/widgets/overlay_background.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/widgets/design/lit_badge.dart';
import 'package:staylit/presentation/overlays/widgets/block_header.dart';
import 'package:staylit/presentation/overlays/widgets/end_session_dialog.dart';

//import 'package:lottie/lottie.dart';

class BlockedAppOverlay extends ConsumerStatefulWidget {
  const BlockedAppOverlay({super.key});

  @override
  ConsumerState<BlockedAppOverlay> createState() => _BlockedAppOverlayState();
}

class _BlockedAppOverlayState extends ConsumerState<BlockedAppOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 100), // Very fast fade-in
      vsync: this,
    );

    // Start fade animation immediately - no slide
    _fadeController.forward();

    // Vibrate on appear
    Future.microtask(() {
      ref.read(overlayDataProvider.notifier).vibrate();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overlayState = ref.watch(overlayDataProvider);
    final overlayNotifier = ref.read(overlayDataProvider.notifier);

    if (overlayState.error != null) {
      return Scaffold(
        backgroundColor: context.palette.ink,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: context.palette.error, size: 64),
              const SizedBox(height: 16),
              Text(
                'Error:  ${overlayState.error}',
                style: TextStyle(color: context.palette.onInk),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => overlayNotifier.goHome(),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: OverlayBackground(
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeController,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated block icon
                    _buildBlockIcon(),

                    const SizedBox(height: 32),

                    // App name and block message
                    _buildBlockMessage(overlayState),

                    const SizedBox(height: 24),

                    // Focus timer
                    FocusTimerWidget(
                      elapsedMinutes: overlayState.focusTimeMinutes,
                      sessionType: overlayState.sessionType,
                    ),

                    const SizedBox(height: 32),

                    // Motivational message
                    MotivationalMessage(
                      message:
                          overlayState.overlayData['motivationalMessage']
                              as String? ??
                          'Stay focused on what truly matters!',
                    ),

                    const SizedBox(height: 40),

                    // App info card
                    const SizedBox(height: 32),

                    // Action buttons
                    ActionButtons(
                      onGoHome: () => overlayNotifier.goHome(),
                      onEndSession: () =>
                          _showEndSessionDialog(context, overlayNotifier),
                      onShowEducation: () =>
                          overlayNotifier.showEducationalContent('blocked_app'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlockIcon() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) => Transform.scale(
        scale: 1.0 + (_pulseController.value * 0.05),
        child: const LitBadge(size: 140),
      ),
    );
  }

  Widget _buildBlockMessage(OverlayState state) {
    return BlockHeader(
      title: '${state.appName} is blocked',
      chip: 'Focus mode active',
    );
  }

  void _showEndSessionDialog(
    BuildContext context,
    OverlayDataNotifier notifier,
  ) {
    showEndSessionDialog(context, onConfirm: notifier.endFocusSession);
  }
}
