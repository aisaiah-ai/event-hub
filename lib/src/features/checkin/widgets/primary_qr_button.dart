import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/nlc_palette.dart';
import '../checkin_tokens.dart';

class PrimaryQRButton extends StatelessWidget {
  const PrimaryQRButton({
    super.key,
    required this.onScanQr,
    this.text = 'Scan CFC ID QR Code',
    this.subtext = 'Fastest way to check in',
  });

  final VoidCallback onScanQr;

  final String text;
  final String subtext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              onScanQr();
            },
            borderRadius: BorderRadius.circular(CheckinTokens.radiusLarge),
            child: Container(
              height: CheckinTokens.qrButtonHeight,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    NlcPalette.brandBlueSoft,
                    NlcPalette.brandBlue,
                    NlcPalette.brandBlueDark,
                  ],
                ),
                borderRadius: BorderRadius.circular(CheckinTokens.radiusLarge),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: CheckinTokens.spacingM,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner, color: NlcPalette.cream, size: 28),
                  const SizedBox(width: CheckinTokens.spacingM),
                  Text(
                    text,
                    style: const TextStyle(
                      color: NlcPalette.cream,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: CheckinTokens.spacingS),
        Text(
          subtext,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: CheckinTokens.textOffWhite.withValues(alpha: 0.9),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
