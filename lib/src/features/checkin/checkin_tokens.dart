import 'package:flutter/material.dart';

import '../../theme/nlc_palette.dart';

/// Design tokens for check-in screen — blue palette, no gold.
class CheckinTokens {
  CheckinTokens._();

  // Colors (delegate to NlcPalette)
  static const Color primaryBlue = NlcPalette.brandBlueDark;
  static const Color surfaceCard = NlcPalette.cream2;
  static const Color successGreen = NlcPalette.success;
  static const Color warningAmber = Color(0xFFFFC107);
  static const Color textPrimary = NlcPalette.ink;
  static const Color textOffWhite = NlcPalette.cream;
  static const Color textMuted = NlcPalette.muted;
  static const Color errorRed = NlcPalette.danger;

  // Radius & Spacing
  static const double radiusLarge = 16;
  static const double radiusMedium = 12;
  static const double spacingXL = 32;
  static const double spacingL = 24;
  static const double spacingM = 16;
  static const double spacingS = 8;

  // Sizes
  static const double emblemHeight = 96;
  static const double qrButtonHeight = 64;
  static const double patternOpacity = 0.06;
}
