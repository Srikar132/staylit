import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/presentation/providers/app_bootstrap_provider.dart';

void main() {
  group('boundedStartupStep', () {
    test('returns the value when the step answers in time', () async {
      final value = await boundedStartupStep<int>(
        'ok',
        Future.value(7),
        const Duration(seconds: 1),
        -1,
      );
      expect(value, 7);
    });

    test(
      'gives up on a step that never answers, so the splash cannot hang',
      () async {
        final value = await boundedStartupStep<int>(
          'hang',
          Completer<int>().future,
          const Duration(milliseconds: 50),
          -1,
        );
        expect(value, -1);
      },
    );

    test(
      'a step that throws falls back instead of failing the bootstrap',
      () async {
        final value = await boundedStartupStep<int>(
          'boom',
          Future<int>.error(StateError('native failed')),
          const Duration(seconds: 1),
          -1,
        );
        expect(value, -1);
      },
    );
  });
}
