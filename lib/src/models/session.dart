import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

  final String id;
  final String title;
  /// Display name (spec); falls back to title.
  final String? name;
  /// Short code (e.g. "S1", "Day1").
  final String? code;
  /// Whether session accepts check-ins.
  final bool isActive;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? type;
  final String? location;
  final int? order;

  String get displayName => name ?? title;

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
  };

  factory Session.fromFirestore(String id, Map<String, dynamic> json) {
    final startAt = json['startAt'];
    final endAt = json['endAt'];
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
    );
  }
}
