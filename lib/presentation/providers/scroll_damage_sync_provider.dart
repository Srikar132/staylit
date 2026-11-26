import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/data/models/scroll_delta.dart';
import 'package:staylit/data/models/scroll_event.dart';
import 'package:staylit/presentation/providers/auth_provider.dart';
import 'package:staylit/presentation/providers/blocked_content_provider.dart';
import 'package:staylit/presentation/providers/parental_control_provider.dart';
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
  // A parent PIN protects the blocks: native must not offer break passes then.
  final parentalLocked = ref.watch(
    parentalControlProvider(uid).select((p) => p.value?.isEnabled),
  );
  final repository = ref.read(scrollStatsRepositoryProvider);
  final flusher = ScrollFlusher<ScrollDelta>(
    readPending: NativeService.getPendingScrollDamage,
    write: repository.addDeltas,
    consume: NativeService.consumeScrollDamage,
    isWorthWriting: (delta) => !delta.isEmpty,
  );
  final eventFlusher = ScrollFlusher<ScrollEvent>(
    readPending: NativeService.getPendingScrollEvents,
    write: (userId, events) {
      repository.addEvents(userId, events);
      // Take a break switched a block on natively: show the same switch in the Blocks tab.
      for (final event in events) {
        final target = event.blockTarget;
        if (!event.switchedBlockOn || target == null) continue;
        unawaited(
          ref
              .read(blockedContentNotifierProvider.notifier)
              .toggleShortFormBlockStatus(
                userId,
                target.platform,
                target.feature,
                true,
              )
              .catchError((Object e) {
                debugPrint('Could not mirror the block to Firestore: $e');
              }),
        );
      }
    },
    consume: NativeService.consumeScrollEvents,
  );
  Future<void> flushAll() async {
    await flusher.flush(uid);
    await eventFlusher.flush(uid);
  }

  final events = NativeService.focusEventStream.listen((event) {
    if (event['event'] == 'scroll_damage_update') {
      unawaited(flushAll());
    }
  }, onError: (_) {});
  final lifecycle = AppLifecycleListener(onResume: () => unawaited(flushAll()));
  ref.onDispose(() {
    events.cancel();
    lifecycle.dispose();
  });

  unawaited(_start(flushAll, uid, enabled, parentalLocked));
});

Future<void> _start(
  Future<void> Function() flushAll,
  String uid,
  bool? enabled,
  bool? parentalLocked,
) async {
  // Settings still loading: leave native as it is, just collect what it has.
  if (enabled != null) {
    // Flag first so Turn off stops counting immediately, then hand over
    // whatever was counted before it.
    await NativeService.setScrollDamageEnabled(
      enabled: enabled,
      uid: uid,
      parentalLocked: parentalLocked,
    );
  }
  await flushAll();
}
