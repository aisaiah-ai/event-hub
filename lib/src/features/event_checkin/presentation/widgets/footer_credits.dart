import 'package:flutter/material.dart';

import '../../../../theme/nlc_palette.dart';
import '../theme/checkin_theme.dart';

/// Footer: "Powered by AISaiah" / "CFC Digital Integration" — two lines, reduced weight.
class FooterCredits extends StatelessWidget {
  const FooterCredits({super.key});

  @override
  Widget build(BuildContext context) {
    const double fontSize = 12;
    const double opacity = 0.6;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Powered by AISaiah',
          style: AppTypography.footer(context).copyWith(
            fontSize: fontSize,
            color: NlcPalette.cream.withValues(alpha: opacity),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          'CFC Digital Integration',
          style: AppTypography.footer(context).copyWith(
            fontSize: fontSize,
            color: NlcPalette.cream.withValues(alpha: opacity),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
