import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_config.dart';
import '../models/registrant.dart';
import 'formation_signal_service.dart';

/// Manages registrants in Firestore.
class RegistrantService {
  RegistrantService({
    FirebaseFirestore? firestore,
    FormationSignalService? formationSignalService,
  }) : _firestore = firestore ?? FirestoreConfig.instance {
    _formationSignalService = formationSignalService ??
        FormationSignalService(
          firestore: _firestore,
          registrantService: this,
        );
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

  Future<List<Registrant>> listRegistrants(String eventId) async {
    final snap = await _firestore.collection(_registrantsPath(eventId)).get();
    return snap.docs
        .map((d) => Registrant.fromFirestore(d.id, d.data()))
        .toList();
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
  Future<void> checkInEvent(
    String eventId,
    String registrantId,
    String checkedInBy,
  ) async {
    final ref = _firestore.doc('${_registrantsPath(eventId)}/$registrantId');
    final now = DateTime.now();
    await ref.update({
      'eventAttendance': {
        'checkedIn': true,
        'checkedInAt': Timestamp.fromDate(now),
        'checkedInBy': checkedInBy,
      },
      'updatedAt': Timestamp.fromDate(now),
    });
    await _formationSignalService.generateForRegistrant(eventId, registrantId);
  }
}
