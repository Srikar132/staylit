import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:installed_apps/installed_apps.dart';

/// Launcher icon bytes for an installed app, looked up once per package and
/// kept for the session so lists and cards never reload it.
final appIconProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  packageName,
) async {
  ref.keepAlive();
  try {
    final info = await InstalledApps.getAppInfo(packageName, null);
    return info?.icon;
  } catch (e) {
    debugPrint('No icon for $packageName: $e');
    return null;
  }
});
