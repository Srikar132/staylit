import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pace/core/theme/theme_context.dart';
import 'package:pace/presentation/providers/theme_mode_provider.dart';

import '../../core/theme/app_theme.dart';
import 'overlay_router.dart';

class OverlayApp extends ConsumerWidget {
  const OverlayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Pace Overlay',
      debugShowCheckedModeBanner: false,
      routerConfig: OverlayRouter.router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.overlayStyle(
            palette: context.palette,
            brightness: Theme.of(context).brightness,
            navigationBarColor: Colors.transparent,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
