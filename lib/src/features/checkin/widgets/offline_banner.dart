import 'package:flutter/material.dart';

import '../checkin_tokens.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.text = 'Offline Mode Active'});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CheckinTokens.spacingM,
        vertical: CheckinTokens.spacingS,
      ),
      decoration: BoxDecoration(
        color: CheckinTokens.accentGold.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(CheckinTokens.radiusLarge),
        border: Border.all(
          color: CheckinTokens.accentGold.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, color: CheckinTokens.accentGold, size: 20),
          const SizedBox(width: CheckinTokens.spacingS),
          Text(
            text,
            style: TextStyle(
              color: CheckinTokens.textPrimary.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
