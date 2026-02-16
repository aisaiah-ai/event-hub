import 'package:flutter/material.dart';

import '../theme/checkin_theme.dart';

/// Footer: "Powered by AIsaiah • CFC Digital Integration".
class FooterCredits extends StatelessWidget {
  const FooterCredits({super.key});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: 'Powered by ',
        style: AppTypography.footer(context).copyWith(
          color: AppColors.gold.withValues(alpha: 0.9),
        ),
        children: [
          TextSpan(
            text: 'AIsaiah',
            style: AppTypography.footerBold(context).copyWith(
              color: AppColors.gold.withValues(alpha: 0.9),
            ),
          ),
          TextSpan(
            text: ' • CFC Digital Integration',
            style: AppTypography.footer(context).copyWith(
              color: AppColors.gold.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
