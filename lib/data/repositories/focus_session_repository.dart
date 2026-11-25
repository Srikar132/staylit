import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:staylit/data/models/daily_stat.dart';
import 'package:staylit/data/models/focus_session_model.dart';

/// What to write when a session ends, computed without touching Firestore so
/// the rules can be unit-tested.
///
/// Durations are minutes. Server timestamps are added by the repository.
@immutable
class SessionFinishPlan {
  const SessionFinishPlan._({
    required this.sessionFields,
    required this.minutes,
    required this.countsTowardStats,
    required this.countsAsCompleted,
  });

  /// Plans the terminal write for a session.
  ///
  /// [status] must be one of the terminal [SessionStatus] values. Negative
  /// [actualMinutes] are treated as 0 and [completionRate] is clamped to
  /// 0..100. [notes] and [tag] are written only when provided.
  factory SessionFinishPlan.build({
    required String status,
    required String endReason,
    required int actualMinutes,
    required double completionRate,
    int pauseCount = 0,
    int interruptionCount = 0,
    String? notes,
    String? tag,
  }) {
    assert(
      status == SessionStatus.completed ||
          status == SessionStatus.endedEarly ||
          status == SessionStatus.discarded,
      'status must be terminal, got $status',
    );
    final minutes = actualMinutes < 0 ? 0 : actualMinutes;
    final rate = completionRate.clamp(0.0, 100.0).toDouble();
    return SessionFinishPlan._(
      sessionFields: {
        'status': status,
        'endReason': endReason,
        'actualDuration': minutes,
        'completionRate': rate,
        'pauseCount': pauseCount < 0 ? 0 : pauseCount,
        'interruptionCount': interruptionCount < 0 ? 0 : interruptionCount,
        'notes': ?notes,
        'tag': ?tag,
      },
      minutes: minutes,
      countsTowardStats: status != SessionStatus.discarded,
      countsAsCompleted: status == SessionStatus.completed,
    );
  }

  /// Fields to merge into `focusSessions/{id}` (without `endTime`).
  final Map<String, Object> sessionFields;

  /// Minutes added to the user's and the day's totals.
  final int minutes;

  /// False for discarded sessions: they change no totals.
  final bool countsTowardStats;

  /// Whether the day's `completedSessions` goes up.
  final bool countsAsCompleted;
}

class FocusSessionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create new session (works offline!)
  Future<String> createSession(FocusSessionModel session) async {
    try {
      final docRef = _firestore
          .collection('focusSessions')
          .doc(session.sessionId);
      await docRef.set(session.toFirestore());

      return docRef.id; // Now this will be the timestamp ID
    } catch (e) {
      debugPrint('Error creating session: $e');
      rethrow;
    }
  }

  /// Ends a session: one atomic batch updates the session document and, unless
  /// it was discarded, the user's totals and the day's stats.
  ///
  /// Fire-and-forget by design: Firestore only completes `batch.commit()` once
  /// the server acknowledges it, so waiting here would freeze the UI offline.
  /// The write is queued locally and synced later; a failure is logged.
  void finishSession({
    required String sessionId,
    required String userId,
    required String status,
    required String endReason,
    required int actualMinutes,
    required double completionRate,
    required String date,
    int pauseCount = 0,
    int interruptionCount = 0,
    String? notes,
    String? tag,
  }) {
    final plan = SessionFinishPlan.build(
      status: status,
      endReason: endReason,
      actualMinutes: actualMinutes,
      completionRate: completionRate,
      pauseCount: pauseCount,
      interruptionCount: interruptionCount,
      notes: notes,
      tag: tag,
    );

    final batch = _firestore.batch();

    batch.update(_firestore.collection('focusSessions').doc(sessionId), {
      ...plan.sessionFields,
      'endTime': FieldValue.serverTimestamp(),
    });

    if (plan.countsTowardStats) {
      // set(merge) so a missing document is created instead of failing the
      // whole batch.
      batch.set(_firestore.collection('users').doc(userId), {
        'totalFocusTime': FieldValue.increment(plan.minutes),
        'totalSessions': FieldValue.increment(1),
        'lastActiveDate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.set(
        _firestore
            .collection('dailyStats')
            .doc(userId)
            .collection('days')
            .doc(date),
        {
          'date': date,
          'tzOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
          'totalFocusTime': FieldValue.increment(plan.minutes),
          'totalSessions': FieldValue.increment(1),
          'completedSessions': FieldValue.increment(
            plan.countsAsCompleted ? 1 : 0,
          ),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    unawaited(
      batch.commit().catchError((Object error, StackTrace stackTrace) {
        debugPrint('Error finishing session $sessionId: $error');
      }),
    );
  }

  /// Adds a note and/or tag to a session that is already recorded. Fire and
  /// forget like [finishSession]: the offline cache queues the write.
  void updateSessionDetails({
    required String sessionId,
    String? notes,
    String? tag,
  }) {
    final fields = <String, Object>{
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'tag': ?tag,
    };
    if (fields.isEmpty) return;
    unawaited(
      _firestore
          .collection('focusSessions')
          .doc(sessionId)
          .update(fields)
          .catchError((Object error) {
            debugPrint('Error updating session $sessionId: $error');
          }),
    );
  }

  // Get today's sessions (cached by Firebase!). Discarded sessions are hidden.
  Stream<List<FocusSessionModel>> streamTodaySessions(String userId) {
    final dateString = DailyStat.dayKey(DateTime.now());

    return _firestore
        .collection('focusSessions')
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: dateString)
        .orderBy('startTime', descending: true)
        .snapshots(includeMetadataChanges: true) // Offline support
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => FocusSessionModel.fromFirestore(doc))
              .where((session) => !session.isDiscarded)
              .toList(),
        );
  }

  // Get session history (with pagination). Discarded sessions are hidden, so a
  // page can hold fewer than [limit] items.
  Future<List<FocusSessionModel>> getSessionHistory({
    required String userId,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection('focusSessions')
          .where('userId', isEqualTo: userId)
          .orderBy('startTime', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => FocusSessionModel.fromFirestore(doc))
          .where((session) => !session.isDiscarded)
          .toList();
    } catch (e) {
      debugPrint('Error getting session history: $e');
      return [];
    }
  }
}
