import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import '../config/firestore_config.dart';
import '../core/utils/csv_exporter.dart';
import '../core/utils/download_helper.dart';
import '../core/utils/excel_exporter.dart';
import '../models/analytics_aggregates.dart';
import 'checkin_analytics_service.dart';
import 'session_service.dart';

/// Raw attendance row for CSV export.
class RawAttendanceRow {
  const RawAttendanceRow({
    required this.firstName,
    required this.lastName,
    this.region = '',
    this.regionOtherText = '',
    this.ministryMembership = '',
    this.service = '',
    required this.sessionName,
    required this.checkInTimestamp,
    this.checkedInBy = '',
  });

  final String firstName;
  final String lastName;
  final String region;
  final String regionOtherText;
  final String ministryMembership;
  final String service;
  final String sessionName;
  final DateTime checkInTimestamp;
  final String checkedInBy;

  List<String> toCsvRow() => [
        firstName,
        lastName,
        region,
        regionOtherText,
        ministryMembership,
        service,
        sessionName,
        DateFormat('yyyy-MM-dd HH:mm:ss').format(checkInTimestamp),
        checkedInBy,
      ];
}

/// Aggregated row for CSV export.
class AggregatedRow {
  const AggregatedRow({
    required this.session,
    required this.attendance,
    this.percentOfTotal,
  });

  final String session;
  final int attendance;
  final double? percentOfTotal;

  List<String> toCsvRow() => [
        session,
        '$attendance',
        percentOfTotal != null ? '${percentOfTotal!.toStringAsFixed(1)}%' : '',
      ];
}

/// Export service for raw and aggregated attendance reports.
/// Raw export scans attendance (admin only, may be slow for large events).
/// Aggregated export uses analytics docs only.
class AttendanceExportService {
  AttendanceExportService({
    FirebaseFirestore? firestore,
    SessionService? sessionService,
  })  : _firestore = firestore ?? FirestoreConfig.instance,
        _sessionService =
            sessionService ?? SessionService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final SessionService _sessionService;

  static const int _batchSize = 500;
  static const List<String> _rawHeaders = [
    'First Name',
    'Last Name',
    'Region',
    'Region - Other Text',
    'Ministry Membership',
    'Service',
    'Session Name',
    'Check-In Timestamp',
    'Checked In By',
  ];
  static const List<String> _aggregatedHeaders = [
    'Session',
    'Attendance',
    '% of Total',
  ];
  static const List<String> _eventSummaryHeaders = [
    'Metric',
    'Value',
  ];

  /// Export raw attendance. Scans attendance collections, joins with registrants.
  /// Uses batched pagination for >5000 docs.
  Future<String> exportRawCsv(String eventId, {String eventSlug = 'nlc-2026'}) async {
    final sessions = await _sessionService.getSessionsOrderedByOrder(eventId);
    final sessionNames = {for (final s in sessions) s.id: s.displayName};
    final rows = <List<String>>[_rawHeaders];

    for (final session in sessions) {
      Query<Map<String, dynamic>> query = _firestore
          .collection('events/$eventId/sessions/${session.id}/attendance')
          .orderBy('checkedInAt');

      QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc;
      while (true) {
        Query<Map<String, dynamic>> q = lastDoc == null
            ? query.limit(_batchSize)
            : query.startAfterDocument(lastDoc).limit(_batchSize);
        final snap = await q.get();
        if (snap.docs.isEmpty) break;

        for (final doc in snap.docs) {
          final data = doc.data();
          final registrantId = doc.id;
          final checkedInAt = (data['checkedInAt'] as Timestamp?)?.toDate();
          final checkedInBy = data['checkedInBy'] as String? ?? '';

          final registrant = await _firestore
              .doc('events/$eventId/registrants/$registrantId')
              .get();
          final rData = registrant.data() ?? {};
          final profile = rData['profile'] as Map<String, dynamic>? ?? {};
          final answers = rData['answers'] as Map<String, dynamic>? ?? {};
          final all = {...profile, ...answers};

          String get(String k) => (all[k]?.toString() ?? '').trim();
          String getFirst(String a, String b) {
            final va = get(a);
            return va.isNotEmpty ? va : get(b);
          }

          rows.add(RawAttendanceRow(
            firstName: get('firstName'),
            lastName: get('lastName'),
            region: getFirst('region', 'regionMembership'),
            regionOtherText: getFirst('regionOtherText', 'regionOther'),
            ministryMembership: getFirst('ministryMembership', 'ministry'),
            service: get('service'),
            sessionName: sessionNames[session.id] ?? session.id,
            checkInTimestamp: checkedInAt ?? DateTime.now(),
            checkedInBy: checkedInBy,
          ).toCsvRow());
        }

        if (snap.docs.length < _batchSize) break;
        lastDoc = snap.docs.last;
      }
    }

    return toCsv(rows);
  }

  /// Export aggregated report based on selected sessions and level.
  Future<String> exportAggregatedCsv(
    String eventId, {
    required List<SessionCheckinStat> sessionStats,
    required GlobalAnalytics global,
    AggregationLevel level = AggregationLevel.perSession,
    List<String>? customSessionIds,
    String eventSlug = 'nlc-2026',
  }) async {
    final rows = <List<String>>[];

    switch (level) {
      case AggregationLevel.perSession:
        rows.add(_aggregatedHeaders);
        final total = sessionStats.fold<int>(
            0, (s, x) => s + x.checkInCount);
        for (final s in sessionStats) {
          final pct = total > 0 ? (s.checkInCount / total) * 100 : null;
          rows.add(AggregatedRow(
            session: s.name,
            attendance: s.checkInCount,
            percentOfTotal: pct,
          ).toCsvRow());
        }
        break;

      case AggregationLevel.entireEvent:
        rows.add(_eventSummaryHeaders);
        rows.add(['Total Unique Attendees', '${global.totalUniqueAttendees}']);
        rows.add(['Total Check-Ins', '${global.totalCheckins}']);
        if (global.earliestCheckin != null && global.earliestCheckin!.registrantId.isNotEmpty) {
          rows.add(['Earliest Check-in', DateFormat.yMd().add_jm().format(global.earliestCheckin!.timestamp)]);
        }
        if (global.earliestRegistration != null && global.earliestRegistration!.registrantId.isNotEmpty) {
          rows.add(['Earliest Registration', DateFormat.yMd().add_jm().format(global.earliestRegistration!.timestamp)]);
        }
        if (global.peakHourKey != null) {
          rows.add(['Peak Hour', global.peakHourKey!]);
        }
        break;

      case AggregationLevel.custom:
        rows.add(_aggregatedHeaders);
        final selected = customSessionIds != null
            ? sessionStats
                .where((s) => customSessionIds.contains(s.sessionId))
                .toList()
            : sessionStats;
        final total = selected.fold<int>(
            0, (s, x) => s + x.checkInCount);
        for (final s in selected) {
          final pct = total > 0 ? (s.checkInCount / total) * 100 : null;
          rows.add(AggregatedRow(
            session: s.name,
            attendance: s.checkInCount,
            percentOfTotal: pct,
          ).toCsvRow());
        }
        break;

      case AggregationLevel.perDay:
        rows.add(_aggregatedHeaders);
        if (global.hourlyCheckins.isNotEmpty) {
          final byDay = <String, int>{};
          for (final e in global.hourlyCheckins.entries) {
            final dateKey = e.key.length >= 10 ? e.key.substring(0, 10) : e.key;
            byDay[dateKey] = (byDay[dateKey] ?? 0) + e.value;
          }
          final sortedDays = byDay.keys.toList()..sort();
          final grandTotal = global.totalCheckins;
          for (final day in sortedDays) {
            final dayTotal = byDay[day]!;
            final pct = grandTotal > 0 ? (dayTotal / grandTotal) * 100 : null;
            rows.add(AggregatedRow(
              session: day,
              attendance: dayTotal,
              percentOfTotal: pct,
            ).toCsvRow());
          }
        } else {
          final byDay = <String, List<SessionCheckinStat>>{};
          for (final s in sessionStats) {
            final key = s.startAt != null
                ? DateFormat('yyyy-MM-dd').format(s.startAt!)
                : 'Unknown';
            byDay.putIfAbsent(key, () => []).add(s);
          }
          final sortedDays = byDay.keys.toList()..sort();
          final grandTotal = sessionStats.fold<int>(0, (s, x) => s + x.checkInCount);
          for (final day in sortedDays) {
            final sess = byDay[day]!;
            final dayTotal = sess.fold<int>(0, (a, x) => a + x.checkInCount);
            final pct = grandTotal > 0 ? (dayTotal / grandTotal) * 100 : null;
            rows.add(AggregatedRow(
              session: day,
              attendance: dayTotal,
              percentOfTotal: pct,
            ).toCsvRow());
          }
        }
        break;
    }

    return toCsv(rows);
  }

  /// Trigger browser download of CSV file.
  Future<bool> downloadCsv(String filename, String csvContent) async {
    return downloadFile(filename, csvContent);
  }

  /// Full flow: generate raw CSV and download.
  Future<bool> exportAndDownloadRaw(
    String eventId, {
    String eventSlug = 'nlc-2026',
  }) async {
    final csv = await exportRawCsv(eventId, eventSlug: eventSlug);
    final filename = csvFilename(eventSlug, 'attendance_raw');
    return downloadCsv(filename, csv);
  }

  /// Export combined Excel (5 sheets: Summary, Regions, Ministries, Hourly, Sessions + Raw).
  Future<bool> exportAndDownloadExcel(
    String eventId, {
    required List<SessionCheckinStat> sessionStats,
    required GlobalAnalytics global,
    AggregationLevel level = AggregationLevel.perSession,
    String eventSlug = 'nlc-2026',
  }) async {
    final summaryRows = <List<String>>[
      ['Metric', 'Value'],
      ['Total Unique Attendees', '${global.totalUniqueAttendees}'],
      ['Total Check-Ins', '${global.totalCheckins}'],
    ];
    if (global.earliestCheckin != null && global.earliestCheckin!.registrantId.isNotEmpty) {
      summaryRows.add(['Earliest Check-in', DateFormat.yMd().add_jm().format(global.earliestCheckin!.timestamp)]);
    }
    if (global.earliestRegistration != null && global.earliestRegistration!.registrantId.isNotEmpty) {
      summaryRows.add(['Earliest Registration', DateFormat.yMd().add_jm().format(global.earliestRegistration!.timestamp)]);
    }
    if (global.peakHourKey != null) {
      summaryRows.add(['Peak Hour', global.peakHourKey!]);
    }

    final regionRows = <List<String>>[['Region', 'Count']];
    for (final e in global.top5Regions) {
      regionRows.add([e.key, '${e.value}']);
    }

    final ministryRows = <List<String>>[['Ministry', 'Count']];
    for (final e in global.top5Ministries) {
      ministryRows.add([e.key, '${e.value}']);
    }

    final hourlyRows = <List<String>>[['Hour', 'Count']];
    final sortedHourly = global.hourlyCheckins.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final e in sortedHourly) {
      hourlyRows.add([e.key, '${e.value}']);
    }

    final sessionRows = <List<String>>[_aggregatedHeaders];
    final total = sessionStats.fold<int>(0, (s, x) => s + x.checkInCount);
    for (final s in sessionStats) {
      final pct = total > 0 ? (s.checkInCount / total) * 100 : null;
      sessionRows.add(AggregatedRow(
        session: s.name,
        attendance: s.checkInCount,
        percentOfTotal: pct,
      ).toCsvRow());
    }

    final rawCsv = await exportRawCsv(eventId, eventSlug: eventSlug);
    final rawRowsParsed =
        const CsvToListConverter().convert(rawCsv).cast<List<dynamic>>();
    List<String> toStringList(List<dynamic> row) =>
        row.map((e) => e?.toString() ?? '').toList();
    final rawRows = rawRowsParsed.map(toStringList).toList();
    final rawData = rawRows.length > 1 ? rawRows.sublist(1) : <List<String>>[];

    final bytes = createAttendanceExcelFull(
      summaryRows: summaryRows,
      regionRows: regionRows,
      ministryRows: ministryRows,
      hourlyRows: hourlyRows,
      sessionRows: sessionRows,
      rawRows: rawData,
      rawHeaders: _rawHeaders,
    );
    final filename =
        csvFilename(eventSlug, 'attendance').replaceAll('.csv', '.xlsx');
    return downloadBytes(filename, bytes);
  }

  /// Full flow: generate aggregated CSV and download.
  Future<bool> exportAndDownloadAggregated(
    String eventId, {
    required List<SessionCheckinStat> sessionStats,
    required GlobalAnalytics global,
    AggregationLevel level = AggregationLevel.perSession,
    List<String>? customSessionIds,
    String eventSlug = 'nlc-2026',
  }) async {
    final csv = await exportAggregatedCsv(
      eventId,
      sessionStats: sessionStats,
      global: global,
      level: level,
      customSessionIds: customSessionIds,
      eventSlug: eventSlug,
    );
    final filename = csvFilename(eventSlug, 'attendance_aggregated');
    return downloadCsv(filename, csv);
  }
}
