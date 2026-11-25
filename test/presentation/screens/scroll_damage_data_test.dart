import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/data/models/scroll_day.dart';
import 'package:staylit/data/models/scroll_delta.dart';
import 'package:staylit/data/models/scroll_event.dart';
import 'package:staylit/presentation/screens/focus/focus_home_data.dart';
import 'package:staylit/presentation/screens/focus/scroll_trend.dart';
import 'package:staylit/services/scroll_flusher.dart';

ScrollDelta delta(String day, int total, {int sessions = 1}) => ScrollDelta(
  day: day,
  tzOffsetMinutes: 330,
  total: total,
  perApp: {'com.instagram.android': total},
  sessions: sessions,
);

void main() {
  group('ScrollTrend', () {
    test('no yesterday data gives no trend', () {
      expect(ScrollTrend.compare(today: 30, yesterday: 0), isNull);
      expect(ScrollTrend.compare(today: 30, yesterday: -4), isNull);
    });

    test('down is good, up is not, equal is same', () {
      final down = ScrollTrend.compare(today: 88, yesterday: 100)!;
      expect(down.text, '↓ 12% vs yesterday');
      expect(down.good, isTrue);

      final up = ScrollTrend.compare(today: 125, yesterday: 100)!;
      expect(up.text, '↑ 25% vs yesterday');
      expect(up.good, isFalse);

      final same = ScrollTrend.compare(today: 100, yesterday: 100)!;
      expect(same.text, 'Same as yesterday');
      expect(same.good, isTrue);
    });

    test('nothing yet today is a full drop, never negative', () {
      expect(
        ScrollTrend.compare(today: 0, yesterday: 50)!.text,
        '↓ 100% vs yesterday',
      );
      expect(
        ScrollTrend.compare(today: -3, yesterday: 50)!.text,
        '↓ 100% vs yesterday',
      );
    });
  });

  group('ScrollDay', () {
    test('lastDays fills gaps with zero and ends today', () {
      final days = ScrollDay.lastDays(
        stats: const [
          ScrollDay(date: '2026-11-24', total: 40),
          ScrollDay(date: '2026-11-26', total: 10),
        ],
        today: DateTime(2026, 11, 26, 23, 59),
      );
      expect(days.length, 7);
      expect(days.first.date, '2026-11-20');
      expect(days.last.date, '2026-11-26');
      expect([for (final d in days) d.total], [0, 0, 0, 0, 40, 0, 10]);
    });

    test('lastDays crosses a month boundary', () {
      final days = ScrollDay.lastDays(
        stats: const [],
        today: DateTime(2026, 3, 2),
        days: 3,
      );
      expect(
        [for (final d in days) d.date],
        ['2026-02-28', '2026-03-01', '2026-03-02'],
      );
    });

    test('fromMap tolerates missing and damaged values', () {
      final day = ScrollDay.fromMap('2026-11-26', {
        'total': 12.0,
        'sessions': -2,
        'perApp': {'com.instagram.android': 9, 'com.x': 'bad'},
      });
      expect(day.total, 12);
      expect(day.sessions, 0);
      expect(day.perApp, {'com.instagram.android': 9, 'com.x': 0});
      expect(ScrollDay.fromMap('d', {}).total, 0);
    });
  });

  group('ScrollDamageData.fromDays', () {
    test('today, week and trend come from the days', () {
      final data = ScrollDamageData.fromDays(const [
        ScrollDay(date: 'a', total: 5),
        ScrollDay(date: 'b', total: 100),
        ScrollDay(date: 'c', total: 80),
      ]);
      expect(data.todayCount, 80);
      expect(data.week, [5, 100, 80]);
      expect(data.trendText, '↓ 20% vs yesterday');
      expect(data.trendGood, isTrue);
    });

    test('empty and single-day inputs do not crash', () {
      final empty = ScrollDamageData.fromDays(const []);
      expect(empty.todayCount, 0);
      expect(empty.trendText, isNull);
      final one = ScrollDamageData.fromDays(const [
        ScrollDay(date: 'a', total: 7),
      ]);
      expect(one.todayCount, 7);
      expect(one.trendText, isNull);
    });
  });

  group('ScrollDelta', () {
    test('parses native maps with Int or Long numbers', () {
      final d = ScrollDelta.tryParse({
        'day': '2026-11-26',
        'tzOffsetMinutes': 330,
        'total': 4,
        'perApp': {'com.instagram.android': 4},
        'sessions': 1,
      })!;
      expect(d.total, 4);
      expect(d.toMap()['perApp'], {'com.instagram.android': 4});
    });

    test('rejects maps without a day', () {
      expect(ScrollDelta.tryParse({'total': 3}), isNull);
      expect(ScrollDelta.tryParse('nope'), isNull);
      expect(ScrollDelta.tryParse(null), isNull);
    });
  });

  group('ScrollFlusher', () {
    test('writes pending then consumes exactly what it wrote', () async {
      final calls = <String>[];
      var reads = 0;
      final flusher = ScrollFlusher(
        readPending: () async => reads++ == 0 ? [delta('2026-11-26', 5)] : [],
        write: (uid, deltas) => calls.add('write $uid ${deltas.single.total}'),
        consume: (deltas) async => calls.add('consume ${deltas.single.total}'),
      );

      await flusher.flush('u1');
      expect(calls, ['write u1 5', 'consume 5']);
    });

    test('nothing pending does nothing', () async {
      var wrote = false;
      final flusher = ScrollFlusher(
        readPending: () async => [delta('d', 0, sessions: 0)],
        write: (_, _) => wrote = true,
        consume: (_) async {},
        isWorthWriting: (d) => !d.isEmpty,
      );
      await flusher.flush('u');
      expect(wrote, isFalse);
    });

    test('a failed write does not consume, so counts are kept', () async {
      var consumed = false;
      final flusher = ScrollFlusher(
        readPending: () async => [delta('d', 3)],
        write: (_, _) => throw StateError('boom'),
        consume: (_) async => consumed = true,
      );
      await flusher.flush('u');
      expect(consumed, isFalse);
      // And it can flush again afterwards.
      await flusher.flush('u');
    });

    test('overlapping triggers never write the same counts twice', () async {
      final pending = <ScrollDelta>[delta('d', 5)];
      var writes = 0;
      final flusher = ScrollFlusher(
        readPending: () async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return List.of(pending);
        },
        write: (_, _) => writes++,
        consume: (done) async => pending.clear(),
      );

      // A ping and an app resume at the same moment.
      await Future.wait([flusher.flush('u'), flusher.flush('u')]);
      expect(writes, 1);
    });

    test('a trigger during a flush gets one more pass', () async {
      final batches = <List<ScrollDelta>>[
        [delta('d', 5)],
        [delta('d', 2)],
        [],
      ];
      var writes = 0;
      late ScrollFlusher flusher;
      var reads = 0;
      flusher = ScrollFlusher(
        readPending: () async {
          if (reads == 0) unawaited(flusher.flush('u')); // arrives mid flush
          return batches[reads++];
        },
        write: (_, _) => writes++,
        consume: (_) async {},
      );
      await flusher.flush('u');
      expect(writes, 2);
    });
  });

  group('ScrollEvent', () {
    test('parses native maps and round trips', () {
      final event = ScrollEvent.tryParse({
        'ts': 1795636800000,
        'day': '2026-11-26',
        'tzOffsetMinutes': 330,
        'pkg': 'com.instagram.android',
        'sessionCount': 30,
        'threshold': 30,
        'response': 'keep',
      })!;
      expect(event.ts, 1795636800000);
      expect(event.response, 'keep');
      expect(ScrollEvent.tryParse(event.toMap())!.sessionCount, 30);
    });

    test('rejects maps without a timestamp and tolerates damaged fields', () {
      expect(ScrollEvent.tryParse({'response': 'keep'}), isNull);
      expect(ScrollEvent.tryParse(null), isNull);
      final event = ScrollEvent.tryParse({
        'ts': 5,
        'pkg': 7,
        'sessionCount': 'x',
      })!;
      expect(event.pkg, '');
      expect(event.sessionCount, 0);
    });
  });

  test('the flusher also works for events', () async {
    final written = <int>[];
    var reads = 0;
    final flusher = ScrollFlusher<ScrollEvent>(
      readPending: () async => reads++ == 0
          ? [
              const ScrollEvent(
                ts: 1,
                day: 'd',
                tzOffsetMinutes: 0,
                pkg: 'p',
                sessionCount: 30,
                threshold: 30,
                response: 'break',
              ),
            ]
          : [],
      write: (_, events) => written.addAll([for (final e in events) e.ts]),
      consume: (_) async {},
    );
    await flusher.flush('u');
    expect(written, [1]);
  });
}
