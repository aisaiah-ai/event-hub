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
/// Official breakout colors: Gender Identity (Blue), Abortion & Contraception (Orange), Immigration (Yellow).
String? sessionColorDisplayName(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final h = (hex.startsWith('#') ? hex : '#$hex').toLowerCase();
  switch (h) {
    case '#1e3a5f':
      return 'Navy';
    case '#2563eb':
      return 'Blue';
    case '#ea580c':
      return 'Orange';
    case '#eab308':
      return 'Yellow';
    default:
      return null;
  }
}
