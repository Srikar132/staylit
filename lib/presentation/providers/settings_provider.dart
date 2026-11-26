import 'package:staylit/data/models/user_settings_model.dart';
import 'package:staylit/data/repositories/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

/// Realtime user settings. Kept alive for the session; Firestore's offline
/// cache makes re-subscribing instant, so do not `ref.invalidate` this.
final userSettingsProvider = StreamProvider.family<UserSettingsModel?, String>((
  ref,
  userId,
) {
  return ref.watch(settingsRepositoryProvider).streamSettings(userId);
});
