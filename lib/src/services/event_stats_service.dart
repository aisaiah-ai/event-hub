import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_config.dart';
import '../models/event_stats.dart';

/// Streams event stats. Updated by Cloud Functions only.
/// Missing doc returns empty stats (dashboard shows skeleton/zeroes).
class EventStatsService {
  EventStatsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirestoreConfig.instance;

  final FirebaseFirestore _firestore;

  static const String _statsPath = 'events/%s/stats/overview';

  /// Real-time stream of stats for dashboard.
  Stream<EventStats> watchStats(String eventId) {
    return _firestore
        .doc(_statsPath.replaceFirst('%s', eventId))
        .snapshots()
        .map((snap) => EventStats.fromFirestore(snap.exists ? snap.data() : null));
  }

  /// Last 60 check-in buckets (by minute) for sparkline.
  /// Bucket ID format: yyyyMMddHHmm. Ordered descending (most recent first).
  Stream<List<CheckinBucket>> watchCheckinBuckets(String eventId, {int limit = 60}) {
    final overviewPath = _statsPath.replaceFirst('%s', eventId);
    return _firestore
        .doc(overviewPath)
        .collection('checkinBuckets')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              return CheckinBucket(
                bucketId: d.id,
                count: (data['count'] as num?)?.toInt() ?? 0,
              );
            }).toList());
  }
}

class CheckinBucket {
  const CheckinBucket({required this.bucketId, required this.count});
  final String bucketId;
  final int count;
}
