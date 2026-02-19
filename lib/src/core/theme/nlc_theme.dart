import 'package:flutter/material.dart';

import '../../theme/nlc_palette.dart';

/// NLC 2026 — Empowered to Serve color system.
/// Delegates to [NlcPalette]. Blue-first palette, no gold accents.
class NlcColors {
  NlcColors._();

  // Primary (blue palette)
  static const Color primaryBlue = NlcPalette.brandBlue;
  static const Color secondaryBlue = NlcPalette.brandBlueSoft;

  // Surfaces
  static const Color ivory = NlcPalette.cream;
  static const Color surfaceLight = NlcPalette.cream2;

  // Text
  static const Color slate = NlcPalette.ink;
  static const Color mutedText = NlcPalette.muted;

  // Status
  static const Color successGreen = NlcPalette.success;

  static const Color white = NlcPalette.white;
}
