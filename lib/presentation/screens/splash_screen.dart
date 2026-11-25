import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pace/presentation/providers/auth_provider.dart';
import 'package:pace/core/theme/theme_context.dart';

/// Pure loading/error gate. All routing decisions (auth, onboarding,
/// permissions, active-session) live in `appRouterProvider`'s `redirect`
/// callback now - this widget only renders while that's still resolving,
/// or if auth hit an error along the way.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authError = ref.watch(authErrorProvider);

    if (authError != null) {
      return _ErrorScreen(
        error: authError,
        onRetry: () => ref.read(authNotifierProvider.notifier).clearError(),
      );
    }

    return const _LoadingScreen();
  }
}

class _ErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorScreen({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [context.palette.onCanvasMuted, context.palette.accent],
          ),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: context.palette.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 50,
                  color: context.palette.onCanvas,
                ),
              ),

              const SizedBox(height: 24),

              // Error Title
              Text(
                'Something went wrong',
                style: TextStyle(
                  color: context.palette.onCanvas,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Error Message
              Text(
                error,
                style: TextStyle(
                  color: context.palette.onCanvas.withValues(alpha: 0.8),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Retry Button
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.palette.accent,
                  foregroundColor: context.palette.onAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatefulWidget {
  const _LoadingScreen();

  @override
  State<_LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<_LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.canvas,
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: const Image(
            image: AssetImage('assets/images/brand_mark.webp'),
            height: 96,
          ),
        ),
      ),
    );
  }
}
