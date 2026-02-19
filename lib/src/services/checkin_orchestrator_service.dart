import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_config.dart';
import '../models/session.dart';
import 'formation_signal_service.dart';
import 'session_catalog_service.dart';

/// Source of check-in for analytics.
enum CheckinSource { qr, search, manual }

/// Result of check-in to a target session.
class CheckinOutcome {
  const CheckinOutcome({
    required this.didCheckIn,
    this.alreadyCheckedIn = false,
    this.session,
    this.checkedInAt,
    this.errorCode,
    this.errorMessage,
  });

  final bool didCheckIn;
  final bool alreadyCheckedIn;
  final Session? session;
  final DateTime? checkedInAt;
  final String? errorCode;
  final String? errorMessage;

  static CheckinOutcome success({required Session session, DateTime? at}) =>
      CheckinOutcome(didCheckIn: true, session: session, checkedInAt: at);

  static CheckinOutcome already() =>
      const CheckinOutcome(didCheckIn: false, alreadyCheckedIn: true);

  static CheckinOutcome failure(String code, String message) =>
      CheckinOutcome(didCheckIn: false, errorCode: code, errorMessage: message);
}

/// Single entrypoint for check-in: ensures main first, capacity in transaction, idempotent.
class CheckinOrchestratorService {
  CheckinOrchestratorService({
    FirebaseFirestore? firestore,
    SessionCatalogService? sessionCatalog,
    FormationSignalService? formationSignalService,
  })  : _firestore = firestore ?? FirestoreConfig.instance,
        _sessionCatalog = sessionCatalog ?? SessionCatalogService(firestore: firestore),
        _formationSignalService =
            formationSignalService ?? FormationSignalService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final SessionCatalogService _sessionCatalog;
  final FormationSignalService _formationSignalService;

  String _sessionsPath(String eventId) => 'events/$eventId/sessions';
  String _attendancePath(String eventId, String sessionId) =>
      '${_sessionsPath(eventId)}/$sessionId/attendance';

  /// Ensure registrant is checked in to main session (isMain=true). Idempotent.
  /// Throws on "Main check-in closed" or "Main check-in full".
  Future<void> ensureMainCheckIn({
    required String eventId,
    required String registrantId,
    required CheckinSource source,
  }) async {
    final mainSessionId = await _sessionCatalog.getMainSessionId(eventId);
    if (mainSessionId == null) {
      throw StateError(
        'No main session (isMain=true) found for event $eventId. Create one in Firestore.',
      );
    }

    final attendanceRef = _firestore
        .doc('${_attendancePath(eventId, mainSessionId)}/$registrantId');
    final existing = await attendanceRef.get();
    if (existing.exists) return;

    final sessionRef = _firestore.doc('${_sessionsPath(eventId)}/$mainSessionId');
    await _firestore.runTransaction((tx) async {
      final sessionSnap = await tx.get(sessionRef);
      if (!sessionSnap.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Main session document not found',
        );
      }
      final data = sessionSnap.data()!;
      final status = data['status'] as String? ?? 'open';
      final capacity = (data['capacity'] as num?)?.toInt() ?? 0;
      final count = (data['attendanceCount'] as num?)?.toInt() ?? 0;

      if (status != 'open') {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
          message: 'Main check-in closed',
        );
      }
      if (capacity > 0 && count >= capacity) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'resource-exhausted',
          message: 'Main check-in full',
        );
      }

      final attSnap = await tx.get(attendanceRef);
      if (attSnap.exists) return;

      tx.set(attendanceRef, _attendanceData(registrantId, source));
      tx.update(sessionRef, {
        'attendanceCount': count + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    try {
      await _formationSignalService.generateForRegistrant(eventId, registrantId);
    } catch (_) {}
  }

  /// Check in to target session. If target is not main, ensures main first. Idempotent; capacity in transaction.
  Future<CheckinOutcome> checkInToTargetSession({
    required String eventId,
    required String registrantId,
    required String targetSessionId,
    required CheckinSource source,
  }) async {
    final sessionRef =
        _firestore.doc('${_sessionsPath(eventId)}/$targetSessionId');
    final sessionSnap = await sessionRef.get();
    if (!sessionSnap.exists) {
      return CheckinOutcome.failure(
        'not-found',
        'Session not found: $targetSessionId',
      );
    }
    final session = Session.fromFirestore(sessionSnap.id, sessionSnap.data()!);

    if (!session.isMain) {
      try {
        await ensureMainCheckIn(
          eventId: eventId,
          registrantId: registrantId,
          source: source,
        );
      } on FirebaseException catch (e) {
        return CheckinOutcome.failure(
          e.code,
          e.message ?? 'Main check-in failed',
        );
      }
    }

    final attendanceRef = _firestore
        .doc('${_attendancePath(eventId, targetSessionId)}/$registrantId');
    final existingAtt = await attendanceRef.get();
    if (existingAtt.exists) {
      return CheckinOutcome.already();
    }

    try {
      Session? updatedSession;
      DateTime? checkedInAt;

      await _firestore.runTransaction((tx) async {
        final sessSnap = await tx.get(sessionRef);
        if (!sessSnap.exists) throw StateError('Session disappeared');
        final data = sessSnap.data()!;
        final status = data['status'] as String? ?? 'open';
        final capacity = (data['capacity'] as num?)?.toInt() ?? 0;
        final count = (data['attendanceCount'] as num?)?.toInt() ?? 0;

        if (status != 'open') {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'failed-precondition',
            message: 'Session closed',
          );
        }
        if (capacity > 0 && count >= capacity) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'resource-exhausted',
            message: 'Session full',
          );
        }

        final attSnap = await tx.get(attendanceRef);
        if (attSnap.exists) return;

        tx.set(attendanceRef, _attendanceData(registrantId, source));
        tx.update(sessionRef, {
          'attendanceCount': count + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      final afterSnap = await sessionRef.get();
      if (afterSnap.exists && afterSnap.data() != null) {
        updatedSession = Session.fromFirestore(
          afterSnap.id,
          afterSnap.data()!,
        );
      }
      final attSnap = await attendanceRef.get();
      if (attSnap.exists && attSnap.data() != null) {
        final d = attSnap.data()!;
        final ts = d['createdAt'] ?? d['checkedInAt'];
        checkedInAt = ts is Timestamp ? ts.toDate() : DateTime.now();
      }

      try {
        await _formationSignalService.generateForRegistrant(eventId, registrantId);
      } catch (_) {}

      return CheckinOutcome.success(
        session: updatedSession ?? session,
        at: checkedInAt,
      );
    } on FirebaseException catch (e) {
      return CheckinOutcome.failure(
        e.code,
        e.message ?? e.code,
      );
    }
  }

  Map<String, dynamic> _attendanceData(String registrantId, CheckinSource source) {
    final sourceStr = source.name;
    return {
      'registrantId': registrantId,
      'createdAt': FieldValue.serverTimestamp(),
      'checkedInAt': FieldValue.serverTimestamp(),
      'source': sourceStr,
      'checkedInBy': 'self',
    };
  }
}
