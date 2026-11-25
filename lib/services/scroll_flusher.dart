import 'package:flutter/foundation.dart';
import 'package:staylit/data/models/scroll_delta.dart';

/// Moves Scroll damage counts from the native ledger to Firestore without
/// losing or double-writing them: read pending, write (enqueue), then tell
/// native to subtract exactly what was written.
///
/// Only one flush runs at a time. A trigger that arrives meanwhile (a ping and
/// an app resume at once) schedules one more pass instead of racing.
class ScrollFlusher {
  ScrollFlusher({
    required this.readPending,
    required this.write,
    required this.consume,
  });

  final Future<List<ScrollDelta>> Function() readPending;

  /// Enqueues the write (fire and forget). Throwing means nothing was written.
  final void Function(String userId, List<ScrollDelta> deltas) write;
  final Future<void> Function(List<ScrollDelta> deltas) consume;

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
        final pending = (await readPending()).where((d) => !d.isEmpty).toList();
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
