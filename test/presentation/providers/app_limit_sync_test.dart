import 'package:flutter_test/flutter_test.dart';
import 'package:staylit/data/models/app_limit_model.dart';
import 'package:staylit/presentation/providers/app_limit_sync_provider.dart';

AppLimitModel _limit(String pkg, int minutes, {bool active = true}) =>
    AppLimitModel(
      packageName: pkg,
      appName: pkg,
      dailyLimit: minutes,
      weeklyLimit: 0,
      isActive: active,
      actionOnExceed: 'block',
    );

void main() {
  test('only active limits with a positive time are sent', () {
    final map = activeLimitsMap([
      _limit('com.a', 30),
      _limit('com.b', 45, active: false),
      _limit('com.c', 0),
      _limit('com.d', 60),
    ]);
    expect(map, {'com.a': 30, 'com.d': 60});
  });

  test('no limits gives an empty map, which clears native', () {
    expect(activeLimitsMap(const []), isEmpty);
  });
}
