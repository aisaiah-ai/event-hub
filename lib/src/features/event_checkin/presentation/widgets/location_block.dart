import 'package:flutter/material.dart';

import '../theme/checkin_theme.dart';

/// Location block — icon + venue + address. Customizable card styling.
class LocationBlock extends StatelessWidget {
  const LocationBlock({
    super.key,
    required this.venue,
    required this.address,
    this.decoration,
    this.padding,
    this.iconColor,
    this.iconSize = 20,
    this.venueStyle,
    this.addressStyle,
  });

  final String venue;
  final String address;
  /// Optional card decoration (e.g. white card with shadow for light theme).
  final BoxDecoration? decoration;
  /// Padding around the content. Default: 20 all sides when decoration is set.
  final EdgeInsetsGeometry? padding;
  /// Icon color. Default: AppColors.gold.
  final Color? iconColor;
  final double iconSize;
  /// Override venue text style.
  final TextStyle? venueStyle;
  /// Override address text style.
  final TextStyle? addressStyle;

  @override
  Widget build(BuildContext context) {
    if (venue.isEmpty && address.isEmpty) return const SizedBox.shrink();

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.location_on,
          size: iconSize,
          color: iconColor ?? AppColors.gold,
        ),
        const SizedBox(width: AppSpacing.iconSpacing),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (venue.isNotEmpty)
                Text(
                  venue,
                  style: venueStyle ?? AppTypography.locationVenue(context),
                ),
              if (address.isNotEmpty) ...[
                if (venue.isNotEmpty) const SizedBox(height: AppSpacing.betweenTitleAddress),
                Text(
                  address,
                  style: addressStyle ?? AppTypography.locationAddress(context),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    if (decoration != null) {
      return Container(
        padding: padding ?? const EdgeInsets.all(20),
        decoration: decoration,
        child: content,
      );
    }

    return content;
  }
}
