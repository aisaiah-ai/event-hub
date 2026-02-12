import 'package:cloud_firestore/cloud_firestore.dart';

/// Import mapping document at events/{eventId}/importMappings/{mappingId}
class ImportMapping {
  const ImportMapping({
    required this.id,
    required this.mapping,
    this.updatedAt,
  });

  final String id;
  final Map<String, String> mapping;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'mapping': mapping,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory ImportMapping.fromFirestore(String id, Map<String, dynamic> json) {
    final updatedAt = json['updatedAt'];
    final mapping = json['mapping'] as Map<String, dynamic>?;
    return ImportMapping(
      id: id,
      mapping: mapping?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {},
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
    );
  }
}
