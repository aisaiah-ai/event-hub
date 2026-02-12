import 'package:flutter/material.dart';

import '../checkin_tokens.dart';
import '../models/checkin_state.dart';

class CheckinStatusCard extends StatelessWidget {
  const CheckinStatusCard({
    super.key,
    required this.result,
  });

  final CheckinResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CheckinTokens.spacingM),
      decoration: BoxDecoration(
        color: CheckinTokens.surfaceCard,
        borderRadius: BorderRadius.circular(CheckinTokens.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    switch (result.status) {
      case CheckinStatus.success:
        return _buildSuccessContent();
      case CheckinStatus.duplicate:
        return _buildDuplicateContent();
      case CheckinStatus.error:
        return _buildErrorContent();
    }
  }

  Widget _buildSuccessContent() {
    final timeStr = _formatTime(result.timestamp);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: CheckinTokens.successGreen.withValues(alpha: 0.2),
          child: const Icon(
            Icons.check_circle,
            color: CheckinTokens.successGreen,
            size: 36,
          ),
        ),
        const SizedBox(width: CheckinTokens.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Checked In Successfully',
                style: const TextStyle(
                  color: CheckinTokens.successGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: CheckinTokens.spacingS),
              Text(
                result.name,
                style: const TextStyle(
                  color: CheckinTokens.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (result.role != null || result.chapter != null) ...[
                const SizedBox(height: 4),
                Text(
                  [result.role, result.chapter].whereType<String>().join(' - '),
                  style: const TextStyle(
                    color: CheckinTokens.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Checked in at $timeStr',
                style: TextStyle(
                  color: CheckinTokens.textPrimary.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        if (result.photoUrl != null)
          CircleAvatar(
            radius: 24,
            backgroundImage: NetworkImage(result.photoUrl!),
          ),
      ],
    );
  }

  Widget _buildDuplicateContent() {
    final timeStr = _formatTime(result.timestamp);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: CheckinTokens.warningAmber.withValues(alpha: 0.3),
          child: const Icon(
            Icons.info_outline,
            color: CheckinTokens.warningAmber,
            size: 36,
          ),
        ),
        const SizedBox(width: CheckinTokens.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Already Checked In',
                style: TextStyle(
                  color: CheckinTokens.warningAmber,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: CheckinTokens.spacingS),
              Text(
                result.name,
                style: const TextStyle(
                  color: CheckinTokens.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (result.message != null) ...[
                const SizedBox(height: 4),
                Text(
                  result.message!,
                  style: TextStyle(
                    color: CheckinTokens.textPrimary.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Previously checked in at $timeStr',
                style: TextStyle(
                  color: CheckinTokens.textPrimary.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: CheckinTokens.errorRed.withValues(alpha: 0.2),
          child: const Icon(
            Icons.error_outline,
            color: CheckinTokens.errorRed,
            size: 36,
          ),
        ),
        const SizedBox(width: CheckinTokens.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Check-In Failed',
                style: TextStyle(
                  color: CheckinTokens.errorRed,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: CheckinTokens.spacingS),
              Text(
                result.message ?? 'Unable to check in. Please try manual entry.',
                style: TextStyle(
                  color: CheckinTokens.textPrimary.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $ampm';
  }
}
