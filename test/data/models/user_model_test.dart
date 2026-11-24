import 'package:flutter_test/flutter_test.dart';
import 'package:pace/data/models/user_model.dart';

UserModel userWith(int totalFocusMinutes) => UserModel(
  uid: 'u1',
  email: 'a@b.c',
  createdAt: DateTime(2026),
  lastLoginAt: DateTime(2026),
  totalFocusTime: totalFocusMinutes,
);

void main() {
  group('UserModel.formattedTotalFocusTime (value is in minutes)', () {
    test('shows minutes only below an hour', () {
      expect(userWith(0).formattedTotalFocusTime, '0m');
      expect(userWith(45).formattedTotalFocusTime, '45m');
      expect(userWith(59).formattedTotalFocusTime, '59m');
    });

    test('shows hours and minutes from one hour up', () {
      expect(userWith(60).formattedTotalFocusTime, '1h 0m');
      expect(userWith(125).formattedTotalFocusTime, '2h 5m');
      expect(userWith(1500).formattedTotalFocusTime, '25h 0m');
    });
  });
}
