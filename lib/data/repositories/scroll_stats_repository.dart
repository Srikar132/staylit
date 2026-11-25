import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:staylit/data/models/scroll_day.dart';
import 'package:staylit/data/models/scroll_delta.dart';
import 'package:staylit/data/models/scroll_event.dart';

/// Reads and writes the per-day Scroll damage counts in
/// `scrollStats/{uid}/days/{yyyy-MM-dd}`. Counts only.
class ScrollStatsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _days(String userId) =>
      _firestore.collection('scrollStats').doc(userId).collection('days');

  /// The most recent [days] days as exactly [days] entries ending today
  /// (missing days are zero). Cached by Firestore, so it works offline.
  Stream<List<ScrollDay>> streamRecent(String userId, {int days = 7}) {
    return _days(userId)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(days)
        .snapshots()
        .map(
          (snapshot) => ScrollDay.lastDays(
            stats: [
              for (final doc in snapshot.docs)
                ScrollDay.fromMap(doc.id, doc.data()),
            ],
            today: DateTime.now(),
            days: days,
          ),
        );
  }

  /// Adds [deltas] to the stored days (set-merge with increments). Fire and
  /// forget like `FocusSessionRepository.finishSession`: the offline cache
  /// queues the write, so this returns as soon as it is enqueued.
  void addDeltas(String userId, List<ScrollDelta> deltas) {
    final writes = deltas.where((d) => !d.isEmpty).toList();
    if (writes.isEmpty) return;

    final batch = _firestore.batch();
    for (final delta in writes) {
      batch.set(_days(userId).doc(delta.day), {
        'date': delta.day,
        'tzOffsetMinutes': delta.tzOffsetMinutes,
        'total': FieldValue.increment(delta.total),
        'sessions': FieldValue.increment(delta.sessions),
        // A nested map (not dotted paths) so package ids with dots are fine.
        'perApp': {
          for (final entry in delta.perApp.entries)
            entry.key: FieldValue.increment(entry.value),
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    unawaited(
      batch.commit().catchError((Object error, StackTrace stackTrace) {
        debugPrint('Error saving scroll damage: $error');
      }),
    );
  }

  /// Stores the answers to the "Take a break?" offer in
  /// `scrollEvents/{uid}/items/{ts}`. The document id is the offer's
  /// timestamp, so writing the same event twice (a retry after a crash)
  /// overwrites it instead of double counting. Fire and forget.
  void addEvents(String userId, List<ScrollEvent> events) {
    if (events.isEmpty) return;
    final batch = _firestore.batch();
    for (final event in events) {
      batch.set(
        _firestore
            .collection('scrollEvents')
            .doc(userId)
            .collection('items')
            .doc('${event.ts}'),
        {...event.toMap(), 'lastUpdated': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    }
    unawaited(
      batch.commit().catchError((Object error, StackTrace stackTrace) {
        debugPrint('Error saving scroll events: $error');
      }),
    );
  }
}
