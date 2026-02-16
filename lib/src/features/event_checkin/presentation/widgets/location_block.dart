import 'package:flutter/material.dart';

import '../theme/checkin_theme.dart';

/// Location block — icon + venue + address.
class LocationBlock extends StatelessWidget {
  const LocationBlock({
    super.key,
    required this.venue,
    required this.address,
  });

  final String venue;
  final String address;

  @override
  Widget build(BuildContext context) {
    if (venue.isEmpty && address.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.location_on,
          size: 20,
          color: AppColors.gold,
        ),
        const SizedBox(width: AppSpacing.iconSpacing),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (venue.isNotEmpty)
                Text(
                  venue,
                  style: AppTypography.locationVenue(context),
                ),
              if (address.isNotEmpty) ...[
                if (venue.isNotEmpty) const SizedBox(height: AppSpacing.betweenTitleAddress),
                Text(
                  address,
                  style: AppTypography.locationAddress(context),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
