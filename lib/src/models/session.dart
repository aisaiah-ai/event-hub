import 'package:cloud_firestore/cloud_firestore.dart';

/// Session status for capacity/availability.
enum SessionStatus { open, closed }

/// Session document at events/{eventId}/sessions/{sessionId}
class Session {
  const Session({
    required this.id,
    this.title = '',
    this.name,
    this.code,
    this.isActive = true,
    this.startAt,
    this.endAt,
    this.type,
    this.location,
    this.order,
    this.capacity = 0,
    this.attendanceCount = 0,
    this.colorHex,
    this.isMain = false,
    this.status = SessionStatus.open,
    this.updatedAt,
  });

  final String id;
  final String title;
  /// Display name (spec); falls back to title.
  final String? name;
  /// Short code (e.g. "S1", "Day1").
  final String? code;
  /// Whether session accepts check-ins (legacy; also consider status).
  final bool isActive;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? type;
  final String? location;
  final int? order;
  /// Hard capacity; 0 means no limit.
  final int capacity;
  /// Current checked-in count; authoritative for capacity gating.
  final int attendanceCount;
  /// Hex color for UI (e.g. "#D4A017").
  final String? colorHex;
  /// True for Main Check-In session only.
  final bool isMain;
  final SessionStatus status;
  final DateTime? updatedAt;

  String get displayName => name ?? title;

  /// Remaining seats (capacity - attendanceCount). Negative or zero when full/unlimited.
  int get remainingSeats =>
      capacity > 0 ? (capacity - attendanceCount).clamp(0, 0x7FFFFFFF) : 0x7FFFFFFF;

  /// Session is available: open and not full.
  bool get isAvailable =>
      status == SessionStatus.open &&
      (capacity <= 0 || attendanceCount < capacity);

  Map<String, dynamic> toJson() => {
        'title': title,
        if (name != null) 'name': name,
        if (code != null) 'code': code,
        'isActive': isActive,
        if (startAt != null) 'startAt': Timestamp.fromDate(startAt!),
        if (endAt != null) 'endAt': Timestamp.fromDate(endAt!),
        if (type != null) 'type': type,
        if (location != null) 'location': location,
        if (order != null) 'order': order,
        'capacity': capacity,
        'attendanceCount': attendanceCount,
        if (colorHex != null) 'colorHex': colorHex,
        'isMain': isMain,
        'status': status.name,
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      };

  factory Session.fromFirestore(String id, Map<String, dynamic> json) {
    final startAt = json['startAt'];
    final endAt = json['endAt'];
    final updatedAt = json['updatedAt'];
    final statusStr = json['status'] as String?;
    SessionStatus status = SessionStatus.open;
    if (statusStr == 'closed') status = SessionStatus.closed;

    return Session(
      id: id,
      title: json['title'] as String? ?? (json['name'] as String? ?? ''),
      name: json['name'] as String?,
      code: json['code'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      startAt: startAt is Timestamp ? startAt.toDate() : null,
      endAt: endAt is Timestamp ? endAt.toDate() : null,
      type: json['type'] as String?,
      location: json['location'] as String?,
      order: (json['order'] as num?)?.toInt(),
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      attendanceCount: (json['attendanceCount'] as num?)?.toInt() ?? 0,
      colorHex: json['colorHex'] as String?,
      isMain: json['isMain'] as bool? ?? false,
      status: status,
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
    );
  }
}
