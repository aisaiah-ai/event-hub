import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';

import '../models/registration_schema.dart';

/// Pure CSV parsing utilities (no Firestore dependency).
class CsvParser {
  const CsvParser();

  /// Parse CSV content into list of row maps (header -> value).
  List<Map<String, String>> parseCsv(String csvContent) {
    const converter = CsvToListConverter(eol: '\n');
    final rows = converter.convert(csvContent);
    if (rows.isEmpty) return [];
    final headers = rows.first.map((e) => e.toString()).toList();
    final result = <Map<String, String>>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final map = <String, String>{};
      for (var j = 0; j < headers.length && j < row.length; j++) {
        map[headers[j]] = row[j].toString();
      }
      result.add(map);
    }
    return result;
  }

  /// Auto-map CSV headers to schema keys (case-insensitive match).
  Map<String, String> autoMapHeaders(
    List<String> csvHeaders,
    RegistrationSchema schema,
  ) {
    final mapping = <String, String>{};
    final schemaKeys = schema.fields.map((f) => f.key.toLowerCase()).toList();
    for (final header in csvHeaders) {
      final lower = header.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      final idx = schemaKeys.indexOf(lower);
      if (idx >= 0) {
        mapping[header] = schema.fields[idx].key;
      } else {
        for (final f in schema.fields) {
          final labelNorm = f.label.toLowerCase().replaceAll(
            RegExp(r'\s+'),
            '_',
          );
          if (labelNorm == lower || f.key.toLowerCase() == lower) {
            mapping[header] = f.key;
            break;
          }
        }
      }
    }
    return mapping;
  }

  /// Deterministic registrant ID from row values.
  String deterministicId(Map<String, dynamic> values, List<String> keyFields) {
    final parts = <String>[];
    for (final k in keyFields) {
      parts.add(values[k]?.toString() ?? '');
    }
    if (parts.isEmpty) parts.addAll(values.values.map((v) => v.toString()));
    final input = parts.join('|');
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 20);
  }
}
