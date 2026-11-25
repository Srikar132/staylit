import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/services/night_mode_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(MethodChannelNightModeBridge.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late MethodChannelNightModeBridge bridge;

  setUp(() => bridge = MethodChannelNightModeBridge(channel));
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('argumentFor', () {
    test('maps every ThemeMode to the string the native side expects', () {
      expect(
        MethodChannelNightModeBridge.argumentFor(ThemeMode.light),
        'light',
      );
      expect(MethodChannelNightModeBridge.argumentFor(ThemeMode.dark), 'dark');
      expect(
        MethodChannelNightModeBridge.argumentFor(ThemeMode.system),
        'system',
      );
    });
  });

  group('apply', () {
    test(
      'sends setNightMode with the mapped argument and returns the result',
      () async {
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });

        expect(await bridge.apply(ThemeMode.dark), isTrue);
        expect(await bridge.apply(ThemeMode.system), isTrue);

        expect(calls.map((c) => c.method), everyElement('setNightMode'));
        expect(calls.map((c) => c.arguments), ['dark', 'system']);
      },
    );

    test('returns false when the platform declines (older Android)', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => false);
      expect(await bridge.apply(ThemeMode.light), isFalse);
    });

    test('returns false and does not throw on a platform error', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'boom', message: 'nope');
      });
      expect(await bridge.apply(ThemeMode.light), isFalse);
    });

    test(
      'returns false and does not throw when there is no native side',
      () async {
        messenger.setMockMethodCallHandler(channel, null);
        expect(await bridge.apply(ThemeMode.light), isFalse);
      },
    );
  });
}
