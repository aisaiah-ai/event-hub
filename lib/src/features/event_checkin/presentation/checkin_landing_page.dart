import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/session.dart';
import '../../events/data/event_model.dart';
import '../data/checkin_mode.dart' show CheckInFlowType;
import '../data/checkin_repository.dart';
import '../data/nlc_sessions.dart';
import 'theme/checkin_theme.dart';
import 'widgets/animated_checkin_card.dart';
import 'widgets/conference_header.dart';
import 'widgets/footer_credits.dart';
import 'widgets/location_block.dart';
import 'widgets/session_dropdown.dart';
import 'widgets/subtitle_bar.dart';

/// Self-check-in landing. Supports event mode (conference) and session mode (session-specific QR).
/// Event mode: session dropdown, updates eventAttendance.
/// Session mode: session name front and center, no dropdown, writes only to attendance.
class CheckinLandingPage extends StatefulWidget {
  const CheckinLandingPage({
    super.key,
    required this.event,
    required this.eventSlug,
    required this.mode,
    this.sessionId,
    this.sessionName,
    this.lockedSession,
    this.isMainCheckIn = false,
    this.repository,
  });

  final EventModel event;
  final String eventSlug;
  final CheckInFlowType mode;
  final String? sessionId;
  final String? sessionName;
  /// When set (session mode or slug-based), use this session and hide the dropdown.
  final Session? lockedSession;
  /// True for conference arrival check-in — no session dropdown, event-level only.
  final bool isMainCheckIn;
  final CheckinRepository? repository;

  @override
  State<CheckinLandingPage> createState() => _CheckinLandingPageState();
}

/// Event ID for NLC 2026. Sessions must be loaded from Firestore; no hardcoded lists.
const String nlc2026EventId = 'nlc-2026';

class _CheckinLandingPageState extends State<CheckinLandingPage> {
  late CheckinRepository _repo;
  List<Session> _sessions = [];
  Session? _selectedSession;
  bool _loadingSessions = true;
  /// True when event is nlc-2026 and sessions collection is empty (run initializeNlc2026).
  bool _eventNotInitialized = false;
  /// Recent check-ins for the current session (name + timestamp).
  List<({String name, DateTime timestamp})> _recentCheckins = [];

  @override
  void initState() {
    super.initState();
    assert(
      widget.mode == CheckInFlowType.event || widget.sessionId != null,
      'Session mode requires sessionId',
    );
    _repo = widget.repository ?? CheckinRepository();
    _loadSessions();
    _loadRecentCheckins();
  }

  Future<void> _loadRecentCheckins() async {
    final list = await _repo.getRecentCheckins(
      widget.event.id,
      _effectiveSessionId,
      limit: 10,
    );
    if (mounted) setState(() => _recentCheckins = list);
  }

  static const List<Session> _defaultSessionFallback = [
    Session(id: 'default', title: 'Day 1 Main Session', name: 'Day 1 Main Session', isActive: true),
  ];

  bool get _isSessionMode => widget.mode == CheckInFlowType.session;

  bool get _isMainCheckIn =>
      widget.mode == CheckInFlowType.event && widget.isMainCheckIn;

  String get _effectiveSessionId =>
      _isMainCheckIn
          ? NlcSessions.mainCheckInSessionId
          : (widget.sessionId ?? _selectedSession?.id ?? 'default');

  String get _effectiveSessionName =>
      _isMainCheckIn ? 'Main Check-In' : (widget.sessionName ?? _selectedSession?.displayName ?? 'Session');

  Future<void> _loadSessions() async {
    if (widget.lockedSession != null || _isSessionMode || _isMainCheckIn) {
      setState(() {
        _sessions = widget.lockedSession != null
            ? [widget.lockedSession!]
            : _defaultSessionFallback;
        _selectedSession = _isMainCheckIn ? null : (widget.lockedSession ?? _defaultSessionFallback.first);
        _loadingSessions = false;
        _eventNotInitialized = false;
      });
      return;
    }
    if (!widget.event.sessionsEnabled) {
      setState(() => _loadingSessions = false);
      return;
    }
    try {
      final List<Session> sessions;
      if (widget.event.id == nlc2026EventId) {
        sessions = await _repo.getSessionsOrderedByOrder(widget.event.id);
        if (!mounted) return;
        if (sessions.isEmpty) {
          setState(() {
            _sessions = [];
            _selectedSession = null;
            _loadingSessions = false;
            _eventNotInitialized = true;
          });
          return;
        }
      } else {
        sessions = await _repo.getActiveSessions(widget.event.id);
        if (!mounted) return;
        if (sessions.isEmpty) {
          setState(() {
            _sessions = _defaultSessionFallback;
            _selectedSession = _defaultSessionFallback.first;
            _loadingSessions = false;
          });
          return;
        }
      }
      setState(() {
        _sessions = sessions;
        _selectedSession = sessions.length == 1 ? sessions.first : null;
        _loadingSessions = false;
        _eventNotInitialized = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _sessions = widget.event.id == nlc2026EventId ? [] : _defaultSessionFallback;
          _selectedSession = _sessions.isNotEmpty ? _sessions.first : null;
          _loadingSessions = false;
          _eventNotInitialized = widget.event.id == nlc2026EventId;
        });
      }
    }
  }

  String get _primaryButtonTitle {
    if (_isSessionMode) {
      return 'Scan QR to Check Into This Session';
    }
    if (_isMainCheckIn) {
      return 'Scan QR to Check In';
    }
    return 'Scan CFC QR Code';
  }

  String get _primaryButtonSubtitle {
    if (_isSessionMode) {
      return 'This will check you into $_effectiveSessionName.';
    }
    if (_isMainCheckIn) {
      return 'This will check you in.';
    }
    return 'Point your camera at your CFC ID QR code.';
  }

  @override
  Widget build(BuildContext context) {
    if (_eventNotInitialized) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Event not initialized. Contact admin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.95),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }
    return _loadingSessions
        ? const Center(
            child: CircularProgressIndicator(color: AppColors.white),
          )
        : SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.horizontal),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.afterHeader),
                      if (_isSessionMode) _buildSessionHeader() else _buildEventHeader(),
                      if (_isMainCheckIn) _buildMainCheckInBadge(),
                      AnimatedCheckinCard(
                        leading: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.goldIconContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.qr_code_scanner, size: 28),
                        ),
                        title: _primaryButtonTitle,
                        subtitle: _primaryButtonSubtitle,
                        onTap: _onScanQr,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.goldGradientStart,
                            AppColors.goldGradientEnd,
                          ],
                        ),
                        isPrimary: true,
                      ),
                      const SizedBox(height: AppSpacing.betweenSections),
                      AnimatedCheckinCard(
                        leading: const Icon(Icons.search, size: 28),
                        title: 'Search by Name',
                        subtitle: _isSessionMode
                            ? 'Enter at least 3 letters of your last name to check into $_effectiveSessionName.'
                            : _isMainCheckIn
                                ? 'Enter at least 3 letters of your last name to check in.'
                                : 'Enter at least 3 letters of your last name.',
                        onTap: _onSearch,
                        backgroundColor: AppColors.surfaceCard,
                        isPrimary: false,
                      ),
                      const SizedBox(height: AppSpacing.betweenSecondaryCards),
                      AnimatedCheckinCard(
                        leading: const Icon(Icons.edit_note, size: 28),
                        title: 'Enter Manually',
                        subtitle: 'For walk-ins or unregistered attendees.',
                        onTap: _onManualEntry,
                        backgroundColor: AppColors.surfaceCard,
                        isPrimary: false,
                      ),
                      const SizedBox(height: AppSpacing.betweenSections),
                      _buildRecentCheckinsLog(),
                      const SizedBox(height: AppSpacing.footerTop),
                      const FooterCredits(),
                      const SizedBox(height: AppSpacing.betweenSections),
                    ],
                  ),
                ),
              ),
            ),
          );
  }

  Widget _buildSessionHeader() {
    return Column(
      children: [
        ConferenceHeader(logoUrl: widget.event.logoUrl),
        const SizedBox(height: AppSpacing.betweenSections),
        Text(
          'SESSION CHECK-IN',
          style: TextStyle(
            fontSize: 18,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
            color: AppColors.goldGradientEnd,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.goldGradientEnd, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _effectiveSessionName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMainCheckInBadge() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1C355E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'MAIN CHECK-IN',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildRecentCheckinsLog() {
    if (_recentCheckins.isEmpty) {
      return const SizedBox.shrink();
    }
    String formatTime(DateTime dt) =>
        '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.goldGradientEnd.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 20, color: AppColors.goldGradientEnd),
              const SizedBox(width: 8),
              Text(
                'Recent check-ins',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._recentCheckins.take(10).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text(
                      formatTime(e.timestamp),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textPrimary87.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildEventHeader() {
    return Column(
      children: [
        ConferenceHeader(logoUrl: widget.event.logoUrl),
        const SizedBox(height: AppSpacing.betweenSections),
        SubtitleBar(
          title: _isMainCheckIn ? 'Main Check-In' : 'Self Check-In Portal',
        ),
        if (_isMainCheckIn)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Scan your QR code or search by name to check in.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.belowSubtitle),
        LocationBlock(
          venue: widget.event.locationName,
          address: widget.event.address,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          iconColor: AppColors.goldIconContainer,
          venueStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
          addressStyle: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textPrimary87,
          ),
        ),
        const SizedBox(height: AppSpacing.betweenSections),
        if (!_isMainCheckIn && widget.event.sessionsEnabled && widget.lockedSession == null) ...[
          SessionDropdown(
            sessions: _sessions,
            selectedSession: _selectedSession,
            onSessionSelected: (s) =>
                setState(() => _selectedSession = s),
          ),
          const SizedBox(height: AppSpacing.betweenSections),
        ],
        if (!_isMainCheckIn && widget.lockedSession != null) ...[
          _SessionLabel(session: widget.lockedSession!),
          const SizedBox(height: AppSpacing.betweenSections),
        ],
      ],
    );
  }

  Future<void> _onScanQr() async {
    if (!_ensureSessionSelected()) return;
    HapticFeedback.mediumImpact();
    final identifier = await _showQrInputDialog();
    if (identifier == null || !mounted) return;
    await _processQrIdentifier(identifier);
  }

  Future<String?> _showQrInputDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter CFC ID or Email'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'From QR code or type manually',
          ),
          autofocus: true,
          onSubmitted: (_) => Navigator.of(ctx).pop(controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Look up'),
          ),
        ],
      ),
    );
  }

  Future<void> _processQrIdentifier(String identifier) async {
    try {
      final registrant = await _repo.findRegistrantByCfcIdOrEmail(
        widget.event.id,
        identifier,
      );
      if (!mounted) return;
      if (registrant != null) {
        await _performCheckin(registrantId: registrant.id);
      } else {
        _showNotFoundSnackbar(identifier);
      }
    } catch (e, st) {
      debugPrint('[CheckinLanding] QR check-in failed: $e');
      debugPrint('[CheckinLanding] Stack: $st');
      if (mounted) _showErrorSnackbar(e.toString());
    }
  }

  void _showNotFoundSnackbar(String identifier) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Not found: $identifier'),
        action: SnackBarAction(
          label: 'Enter manually',
          onPressed: () => _onManualEntry(),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _onSearch() async {
    if (!_ensureSessionSelected()) return;
    HapticFeedback.mediumImpact();
    final result = await context.push<Map<String, dynamic>>(
      '/events/${widget.eventSlug}/checkin/search',
      extra: {
        'eventId': widget.event.id,
        'eventSlug': widget.eventSlug,
        'sessionId': _effectiveSessionId,
        'sessionName': _effectiveSessionName,
      },
    );
    if (!mounted || result == null) return;
    final completed = result['completed'] as bool? ?? false;
    if (completed) return;
    final registrantId = result['registrantId'] as String?;
    if (registrantId != null) {
      await _performCheckin(registrantId: registrantId, method: CheckinMethod.search);
    }
  }

  Future<void> _onManualEntry() async {
    if (!_ensureSessionSelected()) return;
    HapticFeedback.mediumImpact();
    final result = await context.push<Map<String, dynamic>>(
      '/events/${widget.eventSlug}/checkin/manual',
      extra: {
        'eventId': widget.event.id,
        'eventSlug': widget.eventSlug,
        'sessionId': _effectiveSessionId,
        'sessionName': _effectiveSessionName,
      },
    );
    if (!mounted || result == null) return;
    final success = result['success'] as bool? ?? false;
    if (success) {
      await _showSuccessAndReturn(
        name: result['name'] as String? ?? 'Guest',
        sessionName: _effectiveSessionName,
      );
    }
  }

  Future<void> _performCheckin({
    required String registrantId,
    CheckinMethod method = CheckinMethod.qr,
  }) async {
    try {
      await _repo.checkInSessionOnly(
        widget.event.id,
        _effectiveSessionId,
        registrantId,
        source: 'self',
        method: method,
      );
      if (!mounted) return;
      await _loadRecentCheckins();
      if (!mounted) return;
      final registrant = await _repo.getRegistrant(widget.event.id, registrantId);
      final name = registrant != null ? _displayName(registrant) : 'Guest';
      await _showSuccessAndReturn(
        name: name,
        sessionName: _effectiveSessionName,
      );
    } catch (e, st) {
      debugPrint('[CheckinLanding] Check-in failed: $e');
      debugPrint('[CheckinLanding] Stack: $st');
      if (mounted) _showErrorSnackbar(e.toString());
    }
  }

  String _displayName(dynamic r) {
    final first = r.profile['firstName'] ?? r.answers['firstName'];
    final last = r.profile['lastName'] ?? r.answers['lastName'];
    final name = r.profile['name'] ?? r.answers['name'];
    if (name?.toString().trim().isNotEmpty ?? false) return name.toString().trim();
    if ((first ?? last) != null) return '${first ?? ''} ${last ?? ''}'.trim();
    return r.id;
  }

  Future<void> _showSuccessAndReturn({
    required String name,
    required String sessionName,
  }) async {
    await context.push(
      '/events/${widget.eventSlug}/checkin/success',
      extra: {
        'name': name,
        'sessionName': sessionName,
        'eventSlug': widget.eventSlug,
        'returnPath': _effectiveSessionId == NlcSessions.mainCheckInSessionId
            ? '/events/${widget.eventSlug}/main-checkin'
            : '/events/${widget.eventSlug}/checkin',
      },
    );
  }

  bool _ensureSessionSelected() {
    if (_isMainCheckIn) return true;
    if (widget.lockedSession != null || _isSessionMode) {
      return _selectedSession != null || widget.sessionId != null;
    }
    if (!widget.event.sessionsEnabled) {
      setState(() => _selectedSession = _sessions.isNotEmpty ? _sessions.first : null);
      return _selectedSession != null;
    }
    if (_selectedSession == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a session first')),
      );
      return false;
    }
    return true;
  }
}

class _SessionLabel extends StatelessWidget {
  const _SessionLabel({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.goldGradientEnd.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.event_note, color: AppColors.goldGradientEnd, size: 24),
          const SizedBox(width: 12),
          Text(
            session.displayName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}
