import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_config.dart';
import '../models/session.dart';
import 'formation_signal_service.dart';
import 'registrant_service.dart';

// ignore: avoid_print
void _log(String msg) => print('[SessionService] $msg');

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

  /// Sessions ordered by 'order' (NLC 2026: no hardcoded lists). Requires Firestore index on (order).
  /// If index missing or collection empty, returns [].
  Future<List<Session>> getSessionsOrderedByOrder(String eventId) async {
    try {
      final snap = await _firestore
          .collection(_sessionsPath(eventId))
          .orderBy('order')
          .get();
      return snap.docs
          .map((d) => Session.fromFirestore(d.id, d.data()))
          .where((s) => s.isActive)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Active sessions only (for self-check-in session selector).
  /// For eventId nlc-2026 prefer getSessionsOrderedByOrder so order is respected.
  Future<List<Session>> getActiveSessions(String eventId) async {
    final all = await listSessions(eventId);
    return all.where((s) => s.isActive).toList();
  }

  Future<Session?> getSession(String eventId, String sessionId) async {
    final snap = await _firestore
        .doc('${_sessionsPath(eventId)}/$sessionId')
        .get();
    if (!snap.exists || snap.data() == null) return null;
    return Session.fromFirestore(snap.id, snap.data()!);
  }

  /// Whether registrant is in this session's attendance.
  Future<bool> hasSessionAttendance(
    String eventId,
    String sessionId,
    String registrantId,
  ) async {
    final ref = _firestore.doc(
      '${_attendancePath(eventId, sessionId)}/$registrantId',
    );
    final snap = await ref.get();
    return snap.exists;
  }

  /// Session-only: get attendance doc for badge + timestamp. Returns (exists, checkedInAt).
  Future<({bool exists, DateTime? checkedInAt})> getSessionAttendanceInfo(
    String eventId,
    String sessionId,
    String registrantId,
  ) async {
    final ref = _firestore.doc(
      '${_attendancePath(eventId, sessionId)}/$registrantId',
    );
    final snap = await ref.get();
    if (!snap.exists || snap.data() == null) {
      return (exists: false, checkedInAt: null);
    }
    final data = snap.data()!;
    final ts = data['checkedInAt'];
    DateTime? at;
    if (ts is Timestamp) at = ts.toDate();
    return (exists: true, checkedInAt: at);
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

  /// Session-only check-in. Writes to attendance subcollection only.
  /// Does NOT update eventAttendance. Use for session-specific QR pages.
  Future<void> checkInSessionOnly(
    String eventId,
    String sessionId,
    String registrantId,
    String checkedInBy,
  ) async {
    final path = '${_attendancePath(eventId, sessionId)}/$registrantId';
    final ref = _firestore.doc(path);
    try {
      await ref.set({
        'checkedInAt': FieldValue.serverTimestamp(),
        'checkedInBy': checkedInBy,
      }, SetOptions(merge: true));
    } catch (e, st) {
      _log('checkInSessionOnly ATTENDANCE FAILED');
      _log('  path: $path');
      _log('  database: ${FirestoreConfig.databaseId}');
      _log('  error: $e');
      _log('  stack: $st');
      rethrow;
    }
    try {
      await _formationSignalService.generateForRegistrant(eventId, registrantId);
    } catch (e, st) {
      _log('checkInSessionOnly FORMATION SIGNAL FAILED (attendance was written)');
      _log('  eventId: $eventId registrantId: $registrantId');
      _log('  database: ${FirestoreConfig.databaseId}');
      _log('  error: $e');
      _log('  stack: $st');
      rethrow;
    }
  }

  /// Session check-in. Writes attendance only (no event-level check required).
  Future<void> checkInSession(
    String eventId,
    String sessionId,
    String registrantId,
    String checkedInBy,
  ) async {
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
