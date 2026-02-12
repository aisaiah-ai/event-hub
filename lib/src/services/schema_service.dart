import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_config.dart';
import '../models/registration_schema.dart';

/// Loads and saves registration schema from Firestore.
class SchemaService {
  SchemaService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirestoreConfig.instance;

  final FirebaseFirestore _firestore;

  String _schemaPath(String eventId) => 'events/$eventId/schemas/registration';

  /// Load registration schema for an event.
  Future<RegistrationSchema?> getSchema(String eventId) async {
    final ref = _firestore.doc(_schemaPath(eventId));
    final snapshot = await ref.get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return RegistrationSchema.fromJson(snapshot.data()!);
  }

  /// Stream schema changes.
  Stream<RegistrationSchema?> watchSchema(String eventId) {
    return _firestore.doc(_schemaPath(eventId)).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return RegistrationSchema.fromJson(snap.data()!);
    });
  }

  /// Save schema and increment version.
  Future<void> saveSchema(String eventId, RegistrationSchema schema) async {
    final ref = _firestore.doc(_schemaPath(eventId));
    final now = DateTime.now();
    final updated = schema.copyWith(
      version: schema.version + 1,
      updatedAt: now,
    );
    await ref.set(updated.toJson(), SetOptions(merge: true));
  }

  /// Create initial schema if none exists.
  Future<void> createInitialSchema(String eventId) async {
    final existing = await getSchema(eventId);
    if (existing != null) return;
    await saveSchema(
      eventId,
      RegistrationSchema(version: 0, updatedAt: DateTime.now(), fields: []),
    );
  }
}
