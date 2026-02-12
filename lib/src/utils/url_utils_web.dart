// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Redirects old hash URLs (#/events/...) to clean path URLs (/events/...).
/// Ensures old QR codes and bookmarks still work without redirect loops.
void redirectHashToPathIfNeeded() {
  final fragment = html.window.location.hash;
  if (fragment.isEmpty || !fragment.startsWith('#/')) return;
  final path = fragment.substring(1);
  if (path.isEmpty || path == '/') return;
  html.window.history.replaceState(null, '', path);
}
