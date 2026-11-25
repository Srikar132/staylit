import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the design-system rule: every color comes from the theme.
///
/// `lib/core/theme/` is the only place allowed to define raw colors. Anywhere
/// else, use `context.palette` (or `Theme.of(context).colorScheme`).
void main() {
  final themeDir =
      'lib${Platform.pathSeparator}core${Platform.pathSeparator}theme';

  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.contains(themeDir))
      .toList();

  // Matches raw hex colors, legacy AppColors, and named Material colors that
  // bypass the palette. `Colors.transparent` is allowed.
  final forbidden = RegExp(
    r'Color\(0x[0-9A-Fa-f]+\)'
    r'|\bAppColors\b'
    r'|\bColors\.(white|black|grey|blue|red|green|orange|purple|amber|yellow|'
    r'pink|teal|indigo|cyan|brown|redAccent|orangeAccent|greenAccent)\b',
  );

  test('no raw colors or legacy AppColors outside lib/core/theme', () {
    final violations = <String>[];
    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (forbidden.hasMatch(line)) {
          violations.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'Use context.palette instead:\n${violations.join('\n')}',
    );
  });
}
