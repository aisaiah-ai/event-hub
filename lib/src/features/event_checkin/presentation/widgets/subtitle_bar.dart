import 'package:flutter/material.dart';

import '../theme/checkin_theme.dart';

/// "Self Check-In Portal" with gold divider lines above and below.
class SubtitleBar extends StatelessWidget {
  const SubtitleBar({
    super.key,
    this.title = 'Self Check-In Portal',
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.horizontalDivider),
          child: Container(
            height: 2,
            color: AppColors.goldDivider,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            title,
            style: AppTypography.subtitle(context),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.horizontalDivider),
          child: Container(
            height: 2,
            color: AppColors.goldDivider,
          ),
        ),
      ],
    );
  }
}
