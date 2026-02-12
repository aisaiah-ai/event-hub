import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../checkin_tokens.dart';

class FooterActions extends StatelessWidget {
  const FooterActions({
    super.key,
    required this.onManualAdd,
    required this.onSwitchSession,
  });

  final VoidCallback onManualAdd;
  final VoidCallback onSwitchSession;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CheckinTokens.spacingM,
        vertical: CheckinTokens.spacingL,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ActionLink(
            label: 'Manual Add Attendee',
            onTap: onManualAdd,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CheckinTokens.spacingM),
            child: Container(
              width: 1,
              height: 14,
              color: CheckinTokens.textMuted.withValues(alpha: 0.6),
            ),
          ),
          _ActionLink(
            label: 'Switch Session / Day',
            onTap: onSwitchSession,
          ),
        ],
      ),
    );
  }
}

class _ActionLink extends StatelessWidget {
  const _ActionLink({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(CheckinTokens.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CheckinTokens.spacingS,
            vertical: CheckinTokens.spacingS,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: CheckinTokens.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
