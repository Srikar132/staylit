import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/data/models/app_limit_model.dart';
import 'package:staylit/presentation/providers/app_limits_provider.dart';
import 'package:staylit/presentation/providers/auth_provider.dart';
import 'package:staylit/services/app_limit_native_service.dart';

/// `{package: dailyLimitMinutes}` of the limits that should be enforced now.
/// This is the complete set native must hold: native replaces, it does not merge.
Map<String, int> activeLimitsMap(List<AppLimitModel> limits) => {
  for (final limit in limits)
    if (limit.isActive && limit.dailyLimit > 0)
      limit.packageName: limit.dailyLimit,
};

/// Keeps the native app-limit enforcer in step with Firestore. No UI.
///
/// Native only knows the limits Flutter pushes (it saves them, but Firestore is the source of truth), so
/// without this a limit that shows ON in the app is not enforced after a login, a reinstall or a new
/// device until it is toggled off and on. This pushes the full set:
/// - every time the limits stream delivers data (login, any edit, Firestore catching up)
/// - on app resume
/// - an empty set when the user is signed out, so another account's limits never linger
///
/// Watched once from the home shell, so it lives while the user is signed in and does not depend on the
/// Blocks tab having been opened.
final appLimitSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(currentUserProvider.select((u) => u.value?.uid));
  final signedOut = ref.watch(
    currentUserProvider.select((u) => u.hasValue && u.value == null),
  );
  final native = AppLimitNativeService();

  if (uid == null) {
    // Signed out for sure (not just still loading): stop enforcing.
    if (signedOut) unawaited(native.updateLimits(const {}));
    return;
  }

  Map<String, int>? lastPushed;
  Future<void> push(Map<String, int> limits) {
    lastPushed = limits;
    return native.updateLimits(limits);
  }

  // Data events only: while the stream is loading or failed, native keeps what it has.
  ref.listen(appLimitsProvider(uid), (_, next) {
    next.whenData((limits) => unawaited(push(activeLimitsMap(limits))));
  }, fireImmediately: true);

  final lifecycle = AppLifecycleListener(
    onResume: () {
      final limits = lastPushed;
      if (limits != null) unawaited(native.updateLimits(limits));
    },
  );
  ref.onDispose(lifecycle.dispose);
});
