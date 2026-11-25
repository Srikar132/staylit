import 'package:flutter/material.dart' hide OverlayState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pace/presentation/overlays/providers/overlay_provider.dart';
import 'package:pace/presentation/overlays/widgets/actions_buttons.dart';
import 'package:pace/presentation/overlays/widgets/focus_timer_widget.dart';
import 'package:pace/presentation/overlays/widgets/motivational_message.dart';
import 'package:pace/presentation/overlays/widgets/overlay_background.dart';
import 'package:pace/core/theme/theme_context.dart';
import 'package:pace/presentation/widgets/design/lit_badge.dart';

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
    return Column(
      children: [
        Text(
          '${state.appName} is blocked',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: context.palette.onCanvas,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: context.palette.warning.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: context.palette.warning.withValues(alpha: 0.5),
            ),
          ),
          child: Text(
            'Focus Mode Active',
            style: TextStyle(
              color: context.palette.warning,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  void _showEndSessionDialog(
    BuildContext context,
    OverlayDataNotifier notifier,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: context.palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'End Focus Session?',
          style: TextStyle(
            color: context.palette.onCanvas,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to end your focus session?  Your progress will be saved, but you\'ll lose your current momentum.',
          style: TextStyle(color: context.palette.onCanvasSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Continue Focusing',
              style: TextStyle(color: context.palette.info),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              notifier.endFocusSession();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.palette.error,
              foregroundColor: context.palette.onError,
            ),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
  }
}
