import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/checkin_theme.dart';

/// Bottom sheet confirmation modal with gold top border.
class CheckinConfirmationModal extends StatelessWidget {
  const CheckinConfirmationModal({
    super.key,
    required this.name,
    required this.ministry,
    required this.region,
    required this.onConfirm,
    required this.onCancel,
  });

  final String name;
  final String? ministry;
  final String? region;
  final Future<void> Function() onConfirm;
  final VoidCallback onCancel;

  static Future<bool?> show(
    BuildContext context, {
    required String name,
    String? ministry,
    String? region,
    required Future<void> Function() onConfirm,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CheckinConfirmationModal(
        name: name,
        ministry: ministry,
        region: region,
        onConfirm: () async {
          HapticFeedback.mediumImpact();
          await onConfirm();
          if (context.mounted) Navigator.of(context).pop(true);
        },
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            width: 48,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirm Check-In',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                if (ministry != null && ministry!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    ministry!,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary87,
                    ),
                  ),
                ],
                if (region != null && region!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    region!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary87,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppColors.navy),
                          foregroundColor: AppColors.navy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.goldGradientStart,
                              AppColors.goldGradientEnd,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async => await onConfirm(),
                            borderRadius: BorderRadius.circular(14),
                            child: Center(
                              child: Text(
                                'Confirm Check-In',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
