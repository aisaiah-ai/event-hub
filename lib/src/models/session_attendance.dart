import 'package:cloud_firestore/cloud_firestore.dart';

/// Session attendance document at events/{eventId}/sessions/{sessionId}/attendance/{registrantId}
class SessionAttendance {
  const SessionAttendance({
    required this.registrantId,
    this.checkedInAt,
    this.checkedInBy,
  });

  final String registrantId;
  final DateTime? checkedInAt;
  final String? checkedInBy;

  Map<String, dynamic> toJson() => {
        if (checkedInAt != null) 'checkedInAt': Timestamp.fromDate(checkedInAt!),
        if (checkedInBy != null) 'checkedInBy': checkedInBy,
      };

  factory SessionAttendance.fromFirestore(String registrantId, Map<String, dynamic>? json) {
    if (json == null) return SessionAttendance(registrantId: registrantId);
    final checkedInAt = json['checkedInAt'];
    return SessionAttendance(
      registrantId: registrantId,
      checkedInAt: checkedInAt is Timestamp ? checkedInAt.toDate() : null,
      checkedInBy: json['checkedInBy'] as String?,
    );
  }
}
