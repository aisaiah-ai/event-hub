import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_config.dart';
import '../models/registrant.dart';
import '../models/registrant_source.dart';
import '../models/registration_schema.dart';
import '../models/role_override.dart';
import 'csv_parser.dart';
import 'registrant_service.dart';
import 'schema_service.dart';

/// Result of parsing a CSV row.
class CsvRowResult {
  const CsvRowResult({
    required this.values,
    required this.warnings,
  });

  final Map<String, dynamic> values;
  final List<String> warnings;
}

/// CSV header to schema key mapping.
typedef HeaderMapping = Map<String, String>;

/// Parses CSV and imports registrants with schema mapping.
class CsvImportService {
  CsvImportService({
    FirebaseFirestore? firestore,
    SchemaService? schemaService,
    RegistrantService? registrantService,
  })  : _firestore = firestore ?? FirestoreConfig.instance,
        _schemaService = schemaService ?? SchemaService(firestore: firestore),
        _registrantService =
            registrantService ?? RegistrantService(firestore: firestore);

  static const _parser = CsvParser();

  final FirebaseFirestore _firestore;
  final SchemaService _schemaService;
  final RegistrantService _registrantService;

  String _mappingsPath(String eventId) => 'events/$eventId/importMappings';

  /// Parse CSV content into list of row maps (header -> value).
  List<Map<String, String>> parseCsv(String csvContent) =>
      _parser.parseCsv(csvContent);

  /// Auto-map CSV headers to schema keys (case-insensitive match).
  HeaderMapping autoMapHeaders(
    List<String> csvHeaders,
    RegistrationSchema schema,
  ) =>
      _parser.autoMapHeaders(csvHeaders, schema);

  /// Parse a single row with mapping and schema validation.
  CsvRowResult parseRow(
    Map<String, String> row,
    HeaderMapping mapping,
    RegistrationSchema schema, {
    UserRole validationRole = UserRole.admin,
  }) {
    final values = <String, dynamic>{};
    final warnings = <String>[];

    for (final entry in mapping.entries) {
      final csvHeader = entry.key;
      final schemaKey = entry.value;
      final raw = row[csvHeader]?.trim() ?? '';
      if (raw.isEmpty) continue;

      final field = schema.getFieldByKey(schemaKey);
      if (field == null) {
        values[schemaKey] = raw;
        continue;
      }

      dynamic value = raw;
      if (field.type.name == 'number') {
        value = num.tryParse(raw) ?? raw;
      } else if (field.type.name == 'checkbox') {
        value = ['1', 'true', 'yes', 'y'].contains(raw.toLowerCase());
      }

      if (field.required && (value == null || value.toString().isEmpty)) {
        warnings.add('Missing required: ${field.label}');
      }
      values[schemaKey] = value;
    }

    for (final field in schema.fields) {
      if (field.required && !values.containsKey(field.key)) {
        final canBypass = schema.roleOverrides.allowMissingRequired(validationRole);
        if (canBypass) {
          warnings.add('Missing required (admin bypass): ${field.label}');
        }
      }
    }

    return CsvRowResult(values: values, warnings: warnings);
  }

  /// Deterministic registrant ID from row values.
  String deterministicId(Map<String, dynamic> values, List<String> keyFields) =>
      _parser.deterministicId(values, keyFields);

  /// Import rows as registrants.
  Future<CsvImportResult> import(
    String eventId,
    List<Map<String, String>> rows,
    HeaderMapping mapping, {
    List<String> idKeyFields = const ['email', 'fullName', 'name'],
  }) async {
    final schema = await _schemaService.getSchema(eventId);
    if (schema == null) {
      throw StateError('Schema not found for event $eventId');
    }

    var imported = 0;
    var skipped = 0;
    final errors = <String>[];

    for (var i = 0; i < rows.length; i++) {
      final result = parseRow(rows[i], mapping, schema);
      final profile = <String, dynamic>{};
      final answers = <String, dynamic>{};

      for (final entry in result.values.entries) {
        final field = schema.getFieldByKey(entry.key);
        if (field?.systemField != null) {
          profile[entry.key] = entry.value;
        } else {
          answers[entry.key] = entry.value;
        }
      }

      final id = deterministicId(
        result.values,
        idKeyFields.where((k) => result.values.containsKey(k)).toList(),
      );

      final registrant = Registrant(
        id: id,
        profile: profile,
        answers: answers,
        source: RegistrantSource.import,
        flags: RegistrantFlags(
          hasValidationWarnings: result.warnings.isNotEmpty,
          validationWarnings: result.warnings,
        ),
        registeredAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      try {
        await _registrantService.saveRegistrant(eventId, registrant);
        imported++;
      } catch (e) {
        skipped++;
        errors.add('Row ${i + 2}: $e');
      }
    }

    await _saveMapping(eventId, mapping);

    return CsvImportResult(
      imported: imported,
      skipped: skipped,
      errors: errors,
    );
  }

  Future<void> _saveMapping(String eventId, HeaderMapping mapping) async {
    await _firestore.collection(_mappingsPath(eventId)).add({
      'mapping': mapping,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<HeaderMapping>> getSavedMappings(String eventId) async {
    final snap = await _firestore
        .collection(_mappingsPath(eventId))
        .orderBy('updatedAt', descending: true)
        .limit(5)
        .get();
    return snap.docs
        .map((d) =>
            Map<String, String>.from(
              (d.data()['mapping'] as Map?)?.map(
                (k, v) => MapEntry(k.toString(), v.toString()),
              ) ?? {},
            ))
        .toList();
  }
}

class CsvImportResult {
  const CsvImportResult({
    required this.imported,
    required this.skipped,
    this.errors = const [],
  });

  final int imported;
  final int skipped;
  final List<String> errors;
}
