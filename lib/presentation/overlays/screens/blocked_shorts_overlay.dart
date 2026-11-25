import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/presentation/overlays/providers/overlay_provider.dart';
import 'package:staylit/presentation/overlays/widgets/focus_timer_widget.dart';
import 'package:staylit/presentation/overlays/widgets/overlay_background.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/widgets/design/lit_badge.dart';
import 'package:staylit/presentation/overlays/widgets/block_header.dart';
import 'package:staylit/presentation/overlays/widgets/actions_buttons.dart';

class BlockedShortsOverlay extends ConsumerStatefulWidget {
  const BlockedShortsOverlay({super.key});

  @override
  ConsumerState<BlockedShortsOverlay> createState() =>
      _BlockedShortsOverlayState();
}

class _BlockedShortsOverlayState extends ConsumerState<BlockedShortsOverlay>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _bounceController;
  late AnimationController _textController;

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Start animations
    _bounceController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      _textController.forward();
    });

    // Double vibration for shorts
    Future.microtask(() {
      ref.read(overlayDataProvider.notifier).vibrate('double');
    });

    // Auto-dismiss after 2 seconds - close activity and return to YouTube
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ref.read(overlayDataProvider.notifier).closeOverlay();
      }
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _bounceController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overlayState = ref.watch(overlayDataProvider);
    final overlayNotifier = ref.read(overlayDataProvider.notifier);

    if (overlayState.isLoading) {
      return Scaffold(
        backgroundColor: context.palette.ink,
        body: Center(
          child: CircularProgressIndicator(color: context.palette.onInk),
        ),
      );
    }

    final contentType =
        overlayState.overlayData['contentType'] as String? ?? 'Short Content';
    final platform =
        overlayState.overlayData['platform'] as String? ?? 'Unknown';

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: OverlayBackground(
          child: SafeArea(
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: _bounceController,
                curve: Curves.elasticOut,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated wave effect with platform icon
                    _buildWaveAnimation(platform),

                    const SizedBox(height: 32),

                    // Content type blocked message
                    FadeTransition(
                      opacity: _textController,
                      child: _buildBlockMessage(contentType),
                    ),

                    const SizedBox(height: 24),

                    // Focus timer
                    SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0, 0.5),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: _textController,
                              curve: Curves.easeOut,
                            ),
                          ),
                      child: FocusTimerWidget(
                        elapsedMinutes: overlayState.focusTimeMinutes,
                        sessionType: overlayState.sessionType,
                        compact: true,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Educational content card
                    /*SlideTransition(
                      position:  Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _textController,
                        curve: Curves.easeOut,
                      )),
                      child: EducationalContentCard(
                        title:  'Digital Wellness Tip',
                        message: educationalMessage,
                        icon: Icons.psychology,
                        color: context.palette.warning,
                      ),
                    ),*/
                    const SizedBox(height: 24),

                    // Platform-specific tips
                    /*SlideTransition(
                      position:  Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset. zero,
                      ).animate(CurvedAnimation(
                        parent: _textController,
                        curve: Curves.easeOut,
                      )),
                      child: PlatformSpecificTips(platform: platform),
                    ),*/
                    const SizedBox(height: 32),

                    // Quick action buttons
                    FadeTransition(
                      opacity: _textController,
                      child: _buildQuickActions(overlayNotifier),
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

  Widget _buildWaveAnimation(String platform) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer wave
        AnimatedBuilder(
          animation: _waveController,
          builder: (context, child) {
            return Container(
              width: 180 + (_waveController.value * 40),
              height: 180 + (_waveController.value * 40),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _getPlatformColor(platform)
                      .withValues(alpha: 0.3 - (_waveController.value * 0.3)),
                  width: 2,
                ),
              ),
            );
          },
        ),

        // Inner wave
        AnimatedBuilder(
          animation: _waveController,
          builder: (context, child) {
            return Container(
              width: 130 + (_waveController.value * 25),
              height: 130 + (_waveController.value * 25),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _getPlatformColor(platform)
                      .withValues(alpha: 0.5 - (_waveController.value * 0.5)),
                  width: 3,
                ),
              ),
            );
          },
        ),

        // Center: Lit
        const LitBadge(size: 110),
      ],
    );
  }

  Widget _buildBlockMessage(String contentType) {
    return BlockHeader(
      title: '$contentType blocked',
      chip: 'Addictive content detected',
      danger: true,
    );
  }

  Widget _buildQuickActions(OverlayDataNotifier notifier) {
    return BlockActions(
      primaryLabel: 'Go back',
      primaryIcon: Icons.arrow_back_rounded,
      onPrimary: notifier.goBack,
      secondary: [
        BlockAction(
          label: 'Continue',
          icon: Icons.close_rounded,
          onPressed: notifier.closeOverlay,
        ),
        BlockAction(
          label: 'Learn',
          icon: Icons.info_outline_rounded,
          onPressed: () => notifier.showEducationalContent('blocked_shorts'),
        ),
      ],
    );
  }

  Color _getPlatformColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'youtube':
        return context.palette.error;
      case 'instagram':
        return context.palette.chartAlt;
      case 'tiktok':
        return context.palette.badge;
      case 'facebook':
        return context.palette.info;
      case 'snapchat':
        return context.palette.warning;
      default:
        return context.palette.warning;
    }
  }
}
