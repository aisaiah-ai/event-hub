import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_config.dart';

/// Pre-registration: which sessions a registrant is registered to.
class SessionRegistration {
  const SessionRegistration({
    required this.registrantId,
    required this.sessionIds,
    this.updatedAt,
  });

  final String registrantId;
  final List<String> sessionIds;
  final DateTime? updatedAt;
}

/// Read-only service for events/{eventId}/sessionRegistrations/{registrantId}.
class SessionRegistrationService {
  SessionRegistrationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirestoreConfig.instance;

  final FirebaseFirestore _firestore;

  String _path(String eventId, String registrantId) =>
      'events/$eventId/sessionRegistrations/$registrantId';

  /// Get pre-registered session IDs for a registrant. Returns empty list if doc missing.
  Future<List<String>> getRegistrantSessionRegistration(
    String eventId,
    String registrantId,
  ) async {
    final ref = _firestore.doc(_path(eventId, registrantId));
    final snap = await ref.get();
    if (!snap.exists || snap.data() == null) return [];
    final data = snap.data()!;
    final list = data['sessionIds'];
    if (list is! List) return [];
    return list
        .map((e) => e?.toString())
        .where((e) => e != null && e.isNotEmpty)
        .cast<String>()
        .toList();
  }

  /// Full registration doc if needed.
  Future<SessionRegistration?> getRegistration(
    String eventId,
    String registrantId,
  ) async {
    final ref = _firestore.doc(_path(eventId, registrantId));
    final snap = await ref.get();
    if (!snap.exists || snap.data() == null) return null;
    final data = snap.data()!;
    final list = data['sessionIds'];
    final sessionIds = list is List
        ? list
            .map((e) => e?.toString())
            .where((e) => e != null && e.isNotEmpty)
            .cast<String>()
            .toList()
        : <String>[];
    final updatedAt = data['updatedAt'];
    return SessionRegistration(
      registrantId: registrantId,
      sessionIds: sessionIds,
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
    );
  }

  /// Stream of session IDs for a registrant (for reactive UI).
  Stream<List<String>> watchRegistrantSessionRegistration(
    String eventId,
    String registrantId,
  ) {
    return _firestore.doc(_path(eventId, registrantId)).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return <String>[];
      final list = snap.data()!['sessionIds'];
      if (list is! List) return <String>[];
      return list
          .map((e) => e?.toString())
          .where((e) => e != null && e.isNotEmpty)
          .cast<String>()
          .toList();
    });
  }
}
