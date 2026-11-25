import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staylit/data/models/focus_session_model.dart';
import 'package:staylit/presentation/providers/focus_session_provider.dart';

/// The user's most recent focus sessions (newest first, discarded ones
/// hidden), for the Progress tab. Invalidate to refresh.
final sessionHistoryProvider =
    FutureProvider.family<List<FocusSessionModel>, String>(
      (ref, userId) => ref
          .watch(sessionRepositoryProvider)
          .getSessionHistory(userId: userId, limit: 20),
    );
