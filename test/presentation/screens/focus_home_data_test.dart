import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace/data/models/focus_session_model.dart';
import 'package:pace/data/models/user_settings_model.dart';
import 'package:pace/data/models/pomodoro_settings.dart';
import 'package:pace/presentation/screens/active_session/active_session_view.dart';
import 'package:pace/presentation/screens/focus/focus_home_data.dart';

FocusSessionModel session({
  String status = SessionStatus.completed,
  String? tag,
  int? minutes = 25,
}) => FocusSessionModel(
  sessionId: 's',
  userId: 'u',
  startTime: DateTime(2026, 11, 24, 9, 41),
  plannedDuration: 25,
  actualDuration: minutes,
  sessionType: 'timer',
  status: status,
  date: '2026-11-24',
  tag: tag,
);

void main() {
  group('SessionTileData.fromSession', () {
    test('uses the tag as the title and shows time and result', () {
      final tile = SessionTileData.fromSession(session(tag: 'Algebra'));
      expect(tile.title, 'Algebra');
      expect(tile.subtitle, '9:41 AM · Completed');
      expect(tile.minutes, 25);
      expect(tile.icon, Icons.check_circle_outline_rounded);
    });

    test('falls back for a missing or "untagged" tag', () {
      expect(
        SessionTileData.fromSession(session()).title,
        SessionTileData.untaggedTitle,
      );
      expect(
        SessionTileData.fromSession(session(tag: 'untagged')).title,
        SessionTileData.untaggedTitle,
      );
      expect(
        SessionTileData.fromSession(session(tag: '   ')).title,
        SessionTileData.untaggedTitle,
      );
    });

    test('labels an early end', () {
      final tile = SessionTileData.fromSession(
        session(status: SessionStatus.endedEarly, minutes: 12),
      );
      expect(tile.subtitle, '9:41 AM · Ended early');
      expect(tile.minutes, 12);
    });

    test('an active session reads as in progress with zero minutes', () {
      final tile = SessionTileData.fromSession(
        session(status: SessionStatus.active, minutes: null),
      );
      expect(tile.subtitle, '9:41 AM · In progress');
      expect(tile.minutes, 0);
    });
  });

  group('SessionMessages.pick', () {
    test('changes every 5 minutes and cycles', () {
      final first = SessionMessages.pick(elapsedMinutes: 0, paused: false);
      expect(SessionMessages.pick(elapsedMinutes: 4, paused: false), first);
      expect(
        SessionMessages.pick(elapsedMinutes: 5, paused: false),
        isNot(first),
      );
      final cycle = SessionMessages.running.length * 5;
      expect(SessionMessages.pick(elapsedMinutes: cycle, paused: false), first);
    });

    test('shows the pause message while paused', () {
      expect(
        SessionMessages.pick(elapsedMinutes: 30, paused: true),
        SessionMessages.paused,
      );
    });

    test('tolerates a negative elapsed time', () {
      expect(
        SessionMessages.pick(elapsedMinutes: -3, paused: false),
        SessionMessages.running.first,
      );
    });
  });

  group('UserSettingsModel.dailyGoalMinutes', () {
    UserSettingsModel settings({int? goal}) => UserSettingsModel(
      defaultDuration: 25,
      timerMode: 'timer',
      pomodoroSettings: PomodoroSettings.defaultSettings(),
      numberOfBreaks: 1,
      blockPhoneHomeScreen: false,
      strictMode: false,
      autoStartBreaks: true,
      soundEnabled: true,
      vibrationEnabled: true,
      theme: 'dark',
      dailyGoalMinutes: goal ?? UserSettingsModel.defaultDailyGoalMinutes,
    );

    test('defaults to 120', () {
      expect(UserSettingsModel.defaultDailyGoalMinutes, 120);
      expect(settings().dailyGoalMinutes, 120);
    });

    test('is written to Firestore and survives copyWith', () {
      final changed = settings().copyWith(dailyGoalMinutes: 90);
      expect(changed.dailyGoalMinutes, 90);
      expect(changed.toFirestore()['dailyGoalMinutes'], 90);
      expect(changed.copyWith(timerMode: 'stopwatch').dailyGoalMinutes, 90);
    });
  });
}
