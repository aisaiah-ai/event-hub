import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../models/session.dart';
import '../../../theme/nlc_palette.dart';
import '../../../core/utils/download_helper.dart';
import '../../events/data/event_model.dart';
import '../../events/widgets/event_page_scaffold.dart';
import 'theme/checkin_theme.dart';
import 'widgets/conference_header.dart';
import 'widgets/footer_credits.dart';

/// Post check-in confirmation: session info, receipt, Save as Image, Wallet placeholders.
class CheckinConfirmationScreen extends StatefulWidget {
  const CheckinConfirmationScreen({
    super.key,
    required this.eventSlug,
    required this.session,
    required this.registrantName,
    required this.registrantId,
    this.event,
    this.eventId,
    this.checkedInAt,
  });

  final String eventSlug;
  final Session session;
  final String registrantName;
  final String registrantId;
  final EventModel? event;
  final String? eventId;
  final DateTime? checkedInAt;

  @override
  State<CheckinConfirmationScreen> createState() =>
      _CheckinConfirmationScreenState();
}

class _CheckinConfirmationScreenState extends State<CheckinConfirmationScreen> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _savingImage = false;

  Color _colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return NlcPalette.brandBlue;
    final h = hex.startsWith('#') ? hex : '#$hex';
    if (h.length == 7) {
      final r = int.tryParse(h.substring(1, 3), radix: 16);
      final g = int.tryParse(h.substring(3, 5), radix: 16);
      final b = int.tryParse(h.substring(5, 7), radix: 16);
      if (r != null && g != null && b != null) {
        return Color.fromARGB(255, r, g, b);
      }
    }
    return NlcPalette.brandBlue;
  }

  Future<void> _saveAsImage() async {
    final ro = _receiptKey.currentContext?.findRenderObject();
    final boundary = ro is RenderRepaintBoundary ? ro : null;
    if (boundary == null) {
      _showSnack('Could not capture image.');
      return;
    }
    setState(() => _savingImage = true);
    try {
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();
      if (pngBytes == null || pngBytes.isEmpty) {
        _showSnack('Failed to generate image.');
        return;
      }
      final ok = await downloadBytes(
        'checkin-confirmation-${widget.registrantId}.png',
        pngBytes,
        mimeType: 'image/png',
      );
      if (mounted) {
        if (ok) {
          _showSnack('Image saved.');
        } else {
          _showSnack('Save not supported on this device. Use web to download.');
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _savingImage = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final color = _colorFromHex(session.colorHex);
    final at = widget.checkedInAt ?? DateTime.now();
    String dateTime = '';
    if (session.startAt != null) {
      dateTime = DateFormat.MMMd().add_jm().format(session.startAt!);
      if (session.endAt != null) {
        dateTime += ' – ${DateFormat.jm().format(session.endAt!)}';
      }
    } else {
      dateTime = DateFormat.MMMd().add_jm().format(at);
    }

    return EventPageScaffold(
      event: widget.event,
      eventSlug: widget.eventSlug,
      bodyMaxWidth: 480,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: NlcPalette.cream),
          onPressed: () => context.go('/events/${widget.eventSlug}/main-checkin'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.horizontal),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.afterHeader),
                  ConferenceHeader(logoUrl: widget.event?.logoUrl),
                  const SizedBox(height: AppSpacing.betweenSections),
                  Text(
                    "You're Checked In",
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: NlcPalette.cream,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.belowSubtitle),
                  RepaintBoundary(
                    key: _receiptKey,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: color.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  session.displayName,
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (dateTime.isNotEmpty)
                            _ReceiptRow(
                              icon: Icons.schedule,
                              label: 'Date & time',
                              value: dateTime,
                            ),
                          if (session.location != null &&
                              session.location!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _ReceiptRow(
                              icon: Icons.location_on,
                              label: 'Location',
                              value: session.location!,
                            ),
                          ],
                          const SizedBox(height: 20),
                          Divider(
                            height: 1,
                            color: NlcPalette.brandBlue.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Receipt',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.registrantName,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy,
                            ),
                          ),
                          Text(
                            'ID: ${widget.registrantId}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textPrimary87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Checked in: ${DateFormat.MMMd().add_jm().format(at)}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textPrimary87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ActionButton(
                    icon: Icons.image_outlined,
                    label: 'Save as Image',
                    onTap: _savingImage ? null : _saveAsImage,
                    loading: _savingImage,
                  ),
                  const SizedBox(height: 12),
                  _ActionButton(
                    icon: Icons.wallet,
                    label: 'Add to Apple Wallet',
                    subtitle: 'Coming soon',
                    onTap: null,
                  ),
                  const SizedBox(height: 12),
                  _ActionButton(
                    icon: Icons.wallet,
                    label: 'Add to Google Wallet',
                    subtitle: 'Coming soon',
                    onTap: null,
                  ),
                  const SizedBox(height: AppSpacing.footerTop),
                  const FooterCredits(),
                  const SizedBox(height: AppSpacing.betweenSections),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: NlcPalette.brandBlue),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textPrimary87.withValues(alpha: 0.9),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled
                  ? NlcPalette.brandBlue.withValues(alpha: 0.4)
                  : Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: enabled ? NlcPalette.brandBlue : Colors.grey,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: enabled ? AppColors.navy : Colors.grey,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (enabled)
                Icon(
                  Icons.chevron_right,
                  color: NlcPalette.brandBlue,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
