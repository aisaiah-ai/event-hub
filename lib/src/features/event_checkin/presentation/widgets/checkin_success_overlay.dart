import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/checkin_theme.dart';

/// Success overlay with name, mode, timestamp; auto-dismiss after 2 seconds.
class CheckinSuccessOverlay extends StatefulWidget {
  const CheckinSuccessOverlay({
    super.key,
    required this.onDismiss,
    required this.name,
    required this.modeDisplayName,
    this.timestamp,
    this.alsoCheckedInToConference = false,
  });

  final VoidCallback onDismiss;
  final String name;
  final String modeDisplayName;
  final DateTime? timestamp;
  /// When true, show that the user was also checked in to the conference (Main Check-In).
  final bool alsoCheckedInToConference;

  @override
  State<CheckinSuccessOverlay> createState() => _CheckinSuccessOverlayState();
}

class _CheckinSuccessOverlayState extends State<CheckinSuccessOverlay> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) widget.onDismiss();
    });
  }

  String _formatTime(DateTime t) {
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final am = t.hour < 12 ? 'AM' : 'PM';
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m $am';
  }

  @override
  Widget build(BuildContext context) {
    final ts = widget.timestamp ?? DateTime.now();
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: AppColors.statusCheckedIn,
                size: 72,
              ),
              const SizedBox(height: 16),
              Text(
                'Successfully Checked In',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                widget.name,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                widget.modeDisplayName,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary87,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.alsoCheckedInToConference) ...[
                const SizedBox(height: 6),
                Text(
                  'You\'re also checked in to the conference (Main Check-In).',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.statusCheckedIn,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _formatTime(ts),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
