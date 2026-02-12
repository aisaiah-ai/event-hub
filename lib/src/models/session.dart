import 'package:cloud_firestore/cloud_firestore.dart';

/// Session document at events/{eventId}/sessions/{sessionId}
class Session {
  const Session({
    required this.id,
    this.title = '',
    this.startAt,
    this.endAt,
    this.type,
  });

  final String id;
  final String title;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? type;

  Map<String, dynamic> toJson() => {
        'title': title,
        if (startAt != null) 'startAt': Timestamp.fromDate(startAt!),
        if (endAt != null) 'endAt': Timestamp.fromDate(endAt!),
        if (type != null) 'type': type,
      };

  factory Session.fromFirestore(String id, Map<String, dynamic> json) {
    final startAt = json['startAt'];
    final endAt = json['endAt'];
    return Session(
      id: id,
      title: json['title'] as String? ?? '',
      startAt: startAt is Timestamp ? startAt.toDate() : null,
      endAt: endAt is Timestamp ? endAt.toDate() : null,
      type: json['type'] as String?,
    );
  }
}
