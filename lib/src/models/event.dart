import 'package:cloud_firestore/cloud_firestore.dart';

/// Event document at events/{eventId}. Optional root document for event metadata.
class Event {
  const Event({
    required this.id,
    this.title = '',
    this.description = '',
    this.startAt,
    this.endAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        if (startAt != null) 'startAt': Timestamp.fromDate(startAt!),
        if (endAt != null) 'endAt': Timestamp.fromDate(endAt!),
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      };

  factory Event.fromFirestore(String id, Map<String, dynamic>? json) {
    if (json == null) return Event(id: id);
    final startAt = json['startAt'];
    final endAt = json['endAt'];
    final createdAt = json['createdAt'];
    final updatedAt = json['updatedAt'];
    return Event(
      id: id,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      startAt: startAt is Timestamp ? startAt.toDate() : null,
      endAt: endAt is Timestamp ? endAt.toDate() : null,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
    );
  }
}
