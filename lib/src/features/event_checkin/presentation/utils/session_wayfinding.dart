import 'package:flutter/material.dart';

import '../../../../theme/nlc_palette.dart';

/// Wayfinding: session color as physical identity (not capacity/availability).
/// Use for headers, accent lines, and "Proceed to the [Color] session area."

const double _kMinHeaderHeight = 56;

/// Minimum height for a session wayfinding header.
double get sessionWayfindingHeaderMinHeight => _kMinHeaderHeight;

/// Parses session.colorHex to [Color]. Fallback: [NlcPalette.brandBlue].
Color sessionColorFromHex(String? hex) {
  if (hex == null || hex.isEmpty) return NlcPalette.brandBlue;
  final h = (hex.startsWith('#') ? hex : '#$hex').toLowerCase();
  if (h.length == 7) {
    final r = int.tryParse(h.substring(1, 3), radix: 16);
    final g = int.tryParse(h.substring(3, 5), radix: 16);
    final b = int.tryParse(h.substring(5, 7), radix: 16);
    if (r != null && g != null && b != null) {
      return Color.fromARGB(255, r, g, b);
    }
  }
  return NlcPalette.brandBlue;
}

/// Display name for wayfinding message: "Proceed to the [Color] session area."
/// Official breakout colors: Gender Identity (Blue), Abortion & Contraception (Orange), Immigration (Green).
String? sessionColorDisplayName(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final h = (hex.startsWith('#') ? hex : '#$hex').toLowerCase();
  switch (h) {
    case '#1e3a5f':
    case '#1e2f4f':
      return 'Navy';
    case '#2563eb':
    case '#2f6fed':
      return 'Blue';
    case '#ea580c':
    case '#f59e0b':
      return 'Orange';
    case '#eab308':
    case '#facc15':
    case '#16a34a':
      return 'Green';
    default:
      return null;
  }
}

/// Uppercase session color label for signage: "BLUE SESSION", "ORANGE SESSION", wristband instructions.
/// Maps prompt hexes (#2F6FED, #F59E0B, #16A34A, #1E2F4F) and current NLC hexes. Main check-in → "MAIN".
String resolveSessionColorName(String? hex) {
  if (hex == null || hex.isEmpty) return 'SESSION';
  final h = (hex.startsWith('#') ? hex : '#$hex').toLowerCase();
  switch (h) {
    case '#1e3a5f':
    case '#1e2f4f':
      return 'MAIN';
    case '#2e5e7e':
    case '#2563eb':
    case '#2f6fed':
      return 'BLUE';
    case '#ea580c':
    case '#f59e0b':
      return 'ORANGE';
    case '#eab308':
    case '#facc15':
    case '#16a34a':
      return 'GREEN';
    default:
      return 'SESSION';
  }
}

/// Text color for use on a colored background (WCAG contrast). Dark background → white; yellow → dark navy.
Color contrastTextColorOn(Color background) {
  final luminance = background.computeLuminance();
  if (luminance < 0.4) return Colors.white;
  return NlcPalette.ink;
}
