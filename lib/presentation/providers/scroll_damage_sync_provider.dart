import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/presentation/providers/auth_provider.dart';
import 'package:staylit/presentation/providers/scroll_damage_provider.dart';
import 'package:staylit/presentation/providers/settings_provider.dart';
import 'package:staylit/services/native_service.dart';
import 'package:staylit/services/scroll_flusher.dart';

/// Keeps the native Scroll damage counter and Firestore in step. No UI.
///
/// - mirrors the `scrollDamageEnabled` setting (and the account) to native,
///   so Turn off stops counting at once and logging out stops it too
/// - moves counts native -> Firestore on start, app resume and the native
///   "new counts" ping (see [ScrollFlusher])
///
/// Watched once from the home shell, so it lives while the user is signed in.
final scrollDamageSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(currentUserProvider.select((u) => u.value?.uid));
  final signedOut = ref.watch(
    currentUserProvider.select((u) => u.hasValue && u.value == null),
  );

  if (uid == null) {
    // Signed out for sure (not just still loading): stop counting.
    if (signedOut) {
      unawaited(NativeService.setScrollDamageEnabled(enabled: false, uid: ''));
    }
    return;
  }

  final enabled = ref.watch(
    userSettingsProvider(uid).select((s) => s.value?.scrollDamageEnabled),
  );
  final repository = ref.read(scrollStatsRepositoryProvider);
  final flusher = ScrollFlusher(
    readPending: NativeService.getPendingScrollDamage,
    write: repository.addDeltas,
    consume: NativeService.consumeScrollDamage,
  );

  final events = NativeService.focusEventStream.listen((event) {
    if (event['event'] == 'scroll_damage_update') {
      unawaited(flusher.flush(uid));
    }
  }, onError: (_) {});
  final lifecycle = AppLifecycleListener(
    onResume: () => unawaited(flusher.flush(uid)),
  );
  ref.onDispose(() {
    events.cancel();
    lifecycle.dispose();
  });

  unawaited(_start(flusher, uid, enabled));
});

Future<void> _start(ScrollFlusher flusher, String uid, bool? enabled) async {
  // Settings still loading: leave native as it is, just collect what it has.
  if (enabled != null) {
    // Flag first so Turn off stops counting immediately, then hand over
    // whatever was counted before it.
    await NativeService.setScrollDamageEnabled(enabled: enabled, uid: uid);
  }
  await flusher.flush(uid);
}
