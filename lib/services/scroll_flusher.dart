import 'package:flutter/foundation.dart';

bool _alwaysTrue(Object? _) => true;

/// Moves Scroll damage data (counts, break-offer answers) from the native side to Firestore without
/// losing or double-writing them: read pending, write (enqueue), then tell
/// native to subtract exactly what was written.
///
/// Only one flush runs at a time. A trigger that arrives meanwhile (a ping and
/// an app resume at once) schedules one more pass instead of racing.
class ScrollFlusher<T> {
  ScrollFlusher({
    required this.readPending,
    required this.write,
    required this.consume,
    this.isWorthWriting = _alwaysTrue,
  });

  final Future<List<T>> Function() readPending;

  /// Items that carry nothing (an all-zero day) are dropped, not written.
  final bool Function(T item) isWorthWriting;

  /// Enqueues the write (fire and forget). Throwing means nothing was written.
  final void Function(String userId, List<T> items) write;
  final Future<void> Function(List<T> items) consume;

  bool _running = false;
  bool _again = false;

  Future<void> flush(String userId) async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        final pending = (await readPending()).where(isWorthWriting).toList();
        if (pending.isEmpty) break;
        // If write throws, consume is skipped and native keeps the counts.
        write(userId, pending);
        await consume(pending);
      } while (_again);
    } catch (e) {
      debugPrint('Scroll damage flush failed: $e');
    } finally {
      _running = false;
    }
  }
}
