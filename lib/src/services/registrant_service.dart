import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../config/firestore_config.dart';
import '../models/registrant.dart';
import 'formation_signal_service.dart';

// ignore: avoid_print
void _log(String msg) => print('[RegistrantService] $msg');

/// Result of a quick check whether the app can read the registrants collection.
class FirestoreRegistrantReadStatus {
  const FirestoreRegistrantReadStatus({
    required this.ok,
    required this.isPermissionDenied,
    required this.databaseId,
    this.message,
  });

  final bool ok;
  final bool isPermissionDenied;
  final String databaseId;
  final String? message;

  static bool isPermissionDeniedError(Object e) {
    if (e is FirebaseException) {
      return e.code == 'permission-denied' ||
          e.code.contains('permission-denied');
    }
    return e.toString().contains('permission-denied') ||
        e.toString().contains('permission_denied');
  }
}

/// Manages registrants in Firestore.
class RegistrantService {
  RegistrantService({
    FirebaseFirestore? firestore,
    FormationSignalService? formationSignalService,
  }) : _firestore = firestore ?? FirestoreConfig.instance {
    _formationSignalService =
        formationSignalService ??
        FormationSignalService(firestore: _firestore, registrantService: this);
  }

  final FirebaseFirestore _firestore;
  late final FormationSignalService _formationSignalService;

  String _registrantsPath(String eventId) => 'events/$eventId/registrants';

  Future<Registrant?> getRegistrant(String eventId, String registrantId) async {
    final snap = await _firestore
        .doc('${_registrantsPath(eventId)}/$registrantId')
        .get();
    if (!snap.exists || snap.data() == null) return null;
    return Registrant.fromFirestore(snap.id, snap.data()!);
  }

  Stream<Registrant?> watchRegistrant(String eventId, String registrantId) {
    return _firestore
        .doc('${_registrantsPath(eventId)}/$registrantId')
        .snapshots()
        .map((snap) {
          if (!snap.exists || snap.data() == null) return null;
          return Registrant.fromFirestore(snap.id, snap.data()!);
        });
  }

  /// Search by lastNameSearchIndex (for 3000+ scale). Limit 15.
  /// Requires registrants to have lastNameSearchIndex = lastName.toLowerCase().
  Future<List<Registrant>> searchByLastNameIndex(
    String eventId,
    String query, {
    int limit = 15,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];
    final path = _registrantsPath(eventId);
    try {
      final snap = await _firestore
          .collection(path)
          .where('lastNameSearchIndex', isGreaterThanOrEqualTo: q)
          .where('lastNameSearchIndex', isLessThan: '$q\uf8ff')
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => Registrant.fromFirestore(d.id, d.data()))
          .toList();
    } catch (e) {
      _log('searchByLastNameIndex FAILED: $e');
      rethrow;
    }
  }

  /// Simple check: can we read at least one registrant? Use to surface
  /// "rules may be wrong for this database" before user searches.
  Future<FirestoreRegistrantReadStatus> checkRegistrantReadPermission(
    String eventId,
  ) async {
    final path = _registrantsPath(eventId);
    final dbId = FirestoreConfig.databaseId;
    try {
      final snap = await _firestore.collection(path).limit(1).get();
      _log('checkRegistrantReadPermission: ok, db=$dbId');
      return FirestoreRegistrantReadStatus(
        ok: true,
        isPermissionDenied: false,
        databaseId: dbId,
      );
    } catch (e) {
      final isDenied = FirestoreRegistrantReadStatus.isPermissionDeniedError(e);
      _log('checkRegistrantReadPermission: failed isPermissionDenied=$isDenied, db=$dbId, e=$e');
      return FirestoreRegistrantReadStatus(
        ok: false,
        isPermissionDenied: isDenied,
        databaseId: dbId,
        message: e.toString(),
      );
    }
  }

  Future<List<Registrant>> listRegistrants(String eventId) async {
    final path = _registrantsPath(eventId);
    _log('listRegistrants: path=$path, db=${FirestoreConfig.databaseId}');
    try {
      final snap = await _firestore.collection(path).get();
      _log('listRegistrants: got ${snap.docs.length} docs');
      return snap.docs
          .map((d) => Registrant.fromFirestore(d.id, d.data()))
          .toList();
    } catch (e, st) {
      _log('listRegistrants FAILED: $e');
      _log('stackTrace: $st');
      _log('TROUBLESHOOTING: If permission-denied, check Firebase Console → App Check → Firestore. Disable enforcement or add ReCaptchaV3Provider for web.');
      rethrow;
    }
  }

  /// Create or update registrant. Triggers formation signal generation.
  Future<String> saveRegistrant(
    String eventId,
    Registrant registrant, {
    bool triggerFormation = true,
  }) async {
    final ref = registrant.id.isEmpty
        ? _firestore.collection(_registrantsPath(eventId)).doc()
        : _firestore.doc('${_registrantsPath(eventId)}/${registrant.id}');

    final id = ref.id;
    final now = DateTime.now();
    final data = registrant.toJson();
    data['updatedAt'] = Timestamp.fromDate(now);
    if (registrant.id.isEmpty) {
      data['createdAt'] = Timestamp.fromDate(now);
    }

    await ref.set(data, SetOptions(merge: true));

    if (triggerFormation) {
      await _formationSignalService.generateForRegistrant(eventId, id);
    }
    return id;
  }

  /// Event check-in. Updates eventAttendance and triggers formation signal.
  /// Cloud Function onUpdate will aggregate stats when checkedInAt goes null -> set.
  /// [checkInSource] must be 'QR' | 'SEARCH' | 'MANUAL' for analytics.
  Future<void> checkInEvent(
    String eventId,
    String registrantId,
    String checkedInBy, {
    String checkInSource = 'SEARCH',
    String? sessionId,
  }) async {
    final path = '${_registrantsPath(eventId)}/$registrantId';
    final ref = _firestore.doc(path);
    final now = DateTime.now();
    final updates = <String, dynamic>{
      'eventAttendance': {
        'checkedIn': true,
        'checkedInAt': Timestamp.fromDate(now),
        'checkedInBy': checkedInBy,
      },
      'checkInSource': checkInSource,
      'updatedAt': Timestamp.fromDate(now),
    };
    if (sessionId != null) {
      updates['sessionsCheckedIn.$sessionId'] = Timestamp.fromDate(now);
    }

    try {
      await ref.update(updates);
    } catch (e, st) {
      _log('checkInEvent REGISTRANT UPDATE FAILED');
      _log('  path: $path');
      _log('  database: ${FirestoreConfig.databaseId}');
      _log('  error: $e');
      _log('  stack: $st');
      rethrow;
    }

    try {
      await _formationSignalService.generateForRegistrant(eventId, registrantId);
    } catch (e, st) {
      _log('checkInEvent FORMATION SIGNAL FAILED (registrant was updated)');
      _log('  eventId: $eventId registrantId: $registrantId');
      _log('  database: ${FirestoreConfig.databaseId}');
      _log('  error: $e');
      _log('  stack: $st');
      rethrow;
    }
  }
}
