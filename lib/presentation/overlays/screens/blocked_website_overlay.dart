import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/presentation/overlays/providers/overlay_provider.dart';
import 'package:staylit/presentation/overlays/widgets/focus_timer_widget.dart';
import 'package:staylit/presentation/overlays/widgets/overlay_background.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/presentation/widgets/design/lit_badge.dart';
import 'package:staylit/presentation/overlays/widgets/block_header.dart';
import 'package:staylit/presentation/overlays/widgets/end_session_dialog.dart';
import 'package:staylit/presentation/overlays/widgets/actions_buttons.dart';

class BlockedWebsiteOverlay extends ConsumerStatefulWidget {
  const BlockedWebsiteOverlay({super.key});

  @override
  ConsumerState<BlockedWebsiteOverlay> createState() =>
      _BlockedWebsiteOverlayState();
}

class _BlockedWebsiteOverlayState extends ConsumerState<BlockedWebsiteOverlay>
    with TickerProviderStateMixin {
  late AnimationController _shieldController;
  late AnimationController _contentController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _shieldController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    // Staggered animation start
    _shieldController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _contentController.forward();
    });

    // Vibrate
    Future.microtask(() {
      ref.read(overlayDataProvider.notifier).vibrate();
    });
  }

  @override
  void dispose() {
    _shieldController.dispose();
    _contentController.dispose();
    _pulseController.dispose();
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

    final domain = overlayState.overlayData['domain'] as String? ?? 'website';

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: OverlayBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // Shield animation
                  ScaleTransition(
                    scale: CurvedAnimation(
                      parent: _shieldController,
                      curve: Curves.elasticOut,
                    ),
                    child: _buildShieldIcon(),
                  ),

                  const SizedBox(height: 32),

                  // Block message
                  FadeTransition(
                    opacity: _contentController,
                    child: _buildBlockMessage(domain),
                  ),

                  const SizedBox(height: 24),

                  // Website info card
                  /*SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _contentController,
                      curve: Curves.easeOut,
                    )),
                    child: WebsiteInfoCard(
                      domain: domain,
                      blockReason: blockReason,
                      isSecure: domain.startsWith('https'),
                    ),
                  ),*/
                  const SizedBox(height: 24),

                  // Focus timer
                  SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, 0.2),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _contentController,
                            curve: Curves.easeOut,
                          ),
                        ),
                    child: FocusTimerWidget(
                      elapsedMinutes: overlayState.focusTimeMinutes,
                      sessionType: overlayState.sessionType,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Productivity suggestions
                  /*FadeTransition(
                    opacity: _contentController,
                    child: ProductivitySuggestions(
                      domain: domain,
                      suggestion: suggestion,
                    ),
                  ),*/
                  const SizedBox(height: 32),

                  // Action buttons
                  SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _contentController,
                            curve: Curves.easeOut,
                          ),
                        ),
                    child: _buildActionButtons(overlayNotifier),
                  ),

                  const SizedBox(height: 24),

                  // Website blocking stats (if available)
                  _buildBlockingStats(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShieldIcon() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) => Transform.scale(
        scale: 1.0 + (_pulseController.value * 0.05),
        child: const LitBadge(size: 130),
      ),
    );
  }

  Widget _buildBlockMessage(String domain) {
    return BlockHeader(
      title: 'Website blocked',
      chip: domain,
      message: 'This website is blocked during your focus session.',
    );
  }

  Widget _buildActionButtons(OverlayDataNotifier notifier) {
    return BlockActions(
      primaryLabel: 'Go home',
      onPrimary: notifier.goHome,
      secondary: [
        BlockAction(
          label: 'Go back',
          icon: Icons.arrow_back_rounded,
          onPressed: notifier.goBack,
        ),
      ],
      onEndSession: () => _showEndSessionDialog(context, notifier),
    );
  }

  Widget _buildBlockingStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.onCanvas.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.palette.onCanvas.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.block,
            label: 'Blocked Today',
            value: '23',
          ),
          _buildStatItem(icon: Icons.timer, label: 'Time Saved', value: '1.2h'),
          _buildStatItem(
            icon: Icons.trending_up,
            label: 'Focus Score',
            value: '85%',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: context.palette.info, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: context.palette.onCanvas,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: context.palette.onCanvas.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showEndSessionDialog(
    BuildContext context,
    OverlayDataNotifier notifier,
  ) {
    showEndSessionDialog(context, onConfirm: notifier.endFocusSession);
  }
}
