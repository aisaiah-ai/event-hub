// ignore_for_file: avoid_print
/// Seeds NLC registrants from Excel/CSV to Firebase dev database.
/// Hashes all PII (names, email, phone, address, etc.) before storing.

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

import '../config/firestore_config.dart';

const eventId = 'nlc-2026';

/// PII fields to hash (case-insensitive header match).
const _piiKeys = [
  'firstname',
  'first_name',
  'lastname',
  'last_name',
  'fullname',
  'full_name',
  'name',
  'email',
  'phone',
  'mobile',
  'address',
  'city',
  'state',
  'zip',
  'country',
  'chapter',
  'unit',
  'affiliation',
];

String _hashPii(String value) {
  if (value.trim().isEmpty) return '';
  final bytes = utf8.encode(value.trim().toLowerCase());
  final digest = sha256.convert(bytes);
  return digest.toString().substring(0, 16);
}

String _normalizeKey(String k) =>
    k.toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '_');

bool _isPii(String key) {
  final n = _normalizeKey(key);
  return _piiKeys.any((p) => n == p || n.contains(p));
}

String _toSchemaKey(String header) {
  final n = _normalizeKey(header);
  const map = {
    'firstname': 'firstName',
    'first_name': 'firstName',
    'lastname': 'lastName',
    'last_name': 'lastName',
    'fullname': 'fullName',
    'full_name': 'fullName',
    'name': 'name',
    'email': 'email',
    'phone': 'phone',
    'mobile': 'phone',
    'cfcid': 'cfcId',
    'cfc_id': 'cfcId',
    'chapter': 'unit',
    'unit': 'unit',
    'role': 'role',
    'affiliation': 'unit',
    'region': 'region',
    'region_membership': 'regionMembership',
    'regionmembership': 'regionMembership',
    'ministry': 'ministry',
    'ministry_membership': 'ministryMembership',
    'ministrymembership': 'ministryMembership',
    // NLC main export columns (Registrant - Person's Name - First Name, etc.)
    'registrant_person_s_name_first_name': 'firstName',
    'registrant_person_s_name_last_name': 'lastName',
    'registrant_email': 'email',
    'registrant_phone_number': 'phone',
    'region_other_text': 'regionOther',
  };
  return map[n] ?? n;
}

String _registrantId(int index, Map<String, dynamic> row) {
  // Use CSV 'id' column when present (e.g. nlc_main_clean.csv has nlc_xxx ids).
  final id = row['id']?.toString().trim();
  if (id != null && id.isNotEmpty) return id;

  final parts = <String>[];
  for (final k in ['email', 'cfcId', 'firstName', 'lastName', 'name']) {
    final v = row[k]?.toString();
    if (v != null && v.isNotEmpty) parts.add(v);
  }
  if (parts.isEmpty) parts.add('row_$index');
  final input = parts.join('|');
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString().substring(0, 20);
}

/// Session column (CSV header) -> Firestore session ID for NLC dialogue sessions.
const _sessionColumnToId = {
  'export_Gender_Identity_Dialogue': 'gender-ideology-dialogue',
  'export_Contraception_Dialogue': 'contraception-ivf-abortion-dialogue',
  'export_Immigration_Dialogue': 'immigration-dialogue',
};

/// Returns session IDs for which the row has "X" in the corresponding export column.
List<String> _sessionIdsFromRow(Map<String, String> rawRow) {
  final ids = <String>[];
  for (final entry in _sessionColumnToId.entries) {
    final val = rawRow[entry.key]?.trim().toUpperCase();
    if (val == 'X') ids.add(entry.value);
  }
  return ids;
}

Future<List<Map<String, String>>> readSpreadsheet(String path) async {
  final ext = path.toLowerCase().split('.').last;
  List<int> bytes;
  String content;

  // Use bundled asset when path is the sample (macOS sandbox blocks file access)
  final isSample = path.contains('sample_nlc_registrants');
  if (isSample) {
    content = await rootBundle.loadString('tools/sample_nlc_registrants.csv');
    bytes = utf8.encode(content);
  } else {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('File not found', path);
    }
    bytes = await file.readAsBytes();
    content = await file.readAsString();
  }

  if (ext == 'csv') {
    const converter = CsvToListConverter(eol: '\n');
    final rows = converter.convert(content);
    if (rows.isEmpty) return [];
    final headers = rows.first.map((e) => e.toString()).toList();
    final result = <Map<String, String>>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final map = <String, String>{};
      for (var j = 0; j < headers.length && j < row.length; j++) {
        map[headers[j]] = row[j].toString().trim();
      }
      result.add(map);
    }
    return result;
  }

  if (ext == 'xlsx' || ext == 'xls') {
    try {
      final decoder = SpreadsheetDecoder.decodeBytes(bytes);
      final tableName = decoder.tables.keys.first;
      final table = decoder.tables[tableName]!;
      if (table.rows.isEmpty) return [];
      final headers =
          table.rows.first.map((e) => e?.toString().trim() ?? '').toList();
      final result = <Map<String, String>>[];
      for (var i = 1; i < table.rows.length; i++) {
        final row = table.rows[i];
        final map = <String, String>{};
        for (var j = 0; j < headers.length && j < row.length; j++) {
          final h = headers[j];
          if (h.isEmpty) continue;
          map[h] = (row[j]?.toString() ?? '').trim();
        }
        result.add(map);
      }
      return result;
    } catch (e) {
      throw Exception(
        'Failed to parse $ext. Try exporting to CSV or XLSX in Excel: $e',
      );
    }
  }

  throw ArgumentError('Unsupported format: $ext. Use .csv, .xlsx, or .xls');
}

const _batchSize = 500;

/// Deletes all documents in events/{eventId}/registrants and
/// events/{eventId}/sessionRegistrations. Use before reseeding from NLC main export.
Future<void> clearRegistrationData(FirebaseFirestore firestore) async {
  final registrantsRef = firestore.collection('events/$eventId/registrants');
  final sessionRegRef =
      firestore.collection('events/$eventId/sessionRegistrations');

  for (final colRef in [registrantsRef, sessionRegRef]) {
    var total = 0;
    while (true) {
      final snap = await colRef.limit(_batchSize).get();
      if (snap.docs.isEmpty) break;
      final batch = firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
        total++;
      }
      await batch.commit();
      print('  Deleted $total docs from ${colRef.path}');
    }
  }
  print('Cleared registrants and sessionRegistrations for $eventId.');
}

/// Runs the seed. Returns (imported, skipped, sessionRegistrationsWritten).
/// [hashPii]: when false, stores PII as-is (for local testing; search will work).
/// [clearFirst]: when true, deletes all registrants and sessionRegistrations before seeding.
Future<({int imported, int skipped, int sessionRegistrationsWritten})> runSeed(
  String filePath, {
  bool hashPii = true,
  bool clearFirst = false,
}) async {
  print('Reading: $filePath');
  print('PII hashing: ${hashPii ? "on" : "off (searchable)"}');
  if (clearFirst) print('Clear-first: will erase all registrants and sessionRegistrations then seed.');

  final rows = await readSpreadsheet(filePath);
  if (rows.isEmpty) {
    print('No data rows found.');
    return (imported: 0, skipped: 0, sessionRegistrationsWritten: 0);
  }

  // Use default DB if event-hub-dev fails (e.g. doesn't exist yet)
  final useDefault =
      const bool.fromEnvironment('SEED_USE_DEFAULT', defaultValue: false);
  final FirebaseFirestore firestore;
  if (useDefault) {
    firestore = FirebaseFirestore.instance;
    print(
        'Found ${rows.length} rows. Writing to Firestore ((default) database)...');
  } else {
    FirestoreConfig.init(AppEnvironment.dev);
    firestore = FirestoreConfig.instance;
    // Disable persistence to avoid LevelDB lock if app is also running
    firestore.settings = const Settings(persistenceEnabled: false);

    print('Found ${rows.length} rows. Writing to Firestore (event-hub-dev)...');
    print('  Project: ${firestore.app.options.projectId}');
    print('  Database: ${firestore.databaseId}');
  }

  if (clearFirst) {
    print('Clearing existing registration data...');
    await clearRegistrationData(firestore);
  }

  final registrantsRef = firestore.collection('events/$eventId/registrants');
  final sessionRegRef =
      firestore.collection('events/$eventId/sessionRegistrations');

  var imported = 0;
  var skipped = 0;

  for (var i = 0; i < rows.length; i++) {
    final raw = rows[i];
    final profile = <String, dynamic>{};
    final answers = <String, dynamic>{};

    for (final entry in raw.entries) {
      final header = entry.key;
      var value = entry.value;
      if (value.isEmpty) continue;

      final schemaKey = _toSchemaKey(header);
      if (hashPii && _isPii(header)) {
        value = _hashPii(value);
      }

      if (['firstName', 'lastName', 'email', 'cfcId', 'name', 'phone']
          .contains(schemaKey)) {
        profile[schemaKey] = value;
      } else {
        answers[schemaKey] = value;
      }
    }

    final rowMap = <String, dynamic>{}
      ..addAll(profile)
      ..addAll(answers);
    final id = _registrantId(i, rowMap);

    try {
      print('  Creating registrant ${i + 1}/${rows.length}: $id');
      await registrantsRef.doc(id).set({
        'profile': profile,
        'answers': answers,
        'source': 'import',
        'registrationStatus': 'registered',
        'registeredAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'eventAttendance': {'checkedIn': false},
        'flags': {
          'isWalkIn': false,
          'hasValidationWarnings': false,
        },
      }, SetOptions(merge: true));
      imported++;
      print('  ✓ Created: $id');
    } catch (e, st) {
      skipped++;
      print('  ✗ Row ${i + 2} failed: $e');
      print('    Stack: ${st.toString().split('\n').take(3).join('\n    ')}');
      exit(1);
    }
  }

  // Seed sessionRegistrations from export_*_Dialogue columns (X = registered).
  var sessionRegCount = 0;
  for (var i = 0; i < rows.length; i++) {
    final raw = rows[i];
    final sessionIds = _sessionIdsFromRow(raw);
    if (sessionIds.isEmpty) continue;
    final rowMap = <String, dynamic>{};
    for (final e in raw.entries) {
      rowMap[e.key] = e.value;
    }
    final registrantId = _registrantId(i, rowMap);
    try {
      await sessionRegRef.doc(registrantId).set({
        'registrantId': registrantId,
        'sessionIds': sessionIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      sessionRegCount++;
    } catch (e, st) {
      print('  ✗ sessionRegistrations for $registrantId: $e');
      print('    ${st.toString().split('\n').take(2).join('\n    ')}');
    }
  }
  if (sessionRegCount > 0) {
    print('Session registrations written: $sessionRegCount');
  }

  return (
      imported: imported,
      skipped: skipped,
      sessionRegistrationsWritten: sessionRegCount);
}
