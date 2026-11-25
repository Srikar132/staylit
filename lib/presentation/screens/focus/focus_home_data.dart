import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:staylit/data/models/focus_session_model.dart';

/// One row of "Today's sessions".
@immutable
class SessionTileData {
  const SessionTileData({
    required this.title,
    required this.subtitle,
    required this.minutes,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final int minutes;
  final IconData icon;

  /// Title for a session without a tag ("untagged" is how the save screen
  /// records no tag).
  static const String untaggedTitle = 'Focus session';

  factory SessionTileData.fromSession(FocusSessionModel session) {
    final tag = session.tag?.trim();
    final hasTag = tag != null && tag.isNotEmpty && tag != 'untagged';
    final started = DateFormat('h:mm a').format(session.startTime);

    final (statusLabel, icon) = switch (session.status) {
      SessionStatus.completed => (
        'Completed',
        Icons.check_circle_outline_rounded,
      ),
      SessionStatus.endedEarly => ('Ended early', Icons.timelapse_rounded),
      _ => ('In progress', Icons.play_circle_outline_rounded),
    };

    return SessionTileData(
      title: hasTag ? tag : untaggedTitle,
      subtitle: '$started · $statusLabel',
      minutes: session.actualDuration ?? 0,
      icon: icon,
    );
  }
}

/// Everything the Focus home screen shows, already resolved from providers.
@immutable
class FocusHomeData {
  const FocusHomeData({
    required this.firstName,
    required this.photoUrl,
    required this.usageText,
    required this.goalMinutes,
    required this.todayMinutes,
    required this.weekMinutes,
    required this.setupTitle,
    required this.setupSubtitle,
    required this.sessions,
  });

  final String firstName;
  final String? photoUrl;

  /// Phone usage today, e.g. "2h 5m" (or "..." while loading).
  final String usageText;
  final int goalMinutes;
  final int todayMinutes;

  /// Minutes per day for the last 7 days, oldest first; last is today.
  final List<int> weekMinutes;

  /// e.g. "25 min · Timer".
  final String setupTitle;

  /// e.g. "5 apps blocked".
  final String setupSubtitle;
  final List<SessionTileData> sessions;
}
