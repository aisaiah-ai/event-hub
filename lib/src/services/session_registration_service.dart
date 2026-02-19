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

/// Intent layer: pre-registered sessions per registrant.
/// Path: events/{eventId}/sessionRegistrations/{registrantId}.
/// Writes are admin/seed/server-only; client reads only (no arbitrary client writes).
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

  /// Stream of full registration doc (for reactive UI). Returns null when doc missing.
  Stream<SessionRegistration?> watchRegistration(
    String eventId,
    String registrantId,
  ) {
    return _firestore.doc(_path(eventId, registrantId)).snapshots().map((snap) {
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
    });
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

  /// Pre-registered count per session: sessionId -> number of registrants who signed up.
  /// Used for display: "Total: X. Pre-registered: Y. Checked in: Z. Remaining: X − Z."
  Future<Map<String, int>> getPreRegisteredCountsPerSession(String eventId) async {
    final snap = await _firestore
        .collection('events/$eventId/sessionRegistrations')
        .get();
    final counts = <String, int>{};
    for (final doc in snap.docs) {
      final list = doc.data()['sessionIds'];
      if (list is! List) continue;
      for (final e in list) {
        final id = e?.toString();
        if (id == null || id.isEmpty) continue;
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Set session registration for a registrant. Admin/seed/backend only — do not expose to client for arbitrary writes.
  /// Use for import, seed from CSV, or server-side sync.
  Future<void> setRegistration(
    String eventId,
    String registrantId,
    List<String> sessionIds,
  ) async {
    final ref = _firestore.doc(_path(eventId, registrantId));
    await ref.set({
      'registrantId': registrantId,
      'sessionIds': sessionIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
