import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../checkin_tokens.dart';

class EventHeaderWidget extends StatelessWidget {
  const EventHeaderWidget({
    super.key,
    this.emblemPath = 'assets/checkin/empower.png',
    this.organization = 'Couples for Christ',
    this.title = 'National Leaders Conference',
    this.subtitle = '',
  });

  final String emblemPath;
  final String organization;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CheckinTokens.spacingM,
        vertical: CheckinTokens.spacingL,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: CheckinTokens.emblemHeight,
            width: CheckinTokens.emblemHeight,
            child: emblemPath.toLowerCase().endsWith('.png')
                ? Image.asset(emblemPath, fit: BoxFit.contain)
                : SvgPicture.asset(emblemPath, fit: BoxFit.contain),
          ),
          const SizedBox(width: CheckinTokens.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  organization,
                  style: TextStyle(
                    color: CheckinTokens.textOffWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: CheckinTokens.spacingS),
                Text(
                  title,
                  style: TextStyle(
                    color: CheckinTokens.textOffWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: CheckinTokens.spacingS),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: CheckinTokens.textOffWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
