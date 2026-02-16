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
  _writeRows(excel['Summary'], summaryRows);
  _writeRows(excel['Regions'], regionRows);
  _writeRows(excel['Ministries'], ministryRows);
  _writeRows(excel['Hourly'], hourlyRows);
  _writeRows(excel['Sessions'], sessionRows);
  _writeRows(excel['Raw Attendance'], [rawHeaders, ...rawRows]);
  return Uint8List.fromList(excel.encode() ?? []);
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
  final aggSheet = excel['Aggregated'];
  _writeRows(aggSheet, [aggregatedHeaders, ...aggregatedRows]);

  final rawSheet = excel['Raw Attendance'];
  _writeRows(rawSheet, [rawHeaders, ...rawRows]);

  return Uint8List.fromList(excel.encode() ?? []);
}

void _writeRows(Sheet sheet, List<List<String>> rows) {
  for (var r = 0; r < rows.length; r++) {
    final row = rows[r];
    for (var c = 0; c < row.length; c++) {
      final cell = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
      cell.value = TextCellValue(row[c]);
    }
  }
}
