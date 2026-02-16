import 'package:csv/csv.dart';

/// CSV export utilities for attendance reports.
/// Filename format: nlc-2026_attendance_YYYYMMDD.csv
String csvFilename(String eventSlug, String suffix) {
  final now = DateTime.now();
  final y = now.year;
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  return '${eventSlug}_${suffix}_$y$m$d.csv';
}

/// Generate CSV string from rows. First row is header.
String toCsv(List<List<dynamic>> rows) {
  return const ListToCsvConverter().convert(rows);
}

/// Escape a cell value for CSV (handles quotes, commas, newlines).
String escapeCsvCell(dynamic value) {
  if (value == null) return '';
  final s = value.toString();
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}
