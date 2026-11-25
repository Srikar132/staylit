import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tab indexes of the Home shell.
abstract final class HomeTab {
  static const focus = 0;
  static const groups = 1;
  static const blocks = 2;
  static const progress = 3;
}

/// A screen inside the shell asks to switch tab by setting this; the shell
/// switches and resets it to null.
final homeTabRequestProvider = NotifierProvider<HomeTabRequest, int?>(
  HomeTabRequest.new,
);

class HomeTabRequest extends Notifier<int?> {
  @override
  int? build() => null;

  void request(int tab) => state = tab;
  void clear() => state = null;
}
