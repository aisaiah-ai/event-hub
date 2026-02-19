import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/nlc_palette.dart';
import '../../../../models/registrant.dart';
import '../../data/checkin_mode.dart';
import '../../data/checkin_repository.dart';
import '../../data/nlc_sessions.dart';
import '../theme/checkin_theme.dart';

/// Result card: session check-in only. Writes to events/{eventId}/sessions/{sessionId}/attendance.
/// If checked in: green "Checked In", tap disabled. If not: tappable, "Tap to check in to this session".
class RegistrantResultCard extends StatefulWidget {
  const RegistrantResultCard({
    super.key,
    required this.registrant,
    required this.eventId,
    required this.mode,
    required this.repo,
    required this.onTap,
  });

  final Registrant registrant;
  final String eventId;
  final CheckInMode mode;
  final CheckinRepository repo;
  final VoidCallback onTap;

  @override
  State<RegistrantResultCard> createState() => _RegistrantResultCardState();
}

class _RegistrantResultCardState extends State<RegistrantResultCard> {
  bool? _checkedIn;
  /// When checking in to a session other than main-checkin, whether registrant is already in conference.
  bool? _conferenceCheckedIn;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void didUpdateWidget(covariant RegistrantResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode.sessionId != widget.mode.sessionId ||
        oldWidget.registrant.id != widget.registrant.id) {
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    setState(() {
      _checkedIn = null;
      _conferenceCheckedIn = null;
    });
    try {
      final checkedIn = await widget.repo.isCheckedIn(
        eventId: widget.eventId,
        sessionId: widget.mode.sessionId,
        registrantId: widget.registrant.id,
      );
      bool? conferenceCheckedIn;
      if (widget.mode.sessionId != NlcSessions.mainCheckInSessionId) {
        conferenceCheckedIn = await widget.repo.isCheckedIn(
          eventId: widget.eventId,
          sessionId: NlcSessions.mainCheckInSessionId,
          registrantId: widget.registrant.id,
        );
      }
      if (!mounted) return;
      setState(() {
        _checkedIn = checkedIn;
        _conferenceCheckedIn = conferenceCheckedIn;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _checkedIn = false);
    }
  }

  String get _displayName {
    final name =
        widget.registrant.profile['name'] ?? widget.registrant.answers['name'];
    if (name?.toString().trim().isNotEmpty ?? false) {
      return name.toString().trim();
    }
    final first =
        widget.registrant.profile['firstName'] ?? widget.registrant.answers['firstName'];
    final last =
        widget.registrant.profile['lastName'] ?? widget.registrant.answers['lastName'];
    return '${first ?? ''} ${last ?? ''}'.trim();
  }

  String get _firstInitial {
    final first =
        widget.registrant.profile['firstName'] ?? widget.registrant.answers['firstName'];
    if (first != null && first.toString().trim().isNotEmpty) {
      return first.toString().trim().substring(0, 1).toUpperCase();
    }
    final name =
        widget.registrant.profile['name'] ?? widget.registrant.answers['name'];
    if (name != null && name.toString().trim().isNotEmpty) {
      return name.toString().trim().substring(0, 1).toUpperCase();
    }
    return '?';
  }

  String? get _ministry {
    final v = widget.registrant.profile['ministryMembership'] ??
        widget.registrant.answers['ministryMembership'] ??
        widget.registrant.profile['ministry'] ??
        widget.registrant.answers['ministry'];
    return v?.toString().trim();
  }

  String? get _service {
    final v = widget.registrant.profile['service'] ?? widget.registrant.answers['service'];
    return v?.toString().trim();
  }

  /// Ministry and service when not redundant (avoid "CFC · CFC (HH & up)").
  List<String> get _ministryAndServiceDisplay {
    final m = _ministry;
    final s = _service;
    if (m == null && s == null) return [];
    if (m == null) return [s!];
    if (s == null) return [m];
    if (m == s) return [m];
    if (s.toLowerCase().startsWith(m.toLowerCase())) return [s];
    if (m.toLowerCase().startsWith(s.toLowerCase())) return [m];
    return [m, s];
  }

  String? get _regionDisplay {
    final region =
        widget.registrant.profile['region'] ?? widget.registrant.answers['region'];
    final other =
        widget.registrant.profile['regionOtherText'] ??
        widget.registrant.answers['regionOtherText'];
    if (region == null || region.toString().trim().isEmpty) return null;
    final r = region.toString().trim();
    if (r.toLowerCase() == 'other' && other != null && other.toString().trim().isNotEmpty) {
      return 'Other – ${other.toString().trim()}';
    }
    if (other != null && other.toString().trim().isNotEmpty) {
      return '$r – ${other.toString().trim()}';
    }
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final checkedIn = _checkedIn;
    final canTap = checkedIn != true;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canTap ? widget.onTap : null,
        borderRadius: BorderRadius.circular(20),
        splashColor: canTap ? Colors.black12 : null,
        highlightColor: canTap ? Colors.black.withValues(alpha: 0.08) : null,
        mouseCursor: canTap ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInitialBadge(),
              const SizedBox(width: AppSpacing.iconTextSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName,
                      style: GoogleFonts.inter(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    if (_ministryAndServiceDisplay.isNotEmpty || _regionDisplay != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        [
                          ..._ministryAndServiceDisplay,
                          _regionDisplay,
                        ].whereType<String>().join(' · '),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 10),
                    _buildStatusSection(checkedIn),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitialBadge() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NlcPalette.brandBlue,
            NlcPalette.brandBlueSoft,
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: NlcPalette.brandBlue.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        _firstInitial,
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
    );
  }

  Widget _buildStatusSection(bool? checkedIn) {
    if (checkedIn == null) {
      return Text(
        '…',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary87.withValues(alpha: 0.7),
        ),
      );
    }
    if (checkedIn) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.statusCheckedIn,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'CHECKED IN',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      );
    }
    // Only show "You'll also be checked in to conference" when we've actually checked
    // conference status and the registrant is not yet checked in to the conference.
    final isOtherSession = widget.mode.sessionId != NlcSessions.mainCheckInSessionId;
    final hasCheckedConferenceStatus = _conferenceCheckedIn != null;
    final isNotCheckedInToConference = _conferenceCheckedIn == false;
    final showConferenceNote = isOtherSession && hasCheckedConferenceStatus && isNotCheckedInToConference;
    if (showConferenceNote) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Tap to check in to this session.',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: NlcPalette.brandBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'You\'ll also be checked in to the conference (Main Check-In) if you aren\'t already.',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary87.withValues(alpha: 0.85),
            ),
          ),
        ],
      );
    }
    return Text(
      'Tap to check in to this session.',
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: NlcPalette.brandBlue,
      ),
    );
  }
}
