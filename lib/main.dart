import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:staylit/core/constants/app_info.dart';
import 'package:staylit/core/router/app_router.dart';
import 'package:staylit/core/theme/app_theme.dart';
import 'package:staylit/core/theme/theme_context.dart';
import 'package:staylit/data/repositories/theme_repository.dart';
import 'package:staylit/presentation/overlays/overlay_app.dart';
import 'package:staylit/presentation/providers/theme_mode_provider.dart';
import 'package:staylit/services/native_service.dart';
import 'package:staylit/services/night_mode_bridge.dart';

// Overlay entry point - separate from main app
@pragma('vm:entry-point')
Future<void> overlayMain() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The overlay is a separate engine/isolate with no shared providers, so it
  // reads the user's saved theme mode itself (system bar styling is applied by
  // OverlayApp from the resolved theme).
  final themeMode = await SharedPreferencesThemeRepository().load();

  runApp(
    ProviderScope(
      overrides: [initialThemeModeProvider.overrideWithValue(themeMode)],
      child: const OverlayApp(),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase
  await Firebase.initializeApp();

  // Enable Firebase offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Load the saved theme mode before the first frame so there is no flash of
  // the wrong theme. System bar styling follows the resolved theme in
  // StaylitApp's builder.
  final themeMode = await SharedPreferencesThemeRepository().load();

  // Keep Android's per-app night mode (the native splash) in sync with the saved
  // choice, e.g. after an update. Never throws; no-op below Android 12.
  unawaited(MethodChannelNightModeBridge().apply(themeMode));

  runApp(
    ProviderScope(
      overrides: [initialThemeModeProvider.overrideWithValue(themeMode)],
      child: const StaylitApp(),
    ),
  );
}

class StaylitApp extends ConsumerStatefulWidget {
  const StaylitApp({super.key});

  @override
  ConsumerState<StaylitApp> createState() => _StaylitAppState();
}

class _StaylitAppState extends ConsumerState<StaylitApp> {
  @override
  void initState() {
    super.initState();

    // Initialize native method handler after the widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NativeService.initializeMethodHandler(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
          return Material(
            child: Container(
              color: context.palette.error,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: context.palette.onError, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Navigation Error',
                      style: TextStyle(
                        color: context.palette.onError,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorDetails.exception.toString(),
                      style: TextStyle(
                        color: context.palette.onError.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.go(splashRoute);
                      },
                      child: const Text('Restart App'),
                    ),
                  ],
                ),
              ),
            ),
          );
        };
        // System bars follow the resolved (not requested) brightness, so
        // "System" mode is correct too.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.overlayStyle(
            palette: context.palette,
            brightness: Theme.of(context).brightness,
          ),
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}
