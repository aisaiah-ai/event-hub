import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/firestore_config.dart';
import '../../../models/registrant.dart';
import '../../../services/registrant_service.dart';
import '../../events/data/event_model.dart';
import '../../events/data/event_repository.dart';
import '../../events/widgets/event_page_scaffold.dart';
import '../data/checkin_mode.dart';
import '../data/checkin_repository.dart';
import 'theme/checkin_theme.dart';
import 'widgets/registrant_result_card.dart';
import 'widgets/checkin_success_overlay.dart';
import 'widgets/already_checked_in_dialog.dart';

/// Search registrants by name. Session-only: badge and check-in scoped to [sessionId].
class CheckinSearchPage extends StatefulWidget {
  const CheckinSearchPage({
    super.key,
    required this.eventId,
    required this.eventSlug,
    required this.mode,
    this.repository,
  });

  final String eventId;
  final String eventSlug;
  final CheckInMode mode;
  final CheckinRepository? repository;

  @override
  State<CheckinSearchPage> createState() => _CheckinSearchPageState();
}

class _CheckinSearchPageState extends State<CheckinSearchPage> {
  late CheckinRepository _repo;
  EventModel? _event;
  bool _loadingEvent = true;
  final _searchController = TextEditingController();
  List<Registrant> _results = [];
  bool _searching = false;
  /// Set when a one-time permission check finds permission-denied (Firestore rules).
  bool _firestorePermissionDenied = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? CheckinRepository();
    _searchController.addListener(_onSearchChanged);
    _loadEvent();
  }

  @override
  void didUpdateWidget(covariant CheckinSearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode.sessionId != widget.mode.sessionId ||
        oldWidget.eventId != widget.eventId) {
      setState(() => _results = []);
    }
  }

  Future<void> _loadEvent() async {
    final event = await EventRepository().getEventBySlug(widget.eventSlug);
    if (!mounted) return;
    setState(() {
      _event = event;
      _loadingEvent = false;
    });
    final eventId = event?.id ?? widget.eventId;
    if (eventId.isEmpty) return;
    final status = await RegistrantService().checkRegistrantReadPermission(eventId);
    if (!mounted) return;
    if (status.isPermissionDenied) {
      setState(() => _firestorePermissionDenied = true);
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceSearch();
  }

  void _debounceSearch() {
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      final q = _searchController.text.trim();
      if (q.length < 2) {
        setState(() => _results = []);
        return;
      }
      final eventId = _event?.id ?? widget.eventId;
      if (eventId.isEmpty) return;
      setState(() => _searching = true);
      try {
        final list = await _repo.searchRegistrants(eventId, q, limit: 15);
        if (mounted) {
          setState(() {
            _results = list;
            _searching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _searching = false;
            if (FirestoreRegistrantReadStatus.isPermissionDeniedError(e)) {
              _firestorePermissionDenied = true;
            }
          });
        }
        debugPrint('Search error: $e');
        debugPrint(
            'Search debug: eventId=$eventId, db=${FirestoreConfig.databaseId}');
      }
    });
  }

  Future<void> _onSelectRegistrant(Registrant r) async {
    HapticFeedback.mediumImpact();
    final checkedIn = await _repo.isCheckedIn(
      eventId: widget.eventId,
      sessionId: widget.mode.sessionId,
      registrantId: r.id,
    );
    if (checkedIn) {
      if (!mounted) return;
      await AlreadyCheckedInDialog.show(
        context,
        checkedInAt: null,
        message: 'Already checked into this session.',
      );
      return;
    }
    if (!mounted) return;
    try {
      final result = await _repo.checkInSessionAndConferenceIfNeeded(
        widget.eventId,
        widget.mode.sessionId,
        r.id,
        checkedInBy: 'self',
      );
      if (!mounted) return;
      if (result.didSessionCheckIn || result.didConferenceCheckIn) {
        _showSuccessOverlay(
          name: _displayName(r),
          alsoCheckedInToConference: result.didConferenceCheckIn,
        );
        await _refreshSearchResults();
      } else {
        await AlreadyCheckedInDialog.show(
          context,
          checkedInAt: null,
          message: 'Already checked into this session.',
        );
      }
    } catch (e, st) {
      final real = _unwrapError(e);
      final pathLines = _checkInPathLines(r.id);
      debugPrint('[CheckinSearch] Check-in FAILED sessionId=${widget.mode.sessionId} registrantId=${r.id} error=$real');
      debugPrint('[CheckinSearch] database=${FirestoreConfig.databaseId}');
      for (final line in pathLines) {
        debugPrint('[CheckinSearch]   $line');
      }
      debugPrint('[CheckinSearch] stack=$st');
      if (!mounted) return;
      final String message = _checkInErrorMessage(real, pathLines.join(' ; '));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }

  List<String> _checkInPathLines(String registrantId) {
    return [
      'document=events/${widget.eventId}/sessions/${widget.mode.sessionId}/attendance/$registrantId',
    ];
  }

  /// Unwrap boxed errors (e.g. "Dart exception thrown from converted Future" on web).
  static Object _unwrapError(Object e) {
    try {
      if (e is AsyncError) return e.error;
    } catch (_) {}
    try {
      final d = e as dynamic;
      final inner = d.error;
      if (inner != null && identical(inner, e) == false) return inner as Object;
    } catch (_) {}
    return e;
  }

  static String _checkInErrorMessage(Object real, String pathDetail) {
    final pathLine = 'Write target: $pathDetail';
    if (real is FirebaseException) {
      if (real.code == 'permission-denied') {
        return 'Check-in denied. $pathLine Deploy Firestore rules for this database.';
      }
      return 'Check-in failed: ${real.message ?? real.code}. $pathLine';
    }
    final s = real.toString();
    if (s.contains('converted Future') || s.contains("fetch the boxed error")) {
      return 'Check-in failed (likely permission-denied). $pathLine Deploy Firestore rules.';
    }
    return 'Check-in failed: $real. $pathLine';
  }

  Future<void> _refreshSearchResults() async {
    if (!mounted) return;
    final q = _searchController.text.trim();
    if (q.length < 2) return;
    final eventId = _event?.id ?? widget.eventId;
    if (eventId.isEmpty) return;
    final list = await _repo.searchRegistrants(eventId, q, limit: 15);
    if (!mounted) return;
    setState(() => _results = list);
  }

  void _showSuccessOverlay({required String name, bool alsoCheckedInToConference = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => CheckinSuccessOverlay(
        name: name,
        modeDisplayName: widget.mode.displayName,
        timestamp: DateTime.now(),
        alsoCheckedInToConference: alsoCheckedInToConference,
        onDismiss: () {
          Navigator.of(context).pop();
          if (mounted) {
            context.pop({'registrantId': null, 'completed': true});
          }
        },
      ),
    );
  }

  String _displayName(Registrant r) {
    final name = r.profile['name'] ?? r.answers['name'];
    if (name?.toString().trim().isNotEmpty ?? false) return name.toString().trim();
    final first = r.profile['firstName'] ?? r.answers['firstName'];
    final last = r.profile['lastName'] ?? r.answers['lastName'];
    return '${first ?? ''} ${last ?? ''}'.trim();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingEvent) {
      return EventPageScaffold(
        event: null,
        eventSlug: widget.eventSlug,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.white),
        ),
      );
    }

    return EventPageScaffold(
      event: _event,
      eventSlug: widget.eventSlug,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.afterHeader),
                if (_firestorePermissionDenied) _buildPermissionBanner(),
                if (_firestorePermissionDenied) const SizedBox(height: 12),
                _buildSessionContextBanner(),
                const SizedBox(height: AppSpacing.betweenSections),
                _buildHeader(),
                const SizedBox(height: AppSpacing.betweenSections),
                _buildSearchBar(),
                const SizedBox(height: AppSpacing.betweenSections),
                if (_results.isNotEmpty) _buildResultCount(),
                if (_results.isNotEmpty) const SizedBox(height: AppSpacing.insideCards),
                Expanded(
                  child: _searching
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.white),
                        )
                      : _buildResultList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.horizontal),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.insideCards,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.orange.shade900.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade100, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Firestore permission denied',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Search won\'t work until rules allow reading registrants. '
            'For database "${FirestoreConfig.databaseId}": open Firebase Console → Firestore → select that database → Rules tab → paste contents of firestore.rules → Publish. See docs/FIRESTORE_DEV_TROUBLESHOOTING.md.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.95),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionContextBanner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Now Checking Into:',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary87.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.mode.displayName.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.goldGradientEnd,
          ),
        ),
        const SizedBox(height: 8),
        Divider(
          height: 1,
          thickness: 2,
          color: AppColors.goldGradientEnd.withValues(alpha: 0.7),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Row(
            children: [
              const Icon(Icons.arrow_back, size: 20, color: AppColors.gold),
              const SizedBox(width: 8),
              Text(
                'Back to Search',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Search Results',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.gold,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.insideCards),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: GoogleFonts.inter(
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Search by last name (min 3 characters)',
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textPrimary87.withValues(alpha: 0.6),
          ),
          border: InputBorder.none,
          icon: const Icon(Icons.search, color: AppColors.navy, size: 24),
        ),
      ),
    );
  }

  Widget _buildResultCount() {
    return Text(
      '${_results.length} match${_results.length == 1 ? '' : 'es'} found',
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.white.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _buildResultList() {
    if (_results.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.trim().length < 2
              ? 'Enter at least 2 characters to search'
              : 'No matches found',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.white.withValues(alpha: 0.7),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.horizontal),
      itemCount: _results.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.betweenSecondaryCards),
      itemBuilder: (context, i) {
        final r = _results[i];
        return RegistrantResultCard(
          registrant: r,
          eventId: _event?.id ?? widget.eventId,
          mode: widget.mode,
          repo: _repo,
          onTap: () => _onSelectRegistrant(r),
        );
      },
    );
  }
}
