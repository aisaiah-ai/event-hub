import 'package:cloud_firestore/cloud_firestore.dart';

/// Formation signal document at events/{eventId}/formationSignals/{registrantId}
class FormationSignal {
  const FormationSignal({
    required this.eventId,
    required this.registrantId,
    this.tags = const [],
    this.updatedAt,
  });

  final String eventId;
  final String registrantId;
  final List<String> tags;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'registrantId': registrantId,
    'tags': tags,
    'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
  };

  factory FormationSignal.fromJson(Map<String, dynamic> json) {
    final updatedAt = json['updatedAt'];
    return FormationSignal(
      eventId: json['eventId'] as String? ?? '',
      registrantId: json['registrantId'] as String? ?? '',
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
    );
  }
}
