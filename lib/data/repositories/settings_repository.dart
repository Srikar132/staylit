import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:staylit/data/models/pomodoro_settings.dart';
import 'package:staylit/data/models/user_settings_model.dart';

class SettingsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserSettingsModel _defaultSettings() => UserSettingsModel(
    defaultDuration: 25,
    timerMode: 'timer',
    pomodoroSettings: PomodoroSettings.defaultSettings(),
    numberOfBreaks: 1,
    blockPhoneHomeScreen: false,
    strictMode: false,
    autoStartBreaks: true,
    soundEnabled: true,
    vibrationEnabled: true,
  );

  /// Realtime settings. Firestore's disk cache (persistence is on in `main()`)
  /// serves the first event instantly, and local writes fire it immediately, so
  /// callers never need to invalidate or keep their own copy.
  Stream<UserSettingsModel?> streamSettings(String userId) {
    return _firestore
        .collection('userSettings')
        .doc(userId)
        .snapshots()
        .asyncMap((doc) async {
          if (!doc.exists) {
            // A missing doc seen only from the local cache (e.g. offline on a
            // fresh install) is not proof it does not exist on the server - do not
            // write defaults over what may be real data.
            if (!doc.metadata.isFromCache) {
              await _createDefaultSettings(userId);
            }
            return _defaultSettings();
          }
          return UserSettingsModel.fromFirestore(doc);
        });
  }

  Future<void> updateSettings(String userId, UserSettingsModel settings) async {
    try {
      await _firestore
          .collection('userSettings')
          .doc(userId)
          .set(settings.toFirestore(), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        debugPrint(
          'Offline: Settings saved locally and will sync when online.',
        );
      } else {
        rethrow;
      }
    } catch (e) {
      debugPrint('Error updating settings: $e');
      rethrow;
    }
  }

  Future<void> _createDefaultSettings(String userId) async {
    try {
      await _firestore
          .collection('userSettings')
          .doc(userId)
          .set(_defaultSettings().toFirestore());
    } catch (e) {
      debugPrint('Error creating default settings: $e');
    }
  }
}
