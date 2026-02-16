import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/checkin_theme.dart';

/// Dialog shown when attendee is already checked in.
class AlreadyCheckedInDialog extends StatelessWidget {
  const AlreadyCheckedInDialog({
    super.key,
    required this.checkedInAt,
    this.message,
  });

  final DateTime? checkedInAt;
  final String? message;

  static Future<void> show(
    BuildContext context, {
    required DateTime? checkedInAt,
    String? message,
  }) {
    return showDialog(
      context: context,
      builder: (context) => AlreadyCheckedInDialog(
        checkedInAt: checkedInAt,
        message: message,
      ),
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final am = t.hour < 12 ? 'AM' : 'PM';
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m $am';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      title: Text(
        'Already Checked In',
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message ?? 'This attendee has already been checked in.',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary87,
            ),
          ),
          if (checkedInAt != null) ...[
            const SizedBox(height: 12),
            Text(
              'Checked in at: ${_formatTime(checkedInAt!)}',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.navy,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
