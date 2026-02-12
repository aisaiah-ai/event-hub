import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../checkin_tokens.dart';

class ManualEntryButton extends StatelessWidget {
  const ManualEntryButton({
    super.key,
    required this.onTap,
    this.text = 'Enter Name or CFC ID',
  });

  final VoidCallback onTap;

  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(CheckinTokens.radiusLarge),
        child: Container(
          height: CheckinTokens.qrButtonHeight,
          decoration: BoxDecoration(
            color: CheckinTokens.surfaceCard,
            borderRadius: BorderRadius.circular(CheckinTokens.radiusLarge),
            border: Border.all(
              color: CheckinTokens.textPrimary.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: CheckinTokens.spacingM),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.keyboard,
                color: CheckinTokens.textPrimary,
                size: 24,
              ),
              const SizedBox(width: CheckinTokens.spacingM),
              Text(
                text,
                style: const TextStyle(
                  color: CheckinTokens.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
