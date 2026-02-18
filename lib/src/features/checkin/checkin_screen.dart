import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'checkin_tokens.dart';
import 'models/checkin_state.dart';
import 'widgets/checkin_status_card.dart';
import 'widgets/event_header.dart';
import 'widgets/footer_actions.dart';
import 'widgets/manual_entry_button.dart';
import 'widgets/offline_banner.dart';
import 'widgets/primary_qr_button.dart';

/// Conference check-in screen — matches high-fidelity mock.
/// Supports tablet (max 720px) and phone layouts.
class CheckinScreen extends StatefulWidget {
  const CheckinScreen({
    super.key,
    required this.eventId,
    required this.sessionId,
    this.eventTitle,
    this.eventVenue,
    this.eventDate,
    this.checkedInBy = 'admin',
  });

  final String eventId;
  final String sessionId;
  final String? eventTitle;
  final String? eventVenue;
  final DateTime? eventDate;
  final String checkedInBy;

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  CheckinState _state = const CheckinState();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth > 720
            ? 720.0
            : constraints.maxWidth;
        return Scaffold(
          backgroundColor: CheckinTokens.primaryBlue,
          body: Stack(
            children: [
              _buildBackground(),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CheckinTokens.spacingM,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: CheckinTokens.spacingS),
                          EventHeaderWidget(
                            emblemPath: 'assets/checkin/empower.png',
                            organization: 'Couples for Christ',
                            title: widget.eventTitle ?? 'Event Check-in',
                            subtitle: _buildSubtitle(),
                          ),
                          const SizedBox(height: CheckinTokens.spacingL),
                          PrimaryQRButton(onScanQr: _onScanQr),
                          const SizedBox(height: CheckinTokens.spacingL),
                          _buildDivider(),
                          const SizedBox(height: CheckinTokens.spacingL),
                          ManualEntryButton(onTap: _onManualEntry),
                          if (_state.lastResult != null) ...[
                            const SizedBox(height: CheckinTokens.spacingL),
                            CheckinStatusCard(result: _state.lastResult!),
                          ],
                          const SizedBox(height: CheckinTokens.spacingXL),
                          FooterActions(
                            onManualAdd: _onManualAddAttendee,
                            onSwitchSession: _onSwitchSession,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_state.isOffline) _buildOfflineBanner(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF164B70), Color(0xFF0E3A5D), Color(0xFF0A2E47)],
            ),
          ),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: CheckinTokens.patternOpacity,
            child: SvgPicture.asset(
              'assets/checkin/mossaic.svg',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(color: CheckinTokens.textMuted.withValues(alpha: 0.5)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CheckinTokens.spacingM,
          ),
          child: Text(
            'OR',
            style: TextStyle(
              color: CheckinTokens.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: CheckinTokens.textMuted.withValues(alpha: 0.5)),
        ),
      ],
    );
  }

  Widget _buildOfflineBanner() {
    return Positioned(
      left: CheckinTokens.spacingM,
      right: CheckinTokens.spacingM,
      bottom: CheckinTokens.spacingL,
      child: SafeArea(top: false, child: Center(child: OfflineBanner())),
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (widget.eventDate != null) {
      parts.add(_formatDate(widget.eventDate!));
    }
    if (widget.eventVenue != null && widget.eventVenue!.isNotEmpty) {
      if (parts.isNotEmpty) parts.add(' • ');
      parts.add(widget.eventVenue!);
    }
    return parts.isEmpty ? '' : parts.join();
  }

  String _formatDate(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  void _onScanQr() {
    HapticFeedback.mediumImpact();
    // TODO: Integrate QR scanner. For now, simulate success.
    setState(() {
      _state = _state.copyWith(
        lastResult: CheckinResult(
          name: 'Juan Dela Cruz',
          role: 'Unit Head',
          chapter: 'CFC Laguna',
          timestamp: DateTime.now(),
          status: CheckinStatus.success,
        ),
      );
    });
  }

  void _onManualEntry() {
    context.push(
      Uri(
        path: '/admin/sessions/${widget.sessionId}/manual-checkin',
        queryParameters: {'eventId': widget.eventId},
      ).toString(),
    );
  }

  void _onManualAddAttendee() {
    context.push(
      Uri(
        path: '/admin/registrants/new',
        queryParameters: {'eventId': widget.eventId},
      ).toString(),
    );
  }

  void _onSwitchSession() {
    context.push(
      Uri(
        path: '/admin',
        queryParameters: {'eventId': widget.eventId},
      ).toString(),
    );
  }
}
