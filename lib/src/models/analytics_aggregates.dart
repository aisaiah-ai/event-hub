import 'package:cloud_firestore/cloud_firestore.dart';

/// Earliest check-in record.
class EarliestCheckin {
  const EarliestCheckin({
    required this.registrantId,
    required this.sessionId,
    required this.timestamp,
  });

  final String registrantId;
  final String sessionId;
  final DateTime timestamp;

  factory EarliestCheckin.fromFirestore(Map<String, dynamic>? json) {
    if (json == null) {
      return EarliestCheckin(
        registrantId: '',
        sessionId: '',
        timestamp: DateTime(1970),
      );
    }
    final ts = json['timestamp'];
    return EarliestCheckin(
      registrantId: json['registrantId'] as String? ?? '',
      sessionId: json['sessionId'] as String? ?? '',
      timestamp: ts is Timestamp ? ts.toDate() : DateTime(1970),
    );
  }
}

/// Earliest registration record.
class EarliestRegistration {
  const EarliestRegistration({
    required this.registrantId,
    required this.timestamp,
  });

  final String registrantId;
  final DateTime timestamp;

  factory EarliestRegistration.fromFirestore(Map<String, dynamic>? json) {
    if (json == null) {
      return EarliestRegistration(
        registrantId: '',
        timestamp: DateTime(1970),
      );
    }
    final ts = json['timestamp'];
    return EarliestRegistration(
      registrantId: json['registrantId'] as String? ?? '',
      timestamp: ts is Timestamp ? ts.toDate() : DateTime(1970),
    );
  }
}

/// Global analytics at events/{eventId}/analytics/global.
/// Updated by Cloud Functions only. Clients read for dashboard.
class GlobalAnalytics {
  const GlobalAnalytics({
    this.totalUniqueAttendees = 0,
    this.totalCheckins = 0,
    this.totalRegistrants = 0,
    this.lastUpdated,
    this.earliestCheckin,
    this.earliestRegistration,
    this.regionCounts = const {},
    this.ministryCounts = const {},
    this.hourlyCheckins = const {},
  });

  final int totalUniqueAttendees;
  final int totalCheckins;
  /// Pre-computed count of registrants (events/{eventId}/registrants). Updated by backfill + onRegistrantCreate.
  final int totalRegistrants;
  final DateTime? lastUpdated;
  final EarliestCheckin? earliestCheckin;
  final EarliestRegistration? earliestRegistration;
  final Map<String, int> regionCounts;
  final Map<String, int> ministryCounts;
  final Map<String, int> hourlyCheckins;

  /// Top 5 regions by count.
  List<MapEntry<String, int>> get top5Regions =>
      _topN(regionCounts, 5);

  /// Top 5 ministries by count.
  List<MapEntry<String, int>> get top5Ministries =>
      _topN(ministryCounts, 5);

  /// Peak hour key (YYYY-MM-DD-HH) with max check-ins.
  String? get peakHourKey {
    if (hourlyCheckins.isEmpty) return null;
    return hourlyCheckins.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  static List<MapEntry<String, int>> _topN(
    Map<String, int> map,
    int n,
  ) {
    final list = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list.take(n).toList();
  }

  GlobalAnalytics copyWith({
    int? totalUniqueAttendees,
    int? totalCheckins,
    int? totalRegistrants,
    DateTime? lastUpdated,
    EarliestCheckin? earliestCheckin,
    EarliestRegistration? earliestRegistration,
    Map<String, int>? regionCounts,
    Map<String, int>? ministryCounts,
    Map<String, int>? hourlyCheckins,
  }) {
    return GlobalAnalytics(
      totalUniqueAttendees: totalUniqueAttendees ?? this.totalUniqueAttendees,
      totalCheckins: totalCheckins ?? this.totalCheckins,
      totalRegistrants: totalRegistrants ?? this.totalRegistrants,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      earliestCheckin: earliestCheckin ?? this.earliestCheckin,
      earliestRegistration: earliestRegistration ?? this.earliestRegistration,
      regionCounts: regionCounts ?? this.regionCounts,
      ministryCounts: ministryCounts ?? this.ministryCounts,
      hourlyCheckins: hourlyCheckins ?? this.hourlyCheckins,
    );
  }

  factory GlobalAnalytics.fromFirestore(Map<String, dynamic>? json) {
    if (json == null) return const GlobalAnalytics();
    final lastUpdatedTs = json['lastUpdated'];
    final ec = json['earliestCheckin'] as Map<String, dynamic>?;
    final er = json['earliestRegistration'] as Map<String, dynamic>?;
    final rc = json['regionCounts'] as Map<String, dynamic>? ?? {};
    final mc = json['ministryCounts'] as Map<String, dynamic>? ?? {};
    final hc = json['hourlyCheckins'] as Map<String, dynamic>? ?? {};

    int toInt(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse(v?.toString() ?? '0') ?? 0);

    return GlobalAnalytics(
      totalUniqueAttendees: (json['totalUniqueAttendees'] as num?)?.toInt() ?? 0,
      totalCheckins: (json['totalCheckins'] as num?)?.toInt() ?? 0,
      totalRegistrants: (json['totalRegistrants'] as num?)?.toInt() ?? 0,
      lastUpdated: lastUpdatedTs is Timestamp ? lastUpdatedTs.toDate() : null,
      earliestCheckin: ec != null ? EarliestCheckin.fromFirestore(ec) : null,
      earliestRegistration: er != null ? EarliestRegistration.fromFirestore(er) : null,
      regionCounts: rc.map((k, v) => MapEntry(k, toInt(v))),
      ministryCounts: mc.map((k, v) => MapEntry(k, toInt(v))),
      hourlyCheckins: hc.map((k, v) => MapEntry(k, toInt(v))),
    );
  }
}

/// Per-session analytics at events/{eventId}/sessions/{sessionId}/analytics/summary.
class SessionAnalyticsSummary {
  const SessionAnalyticsSummary({
    required this.sessionId,
    required this.sessionName,
    this.attendanceCount = 0,
    this.lastUpdated,
    this.startAt,
    this.regionCounts = const {},
    this.ministryCounts = const {},
  });

  final String sessionId;
  final String sessionName;
  final int attendanceCount;
  final DateTime? lastUpdated;
  final DateTime? startAt;
  final Map<String, int> regionCounts;
  final Map<String, int> ministryCounts;

  factory SessionAnalyticsSummary.fromFirestore(
    String sessionId,
    String sessionName,
    Map<String, dynamic>? json, {
    DateTime? sessionStartAt,
  }) {
    if (json == null) {
      return SessionAnalyticsSummary(
        sessionId: sessionId,
        sessionName: sessionName,
      );
    }
    final lastUpdatedTs = json['lastUpdated'];
    final rc = json['regionCounts'] as Map<String, dynamic>? ?? {};
    final mc = json['ministryCounts'] as Map<String, dynamic>? ?? {};
    int toInt(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse(v?.toString() ?? '0') ?? 0);

    return SessionAnalyticsSummary(
      sessionId: sessionId,
      sessionName: sessionName,
      attendanceCount: (json['attendanceCount'] as num?)?.toInt() ?? 0,
      lastUpdated: lastUpdatedTs is Timestamp ? lastUpdatedTs.toDate() : null,
      startAt: sessionStartAt,
      regionCounts: rc.map((k, v) => MapEntry(k, toInt(v))),
      ministryCounts: mc.map((k, v) => MapEntry(k, toInt(v))),
    );
  }
}

/// Attendee index at events/{eventId}/attendeeIndex/{registrantId}.
/// Cloud Functions only can write. Used for unique global counting.
class AttendeeIndexEntry {
  const AttendeeIndexEntry({
    required this.firstSession,
    this.firstCheckinTime,
  });

  final String firstSession;
  final DateTime? firstCheckinTime;

  factory AttendeeIndexEntry.fromFirestore(Map<String, dynamic>? json) {
    if (json == null) return const AttendeeIndexEntry(firstSession: '');
    final ts = json['firstCheckinTime'];
    return AttendeeIndexEntry(
      firstSession: json['firstSession'] as String? ?? '',
      firstCheckinTime: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

/// Aggregation level for dashboard reporting.
enum AggregationLevel {
  perSession,
  perDay,
  entireEvent,
  custom,
}
