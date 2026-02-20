import 'package:flutter/material.dart';

import '../../models/session.dart';

/// Official NLC 2026 breakout color system — single source of truth.
/// Use for wayfinding and room identification only. Do not use for capacity/ranking.
class NlcSessionColors {
  NlcSessionColors._();

  /// Gender Identity → Blue
  static const Color blue = Color(0xFF2F6FED);

  /// Abortion & Contraception → Orange
  static const Color orange = Color(0xFFF59E0B);

  /// Immigration → Green
  static const Color green = Color(0xFF16A34A);

  /// Main Check-In → Neutral Navy
  static const Color main = Color(0xFF1E2F4F);

  /// Canonical hex values for persistence (e.g. wallet, save-as-image).
  static const String blueHex = '#2F6FED';
  static const String orangeHex = '#F59E0B';
  static const String greenHex = '#16A34A';
  static const String mainHex = '#1E2F4F';
}

/// Resolves session color from id / title / isMain. Single source of truth.
/// If [session.colorHex] is wrong or missing in Firestore, color is derived from id, title, or isMain.
Color resolveSessionColor(Session session) {
  if (session.isMain) return NlcSessionColors.main;
  // Match by session id first (canonical NLC breakout ids)
  switch (session.id) {
    case 'gender-ideology-dialogue':
      return NlcSessionColors.blue;
    case 'contraception-ivf-abortion-dialogue':
      return NlcSessionColors.orange;
    case 'immigration-dialogue':
      return NlcSessionColors.green;
    default:
      break;
  }
  final t = session.title.trim().toLowerCase();
  if (t.contains('gender') && t.contains('ideology')) return NlcSessionColors.blue;
  if (t.contains('contraception') || t.contains('ivf') || t.contains('abortion')) return NlcSessionColors.orange;
  if (t.contains('immigration')) return NlcSessionColors.green;
  final hex = session.colorHex;
  if (hex != null && hex.isNotEmpty) {
    final c = _colorFromHex(hex);
    if (c != null) return c;
  }
  return NlcSessionColors.main;
}

/// Returns the canonical hex string for the session (for wallet, save-as-image).
String resolveSessionColorHex(Session session) {
  if (session.isMain) return NlcSessionColors.mainHex;
  switch (session.id) {
    case 'gender-ideology-dialogue':
      return NlcSessionColors.blueHex;
    case 'contraception-ivf-abortion-dialogue':
      return NlcSessionColors.orangeHex;
    case 'immigration-dialogue':
      return NlcSessionColors.greenHex;
    default:
      break;
  }
  final t = session.title.trim().toLowerCase();
  if (t.contains('gender') && t.contains('ideology')) return NlcSessionColors.blueHex;
  if (t.contains('contraception') || t.contains('ivf') || t.contains('abortion')) return NlcSessionColors.orangeHex;
  if (t.contains('immigration')) return NlcSessionColors.greenHex;
  final hex = session.colorHex;
  if (hex != null && hex.isNotEmpty) return hex.startsWith('#') ? hex : '#$hex';
  return NlcSessionColors.mainHex;
}

Color? _colorFromHex(String hex) {
  final h = (hex.startsWith('#') ? hex : '#$hex').toLowerCase();
  if (h.length != 7) return null;
  final r = int.tryParse(h.substring(1, 3), radix: 16);
  final g = int.tryParse(h.substring(3, 5), radix: 16);
  final b = int.tryParse(h.substring(5, 7), radix: 16);
  if (r == null || g == null || b == null) return null;
  return Color.fromARGB(255, r, g, b);
}
