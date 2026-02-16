import 'package:cloud_firestore/cloud_firestore.dart';

/// Live aggregates at events/{eventId}/stats/overview.
/// Updated by Cloud Functions only; clients read via StreamBuilder.
/// Missing doc returns empty stats (dashboard shows skeleton/zeroes).
class EventStats {
  const EventStats({
    this.totalRegistrations = 0,
    this.totalCheckedIn = 0,
    this.earlyBirdCount = 0,
    this.firstCheckInAt,
    this.firstCheckInRegistrantId,
    this.firstEarlyBirdRegisteredAt,
    this.firstEarlyBirdRegistrantId,
    this.regionCounts = const {},
    this.ministryCounts = const {},
    this.serviceCounts = const {},
    this.sessionTotals = const {},
    this.firstSessionCheckIn = const {},
    this.top5Regions = const [],
    this.top5Ministries = const [],
    this.top5Services = const [],
    this.top5RegionOtherText = const [],
    this.checkInsPerMinute,
    this.peakCheckInMinute,
    this.peakCheckInCount,
    this.updatedAt,
  });

  final int totalRegistrations;
  final int totalCheckedIn;
  final int earlyBirdCount;
  final DateTime? firstCheckInAt;
  final String? firstCheckInRegistrantId;
  final DateTime? firstEarlyBirdRegisteredAt;
  final String? firstEarlyBirdRegistrantId;
  final Map<String, int> regionCounts;
  final Map<String, int> ministryCounts;
  final Map<String, int> serviceCounts;
  final Map<String, int> sessionTotals;
  /// sessionId -> { at: DateTime, registrantId: String }
  final Map<String, FirstSessionCheckIn> firstSessionCheckIn;
  final List<MapEntry<String, int>> top5Regions;
  final List<MapEntry<String, int>> top5Ministries;
  final List<MapEntry<String, int>> top5Services;
  final List<MapEntry<String, int>> top5RegionOtherText;
  final double? checkInsPerMinute;
  final String? peakCheckInMinute;
  final int? peakCheckInCount;
  final DateTime? updatedAt;

  double get earlyBirdPercent =>
      totalRegistrations > 0 ? (earlyBirdCount / totalRegistrations) * 100 : 0;
  double get checkInPercent =>
      totalRegistrations > 0 ? (totalCheckedIn / totalRegistrations) * 100 : 0;

  factory EventStats.fromFirestore(Map<String, dynamic>? json) {
    if (json == null) return const EventStats();
    final regionCounts = json['regionCounts'] as Map<String, dynamic>? ?? {};
    final ministryCounts = json['ministryCounts'] as Map<String, dynamic>? ?? {};
    final serviceCounts = json['serviceCounts'] as Map<String, dynamic>? ?? {};
    final sessionTotals = json['sessionTotals'] as Map<String, dynamic>? ?? {};
    final firstSessionRaw = json['firstSessionCheckIn'] as Map<String, dynamic>? ?? {};
    final top5RegionsRaw = (json['top5Regions'] as List<dynamic>?) ?? [];
    final top5MinistriesRaw = (json['top5Ministries'] as List<dynamic>?) ?? [];
    final top5ServicesRaw = (json['top5Services'] as List<dynamic>?) ?? [];
    final top5RegionOtherRaw = (json['top5RegionOtherText'] as List<dynamic>?) ?? [];

    DateTime? parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }

    List<MapEntry<String, int>> parseTop5(List<dynamic> raw) {
      return raw
          .map<MapEntry<String, int>?>((e) {
            if (e is Map && e['name'] != null && e['count'] != null) {
              final count = e['count'];
              return MapEntry(
                e['name'] as String,
                count is int ? count : (count as num).toInt(),
              );
            }
            return null;
          })
          .whereType<MapEntry<String, int>>()
          .toList();
    }

    int toInt(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse(v?.toString() ?? '0') ?? 0);

    final firstSessionCheckIn = <String, FirstSessionCheckIn>{};
    for (final e in firstSessionRaw.entries) {
      final v = e.value;
      if (v is Map && v['at'] != null && v['registrantId'] != null) {
        firstSessionCheckIn[e.key] = FirstSessionCheckIn(
          at: parseTs(v['at']),
          registrantId: v['registrantId'] as String,
        );
      }
    }

    return EventStats(
      totalRegistrations: toInt(json['totalRegistrations']),
      totalCheckedIn: toInt(json['totalCheckedIn']),
      earlyBirdCount: toInt(json['earlyBirdCount']),
      firstCheckInAt: parseTs(json['firstCheckInAt']),
      firstCheckInRegistrantId: json['firstCheckInRegistrantId'] as String?,
      firstEarlyBirdRegisteredAt: parseTs(json['firstEarlyBirdRegisteredAt']),
      firstEarlyBirdRegistrantId: json['firstEarlyBirdRegistrantId'] as String?,
      regionCounts: regionCounts.map((k, v) => MapEntry(k, toInt(v))),
      ministryCounts: ministryCounts.map((k, v) => MapEntry(k, toInt(v))),
      serviceCounts: serviceCounts.map((k, v) => MapEntry(k, toInt(v))),
      sessionTotals: sessionTotals.map((k, v) => MapEntry(k, toInt(v))),
      firstSessionCheckIn: firstSessionCheckIn,
      top5Regions: parseTop5(top5RegionsRaw),
      top5Ministries: parseTop5(top5MinistriesRaw),
      top5Services: parseTop5(top5ServicesRaw),
      top5RegionOtherText: parseTop5(top5RegionOtherRaw),
      checkInsPerMinute: (json['checkInsPerMinute'] as num?)?.toDouble(),
      peakCheckInMinute: json['peakCheckInMinute'] as String?,
      peakCheckInCount: (json['peakCheckInCount'] as num?)?.toInt(),
      updatedAt: parseTs(json['updatedAt']),
    );
  }
}

class FirstSessionCheckIn {
  const FirstSessionCheckIn({this.at, required this.registrantId});
  final DateTime? at;
  final String registrantId;
}
