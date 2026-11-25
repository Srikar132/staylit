import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/data/models/focus_session_model.dart';

Map<String, dynamic> baseDoc() => {
  'userId': 'u1',
  'startTime': Timestamp.fromDate(DateTime(2026, 11, 24, 9)),
  'endTime': null,
  'plannedDuration': 25,
  'actualDuration': null,
  'sessionType': 'timer',
  'status': 'active',
  'date': '2026-11-24',
  'completionRate': 0,
};

void main() {
  group('FocusSessionModel.fromMap', () {
    test('parses an old document that has no newer fields', () {
      final session = FocusSessionModel.fromMap('s1', baseDoc());
      expect(session.sessionId, 's1');
      expect(session.status, SessionStatus.active);
      expect(session.endReason, isNull);
      expect(session.notes, isNull);
      expect(session.tag, isNull);
      expect(session.completionRate, 0.0);
      expect(session.isDiscarded, isFalse);
    });

    test('parses a finished document with the new fields', () {
      final data = baseDoc()
        ..['status'] = SessionStatus.endedEarly
        ..['endReason'] = SessionEndReason.userEnded
        ..['actualDuration'] = 12
        ..['completionRate'] = 48.5
        ..['notes'] = 'Read chapter 3'
        ..['tag'] = 'Study'
        ..['endTime'] = Timestamp.fromDate(DateTime(2026, 11, 24, 9, 12));
      final session = FocusSessionModel.fromMap('s2', data);
      expect(session.status, SessionStatus.endedEarly);
      expect(session.endReason, SessionEndReason.userEnded);
      expect(session.actualDuration, 12);
      expect(session.completionRate, 48.5);
      expect(session.notes, 'Read chapter 3');
      expect(session.tag, 'Study');
      expect(session.endTime, isNotNull);
    });

    test('a discarded session reports isDiscarded', () {
      final data = baseDoc()..['status'] = SessionStatus.discarded;
      expect(FocusSessionModel.fromMap('s3', data).isDiscarded, isTrue);
    });
  });

  group('FocusSessionModel.toFirestore', () {
    test('omits the optional fields while they are null', () {
      final map = FocusSessionModel.fromMap('s1', baseDoc()).toFirestore();
      expect(map.containsKey('endReason'), isFalse);
      expect(map.containsKey('notes'), isFalse);
      expect(map.containsKey('tag'), isFalse);
    });

    test('writes them once set', () {
      final map = FocusSessionModel.fromMap(
        's1',
        baseDoc(),
      ).copyWith(endReason: SessionEndReason.timerFinished).toFirestore();
      expect(map['endReason'], SessionEndReason.timerFinished);
    });
  });
}
