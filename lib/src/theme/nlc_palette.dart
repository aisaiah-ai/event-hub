import 'package:flutter/material.dart';

/// NLC "Empowered to Serve" blue palette — single source of truth for check-in UI.
/// No hardcoded colors in widgets; use tokens from here.
class NlcPalette {
  NlcPalette._();

  // Primary blues
  static const Color brandBlue = Color(0xFF2E5E7E);
  static const Color brandBlueDark = Color(0xFF1F3F55);
  static const Color brandBlueSoft = Color(0xFF4D7FA0);

  // Surfaces
  static const Color cream = Color(0xFFF3F0E8);
  static const Color cream2 = Color(0xFFF8F6F1);

  // Text
  static const Color ink = Color(0xFF0F2230);
  static const Color muted = Color(0xFF6E7E8A);

  // Borders & shadows
  static const Color border = Color(0x1A2E5E7E);
  static const Color shadow = Color(0x14000000);

  // Status
  static const Color success = Color(0xFF2E7D66);
  static const Color danger = Color(0xFFB84A4A);

  // Legacy aliases for gradual migration (map to palette)
  static const Color white = Colors.white;
}
