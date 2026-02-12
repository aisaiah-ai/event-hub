import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_config.dart';
import '../models/formation_signal.dart';
import 'registrant_service.dart';
import 'schema_service.dart';
import 'session_service.dart';

/// Generates and persists formation signals from registration, attendance, and schema.
class FormationSignalService {
  FormationSignalService({
    FirebaseFirestore? firestore,
    SchemaService? schemaService,
    RegistrantService? registrantService,
    SessionService? sessionService,
  })  : _firestore = firestore ?? FirestoreConfig.instance,
        _schemaService = schemaService ?? SchemaService(firestore: firestore),
        _registrantService = registrantService ?? RegistrantService(firestore: firestore) {
    _sessionService = sessionService ??
        SessionService(
          firestore: _firestore,
          registrantService: _registrantService,
          formationSignalService: this,
        );
  }

  final FirebaseFirestore _firestore;
  final SchemaService _schemaService;
  final RegistrantService _registrantService;
  late final SessionService _sessionService;

  String _signalPath(String eventId, String registrantId) =>
      'events/$eventId/formationSignals/$registrantId';

  /// Regenerate formation signal for a registrant. Call on:
  /// - Event check-in
  /// - Session check-in
  /// - Registrant creation/update
  Future<void> generateForRegistrant(String eventId, String registrantId) async {
    final schema = await _schemaService.getSchema(eventId);
    final registrant = await _registrantService.getRegistrant(eventId, registrantId);
    if (registrant == null) return;

    final tags = <String>[];

    tags.add('event:$eventId');

    for (final field in schema?.fields ?? []) {
      if (field.formationTags.tags.isEmpty) continue;
      final value = registrant.answers[field.key] ?? registrant.profile[field.key];
      if (value != null && value.toString().isNotEmpty) {
        for (final tag in field.formationTags.tags) {
          tags.add(tag);
        }
      }
    }

    if (registrant.eventAttendance.checkedIn) {
      tags.add('event_checked_in');
    }

    final attendedSessions =
        await _sessionService.getAttendedSessionIds(eventId, registrantId);
    for (final sessionId in attendedSessions) {
      tags.add('session:$sessionId');
    }

    final signal = FormationSignal(
      eventId: eventId,
      registrantId: registrantId,
      tags: tags.toSet().toList(),
      updatedAt: DateTime.now(),
    );

    await _firestore.doc(_signalPath(eventId, registrantId)).set(signal.toJson());
  }

  /// Get formation signal for a registrant.
  Future<FormationSignal?> getSignal(String eventId, String registrantId) async {
    final snap = await _firestore.doc(_signalPath(eventId, registrantId)).get();
    if (!snap.exists || snap.data() == null) return null;
    return FormationSignal.fromJson(snap.data()!);
  }
}
