import 'package:flutter/material.dart';

import '../../../events/widgets/event_page_scaffold.dart';
import '../theme/checkin_theme.dart';

/// Header: "NATIONAL LEADERS" / "CONFERENCE 2026" (2026 in gold).
/// Logo defaults to empower.png when logoUrl is null.
class ConferenceHeader extends StatelessWidget {
  static const String defaultLogoPath = 'assets/checkin/empower.png';

  const ConferenceHeader({
    super.key,
    this.logoUrl,
  });

  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final effectiveLogoUrl = logoUrl != null && logoUrl!.isNotEmpty
        ? logoUrl!
        : defaultLogoPath;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.iconTextSpacing),
          child: EventLogo(logoUrl: effectiveLogoUrl, size: 192),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NATIONAL LEADERS',
                style: AppTypography.headerTitle(context),
              ),
              Text.rich(
                TextSpan(
                  text: 'CONFERENCE ',
                  style: AppTypography.headerTitle(context),
                  children: [
                    TextSpan(
                      text: '2026',
                      style: AppTypography.headerTitleGold(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
