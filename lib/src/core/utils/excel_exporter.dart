import 'dart:typed_data';

import 'package:excel/excel.dart';

/// Generate Excel file with Sheet 1: Summary, Sheet 2: Regions, Sheet 3: Ministries,
/// Sheet 4: Hourly, Sheet 5: Sessions, Sheet 6: Raw Attendance.
Uint8List createAttendanceExcelFull({
  required List<List<String>> summaryRows,
  required List<List<String>> regionRows,
  required List<List<String>> ministryRows,
  required List<List<String>> hourlyRows,
  required List<List<String>> sessionRows,
  required List<List<String>> rawRows,
  required List<String> rawHeaders,
}) {
  final excel = Excel.createExcel();
  // Use appendRow to ensure sheets are created and data is written correctly
  _appendAllRows(excel, 'Summary', summaryRows);
  _appendAllRows(excel, 'Regions', regionRows);
  _appendAllRows(excel, 'Ministries', ministryRows);
  _appendAllRows(excel, 'Hourly', hourlyRows);
  _appendAllRows(excel, 'Sessions', sessionRows);
  _appendAllRows(excel, 'Raw Attendance', [rawHeaders, ...rawRows]);

  final encoded = excel.encode();
  if (encoded == null || encoded.isEmpty) {
    throw StateError('Excel encode returned empty or null');
  }
  return Uint8List.fromList(encoded);
}

/// Generate Excel file with Sheet 1: Aggregated, Sheet 2: Raw Attendance.
/// Returns bytes for download.
Uint8List createAttendanceExcel({
  required List<List<String>> aggregatedRows,
  required List<String> aggregatedHeaders,
  required List<List<String>> rawRows,
  required List<String> rawHeaders,
}) {
  final excel = Excel.createExcel();
  _appendAllRows(excel, 'Aggregated', [aggregatedHeaders, ...aggregatedRows]);
  _appendAllRows(excel, 'Raw Attendance', [rawHeaders, ...rawRows]);

  final encoded = excel.encode();
  if (encoded == null || encoded.isEmpty) {
    throw StateError('Excel encode returned empty or null');
  }
  return Uint8List.fromList(encoded);
}

void _appendAllRows(Excel excel, String sheetName, List<List<String>> rows) {
  final sheet = excel[sheetName];
  for (final row in rows) {
    final cellValues = row.map<CellValue?>((s) => TextCellValue(s.toString())).toList();
    sheet.appendRow(cellValues);
  }
}
