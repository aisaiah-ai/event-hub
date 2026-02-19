import 'package:flutter/material.dart';

import '../../../../theme/nlc_palette.dart';
import '../theme/checkin_theme.dart';

/// "Self Check-In Portal" with cream divider lines above and below.
class SubtitleBar extends StatelessWidget {
  const SubtitleBar({
    super.key,
    this.title = 'Self Check-In Portal',
  });

  final String title;

  /// Thin, elegant divider: 1.2px × 180px, cream 80% opacity.
  static const double _dividerHeight = 1.2;
  static const double _dividerWidth = 180;

  @override
  Widget build(BuildContext context) {
    final divider = Center(
      child: Container(
        height: _dividerHeight,
        width: _dividerWidth,
        color: NlcPalette.cream.withValues(alpha: 0.8),
      ),
    );
    return Column(
      children: [
        divider,
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            title,
            style: AppTypography.subtitle(context),
            textAlign: TextAlign.center,
          ),
        ),
        divider,
      ],
    );
  }
}
