import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/data/models/user_model.dart';
import 'package:staylit/presentation/providers/auth_provider.dart';
import 'package:staylit/presentation/providers/focus_session_provider.dart';
import 'package:staylit/presentation/providers/permission_provider.dart';
import 'package:staylit/services/native_service.dart';

/// One-shot app-launch bootstrap:
/// - checks whether a focus session was already running natively (e.g. the
///   app process was killed mid-session) and syncs it into
///   [focusSessionProvider]
/// - runs the initial permission sweep
/// - recovers a timer session that ended while the app was closed, so its
///   Save screen still opens
/// before routing decisions are made.
///
/// Every native step is time-boxed: if a native call ever never answers, the
/// splash screen must not hang forever. The step is logged and skipped.
///
/// This used to live in `SplashScreen`'s `initState()`/local `State` flags
/// (session sync) and a one-shot flag inside `build()` (permission sweep).
/// Moved into a provider so the router's `redirect` callback (a pure
/// function, no widget lifecycle) can depend on it directly, and so
/// `redirect` never has to judge `permissionState.allGranted` before the
/// real sweep has actually run - by the time `appBootstrapProvider` stops
/// loading, `PermissionState.hasCheckedOnce` is guaranteed true (or the
/// sweep timed out and is logged).
final appBootstrapProvider = FutureProvider<void>((ref) async {
  // Brief delay to let providers finish their own initial setup first.
  await Future.delayed(const Duration(milliseconds: 100));

  await Future.wait([
    _syncActiveSession(ref),
    boundedStartupStep(
      'permission sweep',
      ref.read(permissionProvider.notifier).checkPermissions(),
      const Duration(seconds: 5),
      null,
    ),
  ]);

  await _recoverCompletion(ref);
});

/// Runs [work] but gives up after [limit] and returns [fallback].
Future<T> boundedStartupStep<T>(
  String step,
  Future<T> work,
  Duration limit,
  T fallback,
) async {
  try {
    return await work.timeout(limit);
  } on TimeoutException {
    debugPrint(
      '⏱️ Startup step "$step" did not answer in ${limit.inSeconds}s - skipping it',
    );
    return fallback;
  } catch (e) {
    debugPrint('⚠️ Startup step "$step" failed: $e');
    return fallback;
  }
}

Future<void> _syncActiveSession(Ref ref) async {
  final status = await boundedStartupStep<Map<String, dynamic>?>(
    'session status',
    NativeService.getCurrentSessionStatus(),
    const Duration(seconds: 3),
    null,
  );
  if (status != null && status['isActive'] == true) {
    await boundedStartupStep(
      'session sync',
      ref.read(focusSessionProvider.notifier).refreshSessionFromNative(),
      const Duration(seconds: 3),
      null,
    );
  }
}

/// A timer session ended while the app was closed (or no Activity was listening): record it and open
/// its Save screen. Needs the signed-in user to write the session, so it waits for the user (briefly);
/// if there is none yet the completion stays in native and is picked up on the next launch.
Future<void> _recoverCompletion(Ref ref) async {
  final pending = await boundedStartupStep<Map<String, dynamic>?>(
    'pending completion',
    NativeService.getPendingCompletion(),
    const Duration(seconds: 3),
    null,
  );
  if (pending == null) return;

  final user = await boundedStartupStep<UserModel?>(
    'signed-in user',
    ref.read(currentUserProvider.future),
    const Duration(seconds: 4),
    null,
  );
  if (user == null) return;

  ref.read(focusSessionProvider.notifier).recoverCompletion(pending);
}
