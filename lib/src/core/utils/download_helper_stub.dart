/// Stub for non-web platforms. Download not supported.
Future<bool> downloadFile(
  String filename,
  String content, {
  String mimeType = 'text/csv;charset=utf-8',
}) async {
  return false;
}

Future<bool> downloadBytes(
  String filename,
  List<int> bytes, {
  String mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
}) async {
  return false;
}
