import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_config.dart';

class SessionCheckinStat {
  const SessionCheckinStat({
    required this.sessionId,
    required this.name,
    required this.checkInCount,
  });

  final String sessionId;
  final String name;
  final int checkInCount;
}

class AnalyticsSummary {
  const AnalyticsSummary({
    required this.totalCheckIns,
    this.lastUpdated,
  });

  final int totalCheckIns;
  final DateTime? lastUpdated;
}

class CheckinAnalyticsService {
  CheckinAnalyticsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirestoreConfig.instance;

  final FirebaseFirestore _firestore;

  Stream<List<SessionCheckinStat>> watchSessionCheckins(String eventId) {
    return _firestore
        .collection('events/$eventId/sessions')
        .orderBy('order')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => SessionCheckinStat(
                  sessionId: doc.id,
                  name: (doc.data()['name'] as String?) ?? doc.id,
                  checkInCount: (doc.data()['checkInCount'] as num?)?.toInt() ?? 0,
                ),
              )
              .toList(),
        );
  }

  Stream<AnalyticsSummary> watchSummary(String eventId) {
    return _firestore
        .doc('events/$eventId/analytics/summary')
        .snapshots()
        .map((doc) {
      final data = doc.data() ?? const <String, dynamic>{};
      final lastUpdatedTs = data['lastUpdated'];
      return AnalyticsSummary(
        totalCheckIns: (data['totalCheckIns'] as num?)?.toInt() ?? 0,
        lastUpdated:
            lastUpdatedTs is Timestamp ? lastUpdatedTs.toDate() : null,
      );
    });
  }
}
