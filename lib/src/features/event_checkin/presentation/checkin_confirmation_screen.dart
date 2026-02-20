import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/session.dart';
import '../../../theme/nlc_palette.dart';
import '../../../core/utils/download_helper.dart';
import '../../events/data/event_model.dart';
import '../../events/widgets/event_page_scaffold.dart';
import 'theme/checkin_theme.dart';
import 'utils/session_date_display.dart';
import 'utils/session_wayfinding.dart';
import 'widgets/conference_header.dart';
import 'widgets/footer_credits.dart';

/// NLC check-in confirmation: wayfinding (session color), wristband instruction, conference guide.
/// UI + messaging only. No changes to Firestore, analytics, or attendance path.
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

  static const String _guideUrl = 'https://nlcguide.cfcusaconferences.org';

  Future<void> _openGuide() async {
    final uri = Uri.parse(_guideUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) _showSnack('Could not open guide.');
    }
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

  void _onDone() {
    context.go('/events/${widget.eventSlug}/main-checkin');
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final color = sessionColorFromHex(session.colorHex);
    final colorName = resolveSessionColorName(session.colorHex);
    final textOnColor = contrastTextColorOn(color);
    final at = widget.checkedInAt ?? DateTime.now();
    String dateTime = getSessionDateDisplay(session);
    if (dateTime.isEmpty) {
      dateTime = '${DateFormat.MMMd().format(at)} · ${DateFormat.jm().format(at)}';
    }

    return EventPageScaffold(
      event: widget.event,
      eventSlug: widget.eventSlug,
      bodyMaxWidth: 480,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.check, color: NlcPalette.cream),
          onPressed: _onDone,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.afterHeader),
                  ConferenceHeader(logoUrl: widget.event?.logoUrl),
                  const SizedBox(height: AppSpacing.betweenSections),
                  // A. Header: checkmark, You Are Checked In, participant name
                  Icon(
                    Icons.check_circle_rounded,
                    size: 64,
                    color: NlcPalette.success,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You Are Checked In',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: NlcPalette.cream,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.registrantName,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: NlcPalette.cream.withValues(alpha: 0.95),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Session card: banner (icon + color label + title), body (location, date/time), dashed divider, wristband block
                  RepaintBoundary(
                    key: _receiptKey,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Colored banner: circle icon + BLUE SESSION, then session title
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                            decoration: BoxDecoration(color: color),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: textOnColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '$colorName SESSION',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.0,
                                        color: textOnColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  session.displayName,
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: textOnColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // White body: location, date/time
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (session.location != null &&
                                    session.location!.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      Icon(Icons.location_on,
                                          size: 18, color: color),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          session.location!,
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            color: AppColors.textPrimary87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (dateTime.isNotEmpty) const SizedBox(height: 8),
                                ],
                                if (dateTime.isNotEmpty)
                                  Row(
                                    children: [
                                      Icon(Icons.schedule,
                                          size: 18, color: color),
                                      const SizedBox(width: 8),
                                      Text(
                                        dateTime,
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          color: AppColors.textPrimary87,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          // Dashed divider
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              children: List.generate(
                                14,
                                (_) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Container(
                                    width: 12,
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Wristband block: light tint background, icon, instruction
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.festival,
                                  size: 28,
                                  color: color,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text.rich(
                                        TextSpan(
                                          text: 'Your wristband color: ',
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            color: AppColors.navy,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: colorName,
                                              style: GoogleFonts.inter(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: color,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Proceed to the $colorName wristband table.',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Divider(
                    height: 1,
                    color: NlcPalette.cream.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 24),
                  // Conference guide: icon, title/URL, Open Guide button on the right
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: NlcPalette.brandBlue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.menu_book_rounded,
                            size: 28, color: NlcPalette.brandBlue),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Conference Guide',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'nlcguide.cfcusaconferences.org',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.textPrimary87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        FilledButton(
                          onPressed: _openGuide,
                          style: FilledButton.styleFrom(
                            backgroundColor: NlcPalette.brandBlue,
                            foregroundColor: NlcPalette.cream,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Open Guide'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _onDone,
                      style: FilledButton.styleFrom(
                        backgroundColor: NlcPalette.brandBlue,
                        foregroundColor: NlcPalette.cream,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ActionButton(
                    icon: Icons.image_outlined,
                    label: 'Save as Image',
                    onTap: _savingImage ? null : _saveAsImage,
                    loading: _savingImage,
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
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
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: enabled ? AppColors.navy : Colors.grey,
                  ),
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
