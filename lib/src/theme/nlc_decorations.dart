import 'package:flutter/material.dart';

import 'nlc_palette.dart';

/// Shared decoration helpers using [NlcPalette] tokens.
BoxDecoration nlcCardDecoration() {
  return BoxDecoration(
    color: NlcPalette.cream2,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: NlcPalette.border, width: 1),
    boxShadow: [
      BoxShadow(
        color: NlcPalette.shadow,
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

BoxDecoration nlcPanelDecoration() {
  return BoxDecoration(
    color: NlcPalette.cream2,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: NlcPalette.border, width: 1),
    boxShadow: [
      BoxShadow(
        color: NlcPalette.shadow,
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

BoxDecoration nlcPillDecoration() {
  return BoxDecoration(
    color: NlcPalette.brandBlue,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: NlcPalette.brandBlueDark.withValues(alpha: 0.3),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}
