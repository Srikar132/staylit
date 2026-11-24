import 'package:cloud_firestore/cloud_firestore.dart';

/// Values of `focusSessions/{id}.status`.
abstract final class SessionStatus {
  /// Running (or paused). The only non-terminal state.
  static const String active = 'active';

  /// Reached its planned duration (stopwatch sessions count as completed).
  static const String completed = 'completed';

  /// The user ended it before the planned duration but kept it.
  static const String endedEarly = 'ended_early';

  /// The user threw it away. Kept as a document, hidden from lists.
  static const String discarded = 'discarded';
}

/// Values of `focusSessions/{id}.endReason`: how the session ended.
abstract final class SessionEndReason {
  /// The timer reached its end on its own.
  static const String timerFinished = 'timer_finished';

  /// The user pressed end and chose to save.
  static const String userEnded = 'user_ended';

  /// The user pressed end and chose to discard.
  static const String userDiscarded = 'user_discarded';
}

/// A focus session as stored in `focusSessions/{sessionId}`.
///
/// All durations are in **minutes**.
class FocusSessionModel {
  final String sessionId;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  final int plannedDuration;
  final int? actualDuration;
  final String sessionType;

  /// One of [SessionStatus].
  final String status;
  final String date; // "2024-01-15"
  final double completionRate;

  /// One of [SessionEndReason]; null while active and on older documents.
  final String? endReason;
  final String? notes;
  final String? tag;

  FocusSessionModel({
    required this.sessionId,
    required this.userId,
    required this.startTime,
    this.endTime,
    required this.plannedDuration,
    this.actualDuration,
    required this.sessionType,
    required this.status,
    required this.date,
    this.completionRate = 0.0,
    this.endReason,
    this.notes,
    this.tag,
  });

  /// Whether the user discarded this session (hidden from lists and stats).
  bool get isDiscarded => status == SessionStatus.discarded;

  factory FocusSessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FocusSessionModel.fromMap(doc.id, data);
  }

  /// Builds a session from raw document [data]. Older documents that lack the
  /// newer fields (`endReason`, `notes`, `tag`) parse with those set to null.
  factory FocusSessionModel.fromMap(String id, Map<String, dynamic> data) {
    return FocusSessionModel(
      sessionId: id,
      userId: data['userId'],
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: data['endTime'] != null
          ? (data['endTime'] as Timestamp).toDate()
          : null,
      plannedDuration: data['plannedDuration'],
      actualDuration: data['actualDuration'],
      sessionType: data['sessionType'],
      status: data['status'],
      date: data['date'],
      completionRate: (data['completionRate'] as num?)?.toDouble() ?? 0.0,
      endReason: data['endReason'] as String?,
      notes: data['notes'] as String?,
      tag: data['tag'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'plannedDuration': plannedDuration,
      'actualDuration': actualDuration,
      'sessionType': sessionType,
      'status': status,
      'date': date,
      'completionRate': completionRate,
      if (endReason != null) 'endReason': endReason,
      if (notes != null) 'notes': notes,
      if (tag != null) 'tag': tag,
    };
  }

  FocusSessionModel copyWith({
    String? sessionId,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    int? plannedDuration,
    int? actualDuration,
    String? sessionType,
    String? status,
    String? date,
    double? completionRate,
    String? endReason,
    String? notes,
    String? tag,
  }) {
    return FocusSessionModel(
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      plannedDuration: plannedDuration ?? this.plannedDuration,
      actualDuration: actualDuration ?? this.actualDuration,
      sessionType: sessionType ?? this.sessionType,
      status: status ?? this.status,
      date: date ?? this.date,
      completionRate: completionRate ?? this.completionRate,
      endReason: endReason ?? this.endReason,
      notes: notes ?? this.notes,
      tag: tag ?? this.tag,
    );
  }
}
