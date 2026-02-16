import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../src/config/firestore_config.dart';

/// Check-in service: pure session architecture.
/// All writes go to: events/{eventId}/sessions/{sessionId}/attendance/{registrantId}.
/// No /checkins collection.
class CheckInService {
  CheckInService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirestoreConfig.instance;

  final FirebaseFirestore _db;

  /// Writes attendance doc. Idempotent: if doc exists, returns false.
  Future<bool> checkIn({
    required String eventId,
    required String sessionId,
    required String registrantId,
    required String checkedInBy,
  }) async {
    final eventRef = _db.collection('events').doc(eventId);
    final sessionRef = eventRef.collection('sessions').doc(sessionId);
    final attendanceRef = sessionRef.collection('attendance').doc(registrantId);

    // Read parent documents first; do not write to non-existent session.
    final sessionSnap = await sessionRef.get();
    if (!sessionSnap.exists) {
      // ignore: avoid_print
      print(
        '[CheckInService] checkIn ABORT: session does not exist database=${FirestoreConfig.databaseId} '
        'document=${sessionRef.path}',
      );
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'not-found',
        message: 'Session document does not exist: events/$eventId/sessions/$sessionId. Create the session in the DB first. See docs/FIRESTORE_DATA_MODEL.md.',
      );
    }

    // ignore: avoid_print
    print(
      '[CheckInService] Writing to: events/$eventId/sessions/$sessionId/attendance/$registrantId',
    );
    // ignore: avoid_print
    print(
      '[CheckInService] checkIn START database=${FirestoreConfig.databaseId} '
      'document=${attendanceRef.path} authUid=${FirebaseAuth.instance.currentUser?.uid} isAnon=${FirebaseAuth.instance.currentUser?.isAnonymous}',
    );
    try {
      final didCreate = await _db.runTransaction<bool>((tx) async {
        final existing = await tx.get(attendanceRef);
        if (existing.exists) return false;
        tx.set(attendanceRef, {
          'registrantId': registrantId,
          'checkedInAt': FieldValue.serverTimestamp(),
          'checkedInBy': checkedInBy,
        });
        return true;
      });
      // ignore: avoid_print
      print(
        didCreate
            ? '[CheckInService] checkIn SUCCESS database=${FirestoreConfig.databaseId} document=${attendanceRef.path}'
            : '[CheckInService] checkIn ALREADY_EXISTS database=${FirestoreConfig.databaseId} document=${attendanceRef.path}',
      );
      return didCreate;
    } on FirebaseException catch (e, st) {
      // ignore: avoid_print
      print(
        '[CheckInService] checkIn FAILED database=${FirestoreConfig.databaseId} document=${attendanceRef.path} code=${e.code} message=${e.message}',
      );
      // ignore: avoid_print
      print('[CheckInService] stack=$st');
      rethrow;
    } catch (e, st) {
      // ignore: avoid_print
      print(
        '[CheckInService] checkIn FAILED database=${FirestoreConfig.databaseId} document=${attendanceRef.path} type=${e.runtimeType} error=$e',
      );
      // ignore: avoid_print
      print('[CheckInService] stack=$st');
      rethrow;
    }
  }
}
