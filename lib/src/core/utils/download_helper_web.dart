// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation: triggers browser download via Blob + AnchorElement.
Future<bool> downloadFile(
  String filename,
  String content, {
  String mimeType = 'text/csv;charset=utf-8',
}) async {
  try {
    final blob = html.Blob([content], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement()
      ..href = url
      ..download = filename
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> downloadBytes(
  String filename,
  List<int> bytes, {
  String mimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
}) async {
  try {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement()
      ..href = url
      ..download = filename
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return true;
  } catch (_) {
    return false;
  }
}
