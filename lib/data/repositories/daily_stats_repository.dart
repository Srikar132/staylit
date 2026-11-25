import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pace/data/models/daily_stat.dart';

/// Reads the per-day focus totals written by `FocusSessionRepository`.
class DailyStatsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// The most recent [days] days as exactly [days] entries ending today
  /// (missing days are zero). Cached by Firestore, so it works offline.
  Stream<List<DailyStat>> streamRecent(String userId, {int days = 7}) {
    return _firestore
        .collection('dailyStats')
        .doc(userId)
        .collection('days')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(days)
        .snapshots()
        .map(
          (snapshot) => DailyStat.lastDays(
            stats: [
              for (final doc in snapshot.docs)
                DailyStat.fromMap(doc.id, doc.data()),
            ],
            today: DateTime.now(),
            days: days,
          ),
        );
  }
}
