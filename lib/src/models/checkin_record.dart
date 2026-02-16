import 'package:cloud_firestore/cloud_firestore.dart';

/// Method used for check-in. Values must match Firestore rules: 'qr', 'search', 'manual'.
enum CheckinMethod { qr, search, manual }

/// Self-check-in audit record (legacy). Pure session architecture uses
/// events/{eventId}/sessions/{sessionId}/attendance/{registrantId} only.
/// Rules allow create when selfCheckinEnabled(eventId) and fields match; staff can read.
class CheckinRecord {
  const CheckinRecord({
    this.id,
    this.registrantId,
    required this.sessionId,
    required this.method,
    required this.timestamp,
    this.deviceInfo,
    this.source = 'self',
    this.manualPayload,
    this.eventId,
  });

  /// Document id when read from Firestore; null when creating.
  final String? id;

  final String? registrantId;
  final String sessionId;
  final CheckinMethod method;
  final DateTime timestamp;
  final String? deviceInfo;
  final String source;

  /// For method=manual: firstName, lastName, email, chapter, role, etc.
  final Map<String, dynamic>? manualPayload;

  /// Set when read from Firestore; optional when writing (passed to toFirestore).
  final String? eventId;

  /// Serialize for Firestore create. Must match rules: eventId, sessionId, method, source, etc.
  Map<String, dynamic> toFirestore(String eventId) => {
        'eventId': eventId,
        if (registrantId != null) 'registrantId': registrantId,
        'sessionId': sessionId,
        'method': method.name,
        'manual': method == CheckinMethod.manual,
        if (manualPayload != null && method == CheckinMethod.manual)
          'manualPayload': manualPayload,
        'timestamp': Timestamp.fromDate(timestamp),
        'createdAt': Timestamp.fromDate(timestamp),
        if (deviceInfo != null) 'deviceInfo': deviceInfo,
        'source': source,
      };

  /// Parse a checkin document from Firestore (e.g. for audit list or dashboard).
  factory CheckinRecord.fromFirestore(String id, Map<String, dynamic>? json) {
    if (json == null) {
      throw ArgumentError('CheckinRecord.fromFirestore: json is null');
    }
    final ts = json['timestamp'] ?? json['createdAt'];
    final DateTime at = ts is Timestamp ? ts.toDate() : DateTime.now();
    final methodStr = json['method'] as String? ?? 'search';
    CheckinMethod method = CheckinMethod.search;
    for (final e in CheckinMethod.values) {
      if (e.name == methodStr) {
        method = e;
        break;
      }
    }
    return CheckinRecord(
      id: id,
      eventId: json['eventId'] as String?,
      registrantId: json['registrantId'] as String?,
      sessionId: json['sessionId'] as String? ?? '',
      method: method,
      timestamp: at,
      deviceInfo: json['deviceInfo'] as String?,
      source: json['source'] as String? ?? 'self',
      manualPayload: json['manualPayload'] as Map<String, dynamic>?,
    );
  }
}
