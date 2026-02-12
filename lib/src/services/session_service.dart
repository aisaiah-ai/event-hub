import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_config.dart';
import '../models/session.dart';
import 'formation_signal_service.dart';
import 'registrant_service.dart';

/// Manages sessions and session attendance.
class SessionService {
  SessionService({
    FirebaseFirestore? firestore,
    RegistrantService? registrantService,
    FormationSignalService? formationSignalService,
  }) : _firestore = firestore ?? FirestoreConfig.instance,
       _registrantService =
           registrantService ?? RegistrantService(firestore: firestore),
       _formationSignalService =
           formationSignalService ??
           FormationSignalService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final RegistrantService _registrantService;
  final FormationSignalService _formationSignalService;

  String _sessionsPath(String eventId) => 'events/$eventId/sessions';
  String _attendancePath(String eventId, String sessionId) =>
      '${_sessionsPath(eventId)}/$sessionId/attendance';

  Future<List<Session>> listSessions(String eventId) async {
    final snap = await _firestore.collection(_sessionsPath(eventId)).get();
    return snap.docs.map((d) => Session.fromFirestore(d.id, d.data())).toList();
  }

  Future<Session?> getSession(String eventId, String sessionId) async {
    final snap = await _firestore
        .doc('${_sessionsPath(eventId)}/$sessionId')
        .get();
    if (!snap.exists || snap.data() == null) return null;
    return Session.fromFirestore(snap.id, snap.data()!);
  }

  /// Get session IDs this registrant has attended.
  Future<List<String>> getAttendedSessionIds(
    String eventId,
    String registrantId,
  ) async {
    final sessions = await listSessions(eventId);
    final attended = <String>[];
    for (final session in sessions) {
      final ref = _firestore.doc(
        '${_attendancePath(eventId, session.id)}/$registrantId',
      );
      final snap = await ref.get();
      if (snap.exists) attended.add(session.id);
    }
    return attended;
  }

  /// Session check-in. Requires event check-in first.
  Future<void> checkInSession(
    String eventId,
    String sessionId,
    String registrantId,
    String checkedInBy,
  ) async {
    final registrant = await _registrantService.getRegistrant(
      eventId,
      registrantId,
    );
    if (registrant == null) {
      throw StateError('Registrant not found');
    }
    if (!registrant.eventAttendance.checkedIn) {
      throw StateError('Event check-in required before session check-in');
    }

    final ref = _firestore.doc(
      '${_attendancePath(eventId, sessionId)}/$registrantId',
    );
    await ref.set({
      'checkedInAt': FieldValue.serverTimestamp(),
      'checkedInBy': checkedInBy,
    });

    await _formationSignalService.generateForRegistrant(eventId, registrantId);
  }
}
