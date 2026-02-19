import 'package:flutter/material.dart';

import '../../../events/widgets/event_page_scaffold.dart';
import '../theme/checkin_theme.dart';

/// Header: NLC "Empowered to Serve" logo only (no title text).
/// Logo defaults to nlc_logo.png (full circular seal) when logoUrl is null.
class ConferenceHeader extends StatelessWidget {
  static const String defaultLogoPath = 'assets/checkin/nlc_logo.png';

  const ConferenceHeader({
    super.key,
    this.logoUrl,
  });

  final String? logoUrl;

  /// Logo size ~10% larger than previous 192 for better presence.
  static const double logoSize = 212;

  /// Soft blue glow behind logo.
  static final BoxDecoration _logoGlowDecoration = BoxDecoration(
    borderRadius: BorderRadius.circular(8),
    boxShadow: [
      BoxShadow(
        color: AppColors.accent.withValues(alpha: 0.2),
        blurRadius: 30,
        spreadRadius: 2,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    // Use new NLC logo even when event still has old empower.png in Firestore
    final raw = logoUrl != null && logoUrl!.isNotEmpty ? logoUrl! : defaultLogoPath;
    final effectiveLogoUrl = raw == 'assets/checkin/empower.png' ? defaultLogoPath : raw;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.horizontal),
      child: Center(
        child: Container(
          decoration: _logoGlowDecoration,
          child: EventLogo(logoUrl: effectiveLogoUrl, size: logoSize),
        ),
      ),
    );
  }
}
