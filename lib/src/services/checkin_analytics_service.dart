import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/firestore_config.dart';
import '../models/analytics_aggregates.dart';
import '../models/session.dart';

void _log(String msg) => debugPrint('[CheckinAnalytics] $msg');

/// Session check-in stat for dashboard. Reads from attendance counts + session docs.
class SessionCheckinStat {
  const SessionCheckinStat({
    required this.sessionId,
    required this.name,
    required this.checkInCount,
    this.lastUpdated,
    this.startAt,
    this.isActive = true,
    this.capacity = 0,
    this.preRegisteredCount = 0,
  });

  final String sessionId;
  final String name;
  final int checkInCount;
  final DateTime? lastUpdated;
  final DateTime? startAt;
  final bool isActive;
  /// Hard capacity (0 = unlimited).
  final int capacity;
  /// Number of registrants pre-registered for this session.
  final int preRegisteredCount;
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

/// Dashboard analytics service.
/// Counts come from attendance collections (accurate). Analytics docs used for
/// region/ministry/hourly when available. Scales via count() aggregation.
class CheckinAnalyticsService {
  CheckinAnalyticsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirestoreConfig.instance {
    _log('CheckinAnalyticsService init: db=${FirestoreConfig.databaseId} firestore.databaseId=${_firestore.databaseId}');
  }

  final FirebaseFirestore _firestore;
  final StreamController<void> _refreshTrigger = StreamController<void>.broadcast();

  /// Trigger a manual refresh. Causes watch streams to emit fresh data.
  void triggerRefresh() {
    if (!_refreshTrigger.isClosed) _refreshTrigger.add(null);
  }

  static const _pollInterval = Duration(seconds: 4);

  static Stream<T> _mergeStreams<T>(List<Stream<T>> streams) {
    final controller = StreamController<T>.broadcast();
    final subs = <StreamSubscription<T>>[];
    for (final s in streams) {
      subs.add(s.listen(
        controller.add,
        onError: controller.addError,
        cancelOnError: false,
      ));
    }
    controller.onCancel = () async {
      for (final sub in subs) {
        await sub.cancel();
      }
    };
    return controller.stream;
  }

  /// Real-time stream of global analytics (full data).
  /// totalCheckins comes from live attendance counts; other fields from analytics doc.
  Stream<GlobalAnalytics> watchGlobalAnalytics(String eventId) {
    final path = 'events/$eventId/analytics/global';
    _log('watchGlobalAnalytics: path=$path db=${FirestoreConfig.databaseId}');
    final fromSnapshots = _firestore.doc(path).snapshots().asyncMap((doc) async {
      final base = GlobalAnalytics.fromFirestore(doc.data());
      final liveTotal = await _totalCheckinsFromAttendance(eventId);
      // When pre-computed totalRegistrants is 0 (e.g. before backfill or old doc), fill from live count
      final registrants = base.totalRegistrants > 0
          ? base.totalRegistrants
          : await getRegistrantCount(eventId);
      _log('watchGlobalAnalytics: totalCheckins=$liveTotal (from attendance) totalRegistrants=$registrants');
      return base.copyWith(totalCheckins: liveTotal, totalRegistrants: registrants);
    });
    final fromPoll = Stream.periodic(_pollInterval)
        .asyncMap((_) => getGlobalAnalytics(eventId));
    final fromRefresh = _refreshTrigger.stream
        .asyncMap((_) => getGlobalAnalytics(eventId));
    return _mergeStreams([fromSnapshots, fromPoll, fromRefresh]);
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
  /// Also polls periodically so dashboard updates within ~15s of check-in.
  /// No attendance collection scan.
  Stream<List<SessionCheckinStat>> watchSessionCheckins(String eventId) {
    final fromGlobal = watchSummary(eventId).asyncMap((_) => fetchSessionStats(eventId));
    final fromPoll = Stream.periodic(_pollInterval)
        .asyncMap((_) => fetchSessionStats(eventId));
    final fromRefresh = _refreshTrigger.stream
        .asyncMap((_) => fetchSessionStats(eventId));
    return _mergeStreams([fromGlobal, fromPoll, fromRefresh]);
  }

  /// Count docs in attendance subcollection. Uses count() aggregation (no document transfer).
  Future<int> _countAttendance(String eventId, String sessionId) async {
    try {
      final snapshot = await _firestore
          .collection('events/$eventId/sessions/$sessionId/attendance')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      _log('_countAttendance failed: $e');
      return 0;
    }
  }

  /// Session stats from live attendance counts. Accurate regardless of Cloud Functions.
  Future<List<SessionCheckinStat>> fetchSessionStats(String eventId) async {
    final sessionsPath = 'events/$eventId/sessions';
    _log('fetchSessionStats: path=$sessionsPath db=${FirestoreConfig.databaseId}');
    final sessionsSnap = await _firestore.collection(sessionsPath).get();

    _log('fetchSessionStats: sessions count=${sessionsSnap.docs.length} ids=${sessionsSnap.docs.map((d) => d.id).toList()}');
    if (sessionsSnap.docs.isEmpty) return [];

    final docs = sessionsSnap.docs.toList()
      ..sort((a, b) {
        final orderA = (a.data()['order'] as num?)?.toInt() ?? 999;
        final orderB = (b.data()['order'] as num?)?.toInt() ?? 999;
        return orderA.compareTo(orderB);
      });

    // Fetch pre-registered counts for all sessions in one query.
    final preRegCounts = await _fetchPreRegCounts(eventId);

    final results = <SessionCheckinStat>[];
    for (final doc in docs) {
      final data = doc.data();
      final session = Session.fromFirestore(doc.id, data);
      // Prefer session doc attendanceCount (authoritative for capacity); fallback to live count.
      final count = session.attendanceCount > 0
          ? session.attendanceCount
          : await _countAttendance(eventId, doc.id);
      _log('fetchSessionStats: session=${doc.id} attendanceCount=$count');
      final startAt = (data['startAt'] as Timestamp?)?.toDate();
      results.add(SessionCheckinStat(
        sessionId: doc.id,
        name: session.displayName,
        checkInCount: count,
        lastUpdated: DateTime.now(),
        startAt: startAt,
        isActive: session.isActive,
        capacity: session.capacity,
        preRegisteredCount: preRegCounts[doc.id] ?? 0,
      ));
    }
    return results;
  }

  /// Counts pre-registered registrants per session from sessionRegistrations collection.
  Future<Map<String, int>> _fetchPreRegCounts(String eventId) async {
    try {
      final snap = await _firestore
          .collection('events/$eventId/sessionRegistrations')
          .get();
      final counts = <String, int>{};
      for (final doc in snap.docs) {
        final list = doc.data()['sessionIds'];
        if (list is! List) continue;
        for (final e in list) {
          final id = e?.toString();
          if (id == null || id.isEmpty) continue;
          counts[id] = (counts[id] ?? 0) + 1;
        }
      }
      return counts;
    } catch (e) {
      _log('_fetchPreRegCounts failed: $e');
      return {};
    }
  }

  /// Count of registrants. Uses count() aggregation.
  Future<int> getRegistrantCount(String eventId) async {
    try {
      final snapshot = await _firestore
          .collection('events/$eventId/registrants')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      _log('getRegistrantCount failed: $e');
      return 0;
    }
  }

  /// Real-time stream of registrant count. Merges with same triggers as session stats.
  Stream<int> watchRegistrantCount(String eventId) {
    final fromGlobal = watchSummary(eventId).asyncMap((_) => getRegistrantCount(eventId));
    final fromPoll = Stream.periodic(_pollInterval)
        .asyncMap((_) => getRegistrantCount(eventId));
    final fromRefresh = _refreshTrigger.stream
        .asyncMap((_) => getRegistrantCount(eventId));
    return _mergeStreams([fromGlobal, fromPoll, fromRefresh]);
  }

  /// Sum of check-ins across all sessions (from live attendance counts).
  Future<int> _totalCheckinsFromAttendance(String eventId) async {
    final stats = await fetchSessionStats(eventId);
    return stats.fold<int>(0, (acc, s) => acc + s.checkInCount);
  }

  /// One-time fetch of global analytics. totalCheckins from live attendance; totalRegistrants from doc or live count when 0.
  Future<GlobalAnalytics> getGlobalAnalytics(String eventId) async {
    final snap =
        await _firestore.doc('events/$eventId/analytics/global').get();
    final base = GlobalAnalytics.fromFirestore(snap.data());
    final liveTotal = await _totalCheckinsFromAttendance(eventId);
    final registrants = base.totalRegistrants > 0
        ? base.totalRegistrants
        : await getRegistrantCount(eventId);
    return base.copyWith(totalCheckins: liveTotal, totalRegistrants: registrants);
  }

  /// Top 3 earliest registrations (name + timestamp). Sorted ascending.
  Future<List<({String name, DateTime timestamp})>> getTop3EarliestRegistrants(
    String eventId,
  ) async {
    try {
      final path = 'events/$eventId/registrants';
      final snap = await _firestore
          .collection(path)
          .orderBy('createdAt', descending: false)
          .limit(3)
          .get();
      final results = <({String name, DateTime timestamp})>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = data['createdAt'] ?? data['registeredAt'];
        final dt = ts is Timestamp ? ts.toDate() : DateTime.now();
        final profile = data['profile'] as Map<String, dynamic>? ?? {};
        final answers = data['answers'] as Map<String, dynamic>? ?? {};
        final name = profile['name'] ?? answers['name'];
        final first = profile['firstName'] ?? answers['firstName'];
        final last = profile['lastName'] ?? answers['lastName'];
        final displayName = name?.toString().trim().isNotEmpty == true
            ? name.toString().trim()
            : '${first ?? ''} ${last ?? ''}'.trim();
        results.add((name: displayName.isEmpty ? 'Guest' : displayName, timestamp: dt));
      }
      return results;
    } catch (e) {
      _log('getTop3EarliestRegistrants failed: $e');
      return [];
    }
  }

  /// Top 3 earliest check-ins (name + timestamp). Sorted ascending.
  Future<List<({String name, DateTime timestamp})>> getTop3EarliestCheckins(
    String eventId,
  ) async {
    try {
      final sessionsSnap = await _firestore
          .collection('events/$eventId/sessions')
          .get();
      final candidates = <({String registrantId, DateTime timestamp})>[];
      for (final s in sessionsSnap.docs) {
        final attSnap = await _firestore
            .collection('events/$eventId/sessions/${s.id}/attendance')
            .orderBy('checkedInAt', descending: false)
            .limit(5)
            .get();
        for (final d in attSnap.docs) {
          final data = d.data();
          final ts = data['checkedInAt'];
          if (ts is Timestamp) {
            candidates.add((registrantId: d.id, timestamp: ts.toDate()));
          }
        }
      }
      candidates.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      // First 3 unique registrants by earliest check-in time (one row per person).
      final seen = <String>{};
      final top3 = <({String registrantId, DateTime timestamp})>[];
      for (final c in candidates) {
        if (seen.contains(c.registrantId)) continue;
        seen.add(c.registrantId);
        top3.add(c);
        if (top3.length >= 3) break;
      }
      final results = <({String name, DateTime timestamp})>[];
      for (final c in top3) {
        final regSnap = await _firestore
            .doc('events/$eventId/registrants/${c.registrantId}')
            .get();
        final data = regSnap.data() ?? {};
        final profile = data['profile'] as Map<String, dynamic>? ?? {};
        final answers = data['answers'] as Map<String, dynamic>? ?? {};
        final name = profile['name'] ?? answers['name'];
        final first = profile['firstName'] ?? answers['firstName'];
        final last = profile['lastName'] ?? answers['lastName'];
        final displayName = name?.toString().trim().isNotEmpty == true
            ? name.toString().trim()
            : '${first ?? ''} ${last ?? ''}'.trim();
        results.add((name: displayName.isEmpty ? 'Guest' : displayName, timestamp: c.timestamp));
      }
      return results;
    } catch (e) {
      _log('getTop3EarliestCheckins failed: $e');
      return [];
    }
  }

  /// Combined top-3 data for dashboard. Merges with same triggers as session stats.
  Future<({
    List<({String name, DateTime timestamp})> registrations,
    List<({String name, DateTime timestamp})> checkins,
  })> getFirst3Data(String eventId) async {
    final reg = await getTop3EarliestRegistrants(eventId);
    final chk = await getTop3EarliestCheckins(eventId);
    return (registrations: reg, checkins: chk);
  }

  Stream<({
    List<({String name, DateTime timestamp})> registrations,
    List<({String name, DateTime timestamp})> checkins,
  })> watchFirst3Data(String eventId) {
    final fromGlobal = watchSummary(eventId).asyncMap((_) => getFirst3Data(eventId));
    final fromPoll = Stream.periodic(_pollInterval)
        .asyncMap((_) => getFirst3Data(eventId));
    final fromRefresh = _refreshTrigger.stream
        .asyncMap((_) => getFirst3Data(eventId));
    return _mergeStreams([fromGlobal, fromPoll, fromRefresh]);
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
