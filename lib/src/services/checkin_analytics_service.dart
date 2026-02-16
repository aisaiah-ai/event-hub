import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/firestore_config.dart';
import '../models/analytics_aggregates.dart';
import '../models/session.dart';

void _log(String msg) => debugPrint('[CheckinAnalytics] $msg');

/// Session check-in stat for dashboard. Reads from analytics docs only.
class SessionCheckinStat {
  const SessionCheckinStat({
    required this.sessionId,
    required this.name,
    required this.checkInCount,
    this.lastUpdated,
    this.startAt,
  });

  final String sessionId;
  final String name;
  final int checkInCount;
  final DateTime? lastUpdated;
  final DateTime? startAt;
}

/// Event-level analytics summary. Reads from analytics/global only.
/// Use GlobalAnalytics for full data (top5, earliest, peak, etc.).
class AnalyticsSummary {
  const AnalyticsSummary({
    required this.totalCheckIns,
    this.totalUniqueAttendees = 0,
    this.lastUpdated,
  });

  final int totalCheckIns;
  final int totalUniqueAttendees;
  final DateTime? lastUpdated;
}

/// Dashboard analytics service. Reads ONLY from:
/// - events/{eventId}/analytics/global
/// - events/{eventId}/sessions/{sessionId}/analytics/summary
/// Does NOT scan attendance collections. Scalable for 3,000+ attendees.
class CheckinAnalyticsService {
  CheckinAnalyticsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirestoreConfig.instance {
    _log('CheckinAnalyticsService init: db=${FirestoreConfig.databaseId} firestore.databaseId=${_firestore.databaseId}');
  }

  final FirebaseFirestore _firestore;

  /// Real-time stream of global analytics (full data).
  Stream<GlobalAnalytics> watchGlobalAnalytics(String eventId) {
    final path = 'events/$eventId/analytics/global';
    _log('watchGlobalAnalytics: path=$path db=${FirestoreConfig.databaseId}');
    return _firestore.doc(path).snapshots().map((doc) {
      final data = doc.data();
      _log('watchGlobalAnalytics: path=$path exists=${doc.exists} hasData=${data != null} totalCheckins=${data?['totalCheckins']}');
      return GlobalAnalytics.fromFirestore(data);
    });
  }

  /// Real-time stream of summary (backward compat).
  Stream<AnalyticsSummary> watchSummary(String eventId) {
    return watchGlobalAnalytics(eventId).map((g) => AnalyticsSummary(
          totalCheckIns: g.totalCheckins,
          totalUniqueAttendees: g.totalUniqueAttendees,
          lastUpdated: g.lastUpdated,
        ));
  }

  /// Real-time stream of session-level check-in stats.
  /// Triggers on analytics/global changes (any check-in) then fetches session analytics.
  /// No attendance collection scan.
  Stream<List<SessionCheckinStat>> watchSessionCheckins(String eventId) {
    return watchSummary(eventId).asyncMap((_) => fetchSessionStats(eventId));
  }

  Future<List<SessionCheckinStat>> fetchSessionStats(String eventId) async {
    final sessionsPath = 'events/$eventId/sessions';
    _log('fetchSessionStats: path=$sessionsPath db=${FirestoreConfig.databaseId}');
    // Don't use orderBy('order') — sessions without 'order' field would be excluded
    final sessionsSnap = await _firestore.collection(sessionsPath).get();

    _log('fetchSessionStats: sessions count=${sessionsSnap.docs.length} ids=${sessionsSnap.docs.map((d) => d.id).toList()}');
    if (sessionsSnap.docs.isEmpty) return [];

    final docs = sessionsSnap.docs.toList()
      ..sort((a, b) {
        final orderA = (a.data()['order'] as num?)?.toInt() ?? 999;
        final orderB = (b.data()['order'] as num?)?.toInt() ?? 999;
        return orderA.compareTo(orderB);
      });

    final results = <SessionCheckinStat>[];
    for (final doc in docs) {
      final summaryPath = 'events/$eventId/sessions/${doc.id}/analytics/summary';
      final session = Session.fromFirestore(doc.id, doc.data() ?? {});
      final summarySnap = await _firestore.doc(summaryPath).get();
      final summaryData = summarySnap.data();
      final count = (summaryData?['attendanceCount'] as num?)?.toInt() ?? 0;
      _log('fetchSessionStats: session=${doc.id} path=$summaryPath exists=${summarySnap.exists} attendanceCount=$count');
      results.add(SessionCheckinStat(
        sessionId: doc.id,
        name: session.displayName,
        checkInCount:
            (summaryData?['attendanceCount'] as num?)?.toInt() ?? 0,
        lastUpdated: (summaryData?['lastUpdated'] as Timestamp?)?.toDate(),
        startAt: ((doc.data() ?? {})['startAt'] as Timestamp?)?.toDate(),
      ));
    }
    return results;
  }

  /// One-time fetch of global analytics (for export).
  Future<GlobalAnalytics> getGlobalAnalytics(String eventId) async {
    final snap =
        await _firestore.doc('events/$eventId/analytics/global').get();
    return GlobalAnalytics.fromFirestore(snap.data());
  }

  /// One-time fetch of all session analytics (for export).
  Future<List<SessionAnalyticsSummary>> getSessionAnalytics(
    String eventId,
    List<Session> sessions,
  ) async {
    final results = <SessionAnalyticsSummary>[];
    for (final s in sessions) {
      final snap = await _firestore
          .doc('events/$eventId/sessions/${s.id}/analytics/summary')
          .get();
      results.add(SessionAnalyticsSummary.fromFirestore(
        s.id,
        s.displayName,
        snap.data(),
        sessionStartAt: s.startAt,
      ));
    }
    return results;
  }
}
