import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/data/models/focus_session_model.dart';
import 'package:staylit/data/repositories/focus_session_repository.dart';

SessionFinishPlan plan({
  String status = SessionStatus.completed,
  String endReason = SessionEndReason.timerFinished,
  int minutes = 25,
  double rate = 100,
  String? notes,
  String? tag,
}) => SessionFinishPlan.build(
  status: status,
  endReason: endReason,
  actualMinutes: minutes,
  completionRate: rate,
  notes: notes,
  tag: tag,
);

void main() {
  group('SessionFinishPlan', () {
    test('a completed session counts toward totals and as completed', () {
      final p = plan();
      expect(p.countsTowardStats, isTrue);
      expect(p.countsAsCompleted, isTrue);
      expect(p.minutes, 25);
      expect(p.sessionFields['status'], SessionStatus.completed);
      expect(p.sessionFields['endReason'], SessionEndReason.timerFinished);
      expect(p.sessionFields['actualDuration'], 25);
      expect(p.sessionFields['completionRate'], 100.0);
    });

    test('an early end counts toward totals but not as completed', () {
      final p = plan(
        status: SessionStatus.endedEarly,
        endReason: SessionEndReason.userEnded,
        minutes: 10,
        rate: 40,
      );
      expect(p.countsTowardStats, isTrue);
      expect(p.countsAsCompleted, isFalse);
      expect(p.minutes, 10);
      expect(p.sessionFields['status'], SessionStatus.endedEarly);
    });

    test('a discarded session changes no totals but keeps its data', () {
      final p = plan(
        status: SessionStatus.discarded,
        endReason: SessionEndReason.userDiscarded,
        minutes: 3,
        rate: 12,
      );
      expect(p.countsTowardStats, isFalse);
      expect(p.countsAsCompleted, isFalse);
      expect(p.sessionFields['status'], SessionStatus.discarded);
      expect(p.sessionFields['actualDuration'], 3);
    });

    test('negative minutes become zero', () {
      final p = plan(minutes: -5);
      expect(p.minutes, 0);
      expect(p.sessionFields['actualDuration'], 0);
    });

    test('completion rate is clamped to 0..100', () {
      expect(plan(rate: 250).sessionFields['completionRate'], 100.0);
      expect(plan(rate: -10).sessionFields['completionRate'], 0.0);
    });

    test('notes and tag are written only when provided', () {
      final without = plan();
      expect(without.sessionFields.containsKey('notes'), isFalse);
      expect(without.sessionFields.containsKey('tag'), isFalse);

      final withBoth = plan(notes: 'Chapter 3', tag: 'Study');
      expect(withBoth.sessionFields['notes'], 'Chapter 3');
      expect(withBoth.sessionFields['tag'], 'Study');
    });

    test('empty notes are kept (saved without writing anything)', () {
      expect(plan(notes: '').sessionFields['notes'], '');
    });

    test('a zero-minute session is still valid', () {
      final p = plan(minutes: 0, rate: 100);
      expect(p.minutes, 0);
      expect(p.countsTowardStats, isTrue);
    });
  });
}
