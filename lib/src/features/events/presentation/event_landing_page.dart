import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/event_model.dart';
import '../data/event_repository.dart';
import '../data/event_schedule_model.dart';
import '../data/venue_model.dart';
import '../event_tokens.dart';
import '../widgets/event_page_scaffold.dart';

/// Event landing page — /events/:eventSlug
/// Fetches event by slug, shows 404 if not found.
/// Uses dynamic branding (logo, background) from event.
class EventLandingPage extends StatefulWidget {
  const EventLandingPage({
    super.key,
    required this.eventSlug,
    this.queryParams = const {},
    this.repository,
  });

  final String eventSlug;
  final Map<String, String> queryParams;
  final EventRepository? repository;

  @override
  State<EventLandingPage> createState() => _EventLandingPageState();
}

class _EventLandingPageState extends State<EventLandingPage>
    with TickerProviderStateMixin {
  late EventRepository _repo;
  late TabController _tab;
  Timer? _ticker;

  EventModel? _event;
  List<EventSession> _sessions = [];
  bool _loading = true;
  String? _error;
  DateTime _scheduleUpdatedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _repo = widget.repository ?? EventRepository();
    // Rebuild "Updated X mins ago" label periodically.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tab.dispose();
    super.dispose();
  }

  Future<void> _openMaps(Venue venue) async {
    final fullAddress = venue.fullAddress;
    final query = fullAddress.isNotEmpty ? fullAddress : venue.name;
    if (query.isEmpty) return;
    final url =
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _sessions = [];
    });
    try {
      // ignore: avoid_print
      print('[EventLandingPage] loading slug=${widget.eventSlug}');
      final event = await _repo.getEventBySlug(widget.eventSlug);
      // ignore: avoid_print
      print('[EventLandingPage] event: id=${event?.id} name=${event?.name}');
      if (event != null) {
        // getSessions internally resolves speakers and embeds SessionSpeaker.
        final sessions = await _repo.getSessions(event.id, slug: widget.eventSlug);
        // ignore: avoid_print
        print('[EventLandingPage] loaded ${sessions.length} sessions');
        for (final s in sessions) {
          // ignore: avoid_print
          print('[EventLandingPage]   session: ${s.id} speaker=${s.speaker?.name}');
        }
        setState(() {
          _event = event;
          _sessions = sessions;
          _scheduleUpdatedAt = DateTime.now();
          _loading = false;
        });
      } else {
        // ignore: avoid_print
        print('[EventLandingPage] event not found');
        setState(() {
          _event = null;
          _loading = false;
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('[EventLandingPage] error: $e');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return EventPageScaffold(event: _event, body: _buildBody());
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: EventTokens.textOffWhite),
      );
    }
    if (_error != null) {
      return _buildError();
    }
    if (_event == null) {
      return _buildNotFound();
    }
    return _buildContent(_event!);
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(EventTokens.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: EventTokens.textOffWhite,
              size: 48,
            ),
            const SizedBox(height: EventTokens.spacingM),
            const Text(
              'Something went wrong',
              style: TextStyle(
                color: EventTokens.textOffWhite,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: EventTokens.spacingS),
            TextButton(
              onPressed: _load,
              child: const Text(
                'Retry',
                style: TextStyle(color: EventTokens.accentGold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(EventTokens.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, color: EventTokens.textOffWhite, size: 48),
            const SizedBox(height: EventTokens.spacingM),
            const Text(
              'Event not found',
              style: TextStyle(
                color: EventTokens.textOffWhite,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: EventTokens.spacingS),
            Text(
              "The event you're looking for doesn't exist or has been removed.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: EventTokens.textOffWhite.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(EventModel event) {
    final theme = _EventTheme.from(event);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          children: [
            _EventHeader(
              event: event,
              theme: theme,
              onOpenMaps: () => _openMaps(event.effectiveVenue),
            ),
            if (event.shortDescription != null &&
                event.shortDescription!.isNotEmpty)
              _ShortDescriptionBlock(
                text: event.shortDescription!,
                theme: theme,
              ),
            _RegisterButton(
              event: event,
              theme: theme,
              onRegister: () {
                final uri = Uri(
                  path: '/events/${event.slug}/rsvp',
                  queryParameters:
                      widget.queryParams.isNotEmpty ? widget.queryParams : null,
                );
                context.push(uri.toString());
              },
            ),
            const SizedBox(height: 20),
            _TabsHeader(tab: _tab, updatedAt: _scheduleUpdatedAt, theme: theme),
            const SizedBox(height: 12),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.90,
              child: TabBarView(
                controller: _tab,
                children: [
                  _ScheduleTab(
                    event: event,
                    sessions: _sessions,
                    theme: theme,
                    onCheckIn: () =>
                        context.push('/events/${event.slug}/checkin'),
                  ),
                  const _AnnouncementsEmpty(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Design tokens (dark theme matching mockup) ─────────────────────────────

const _kCard = Color(0xFF141420);
const _kBorder = Color(0x22FFFFFF);
const _kTextMuted = Color(0xFFA7A7B3);
const _kChipBg = Color(0xFF17202A);
const _kRail = Color(0x33FFFFFF);
const _kGreenAccent = Color(0xFF7AE3A5);

/// Lightweight branding token holder derived from [EventModel].
/// Falls back to the dark-theme defaults when event branding is absent.
class _EventTheme {
  const _EventTheme({
    required this.primary,
    required this.accent,
    required this.cardBackgroundColor,
    required this.checkInButtonColor,
  });

  final Color primary;
  final Color accent;
  final Color cardBackgroundColor;
  final Color checkInButtonColor;

  factory _EventTheme.from(EventModel event) => _EventTheme(
        primary: event.primaryColor,
        accent: event.accentColor,
        cardBackgroundColor: event.cardBackgroundColor,
        checkInButtonColor: event.checkInButtonColor,
      );
}

// ─── Event Header (logo + title, date, venue, Get Directions) ─────────────────

class _EventHeader extends StatelessWidget {
  const _EventHeader({
    required this.event,
    required this.theme,
    required this.onOpenMaps,
  });

  final EventModel event;
  final _EventTheme theme;
  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final venue = event.effectiveVenue;
    final logoUrl = event.effectiveLogoUrl;
    final hasLogo = logoUrl != null && logoUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.cardBackgroundColor.withOpacity(0.68),
            theme.cardBackgroundColor.withOpacity(0.62),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasLogo) ...[
            _EventHeaderLogo(logoUrl: logoUrl),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  event.displayDate,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (venue.name.isNotEmpty)
                  Text(
                    venue.name,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (venue.street.isNotEmpty)
                  Text(
                    venue.street,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.70),
                      fontSize: 14,
                    ),
                  ),
                if (venue.city.isNotEmpty || venue.state.isNotEmpty || venue.zip.isNotEmpty)
                  Text(
                    [venue.city, venue.state, venue.zip]
                        .where((s) => s.isNotEmpty)
                        .join(' '),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.70),
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: (venue.fullAddress.isNotEmpty || venue.name.isNotEmpty)
                      ? onOpenMaps
                      : null,
                  child: Text(
                    'Get Directions',
                    style: TextStyle(
                      color: theme.primary,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: theme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Logo in header: CachedNetworkImage for URLs, Image.asset for assets.
class _EventHeaderLogo extends StatelessWidget {
  const _EventHeaderLogo({required this.logoUrl});

  final String logoUrl;

  static bool _isAssetPath(String path) => path.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    if (_isAssetPath(logoUrl)) {
      return SizedBox(
        height: 72,
        width: 120,
        child: Image.asset(
          logoUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox(height: 72, width: 120),
        ),
      );
    }
    return SizedBox(
      height: 72,
      width: 120,
      child: CachedNetworkImage(
        imageUrl: logoUrl,
        fit: BoxFit.contain,
        fadeInDuration: const Duration(milliseconds: 300),
        errorWidget: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

// ─── Short event description (below header, above register button) ─────────────

class _ShortDescriptionBlock extends StatelessWidget {
  const _ShortDescriptionBlock({
    required this.text,
    required this.theme,
  });

  final String text;
  final _EventTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.cardBackgroundColor.withOpacity(0.68),
            theme.cardBackgroundColor.withOpacity(0.62),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          height: 1.4,
          color: Colors.white.withOpacity(0.92),
        ),
      ),
    );
  }
}

// ─── Register to Event (secondary button) ─────────────────────────────────────

class _RegisterButton extends StatelessWidget {
  const _RegisterButton({
    required this.event,
    required this.theme,
    required this.onRegister,
  });

  final EventModel event;
  final _EventTheme theme;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final isRegistered = event.isRegistered == true;
    final isPending =
        event.registrationStatus?.toLowerCase() == 'pending';

    String label;
    if (isRegistered) {
      label = 'Registered ✓';
    } else if (isPending) {
      label = 'Pending Approval';
    } else {
      label = 'Register to Event';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 0),
      child: SizedBox(
        height: 48,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: isRegistered ? null : onRegister,
          style: OutlinedButton.styleFrom(
            backgroundColor: theme.accent.withValues(alpha: 0.18),
            foregroundColor: theme.accent,
            side: BorderSide(
              color: theme.accent.withValues(alpha: 0.35),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Tabs Header (Schedule / Announcements + updated chip + Today button) ────

class _TabsHeader extends StatelessWidget {
  const _TabsHeader({
    required this.tab,
    required this.updatedAt,
    required this.theme,
  });

  final TabController tab;
  final DateTime updatedAt;
  final _EventTheme theme;

  String _updatedLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return 'Updated ${diff.inHours} hrs ago';
    return 'Updated ${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.cardBackgroundColor.withOpacity(0.68),
            theme.cardBackgroundColor.withOpacity(0.62),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: tab,
                  labelColor: Colors.white.withOpacity(0.92),
                  unselectedLabelColor: Colors.white.withOpacity(0.70),
                  labelStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  indicatorColor: theme.primary,
                  indicatorWeight: 2.5,
                  dividerColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  tabAlignment: TabAlignment.start,
                  isScrollable: true,
                  tabs: const [
                    Tab(text: 'Schedule'),
                    Tab(text: 'Announcements'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz_rounded, color: _kTextMuted),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // "Updated X mins ago" chip
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.cardBackgroundColor.withOpacity(0.68),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _updatedLabel(updatedAt),
                      style: const TextStyle(
                        color: _kGreenAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.refresh_rounded,
                      size: 14,
                      color: _kGreenAccent,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // "Today >" button
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.cardBackgroundColor.withOpacity(0.68),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 16, color: theme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Today',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Colors.white.withOpacity(0.70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Schedule Tab ─────────────────────────────────────────────────────────────

class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab({
    required this.event,
    required this.sessions,
    required this.theme,
    required this.onCheckIn,
  });

  final EventModel event;
  final List<EventSession> sessions;
  final _EventTheme theme;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(EventTokens.spacingL),
        child: Text(
          'No sessions yet.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.70),
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 6, bottom: 120),
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final s = sessions[i];
        return _SessionTimelineCard(
          session: s,
          eventSlug: event.slug,
          showCheckIn: event.allowCheckin,
          theme: theme,
          onCheckIn: onCheckIn,
        );
      },
    );
  }
}

// ─── Session Timeline Card ────────────────────────────────────────────────────

class _SessionTimelineCard extends StatelessWidget {
  const _SessionTimelineCard({
    required this.session,
    required this.eventSlug,
    required this.showCheckIn,
    required this.theme,
    required this.onCheckIn,
  });

  final EventSession session;
  /// Event slug forwarded to [_SpeakerRow] so it can pass [eventSlug] to
  /// [SpeakerDetailsPage] for branding and speaker sub-collection lookup.
  final String eventSlug;
  final bool showCheckIn;
  final _EventTheme theme;
  final VoidCallback onCheckIn;

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat.jm().format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = session.speaker != null ||
        session.materials.isNotEmpty ||
        (session.description != null && session.description!.isNotEmpty);
    final isMainCheckIn = session.id == 'main-checkin';

    return Container(
      decoration: BoxDecoration(
        gradient: isMainCheckIn
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.checkInButtonColor.withOpacity(0.11),
                  theme.cardBackgroundColor.withOpacity(0.68),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.cardBackgroundColor.withOpacity(0.68),
                  theme.cardBackgroundColor.withOpacity(0.62),
                ],
              ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMainCheckIn
              ? theme.checkInButtonColor.withOpacity(0.25)
              : Colors.white.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time label
          SizedBox(
            width: 76,
            child: Text(
              _formatTime(session.startAt),
              style: TextStyle(
                color: Colors.white.withOpacity(0.92),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Timeline dot + rail
          Column(
            children: [
              const SizedBox(height: 4),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: theme.primary.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 2,
                height: hasContent ? 48 : 24,
                color: _kRail,
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Content: left-flow vertical structure
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Text(
                  session.displayName,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),

                if (session.speaker != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.mic_rounded, size: 13, color: _kTextMuted),
                      const SizedBox(width: 4),
                      Text(
                        'Guest Speaker',
                        style: TextStyle(
                          color: _kTextMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SpeakerRow(
                    speaker: session.speaker!,
                    eventSlug: eventSlug,
                    theme: theme,
                  ),
                ],

                if (session.materials.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final m in session.materials) ...[
                    _MaterialRow(
                      theme: theme,
                      title: m.title,
                      typeLabel: m.type.toUpperCase(),
                      onTap: () {},
                    ),
                    if (m != session.materials.last) const SizedBox(height: 8),
                  ],
                ],

                if (session.description != null &&
                    session.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    session.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.70),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],

                if (showCheckIn) ...[
                  const SizedBox(height: 12),
                  _SessionCheckInButton(
                    session: session,
                    theme: theme,
                    onCheckIn: onCheckIn,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Session check-in button (left-aligned; main check-in full width) ─────────

class _SessionCheckInButton extends StatelessWidget {
  const _SessionCheckInButton({
    required this.session,
    required this.theme,
    required this.onCheckIn,
  });

  final EventSession session;
  final _EventTheme theme;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final isMainCheckIn = session.id == 'main-checkin';
    final checkedIn = session.sessionCheckedIn;

    if (isMainCheckIn) {
      final brighter = Color.lerp(
        theme.checkInButtonColor,
        Colors.white,
        0.2,
      )!;
      return SizedBox(
        height: 42,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: checkedIn ? null : onCheckIn,
          style: OutlinedButton.styleFrom(
            backgroundColor: brighter.withOpacity(0.40),
            foregroundColor: Colors.white,
            disabledBackgroundColor: brighter.withOpacity(0.12),
            disabledForegroundColor: Colors.white,
            side: BorderSide(
              color: brighter.withOpacity(0.45),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: Text(
            checkedIn ? 'Checked In ✓' : 'Event Check In',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    final backgroundColor = checkedIn
        ? theme.checkInButtonColor.withOpacity(0.35)
        : theme.checkInButtonColor.withOpacity(0.9);

    return IntrinsicWidth(
      child: SizedBox(
        height: 36,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: Colors.white.withOpacity(0.92),
            disabledBackgroundColor: backgroundColor,
            disabledForegroundColor: Colors.white.withOpacity(0.92),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          onPressed: checkedIn ? null : onCheckIn,
          child: Text(
            checkedIn ? 'Checked In ✓' : 'Check In',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Speaker Row ──────────────────────────────────────────────────────────────

class _SpeakerRow extends StatelessWidget {
  const _SpeakerRow({
    required this.speaker,
    required this.eventSlug,
    required this.theme,
  });

  final SessionSpeaker speaker;
  /// Event slug passed to [SpeakerDetailsPage] for branding + sub-collection lookup.
  final String eventSlug;
  final _EventTheme theme;

  void _navigate(BuildContext context) {
    final speakerId = speaker.speakerId;
    if (speakerId != null && speakerId.isNotEmpty) {
      // Full profile: fetch speaker document from Firestore.
      context.push(
        Uri(
          path: '/speaker/$speakerId',
          queryParameters: {'eventSlug': eventSlug},
        ).toString(),
      );
    } else {
      // Fallback: speaker came from denormalized API strings — no document ID.
      // Show the lightweight preview we already have.
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _SpeakerBottomSheet(speaker: speaker, theme: theme),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _navigate(context),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.cardBackgroundColor.withOpacity(0.68),
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withOpacity(0.05), width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: _speakerPhoto(speaker, size: 38),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  speaker.name,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (speaker.title != null && speaker.title!.isNotEmpty)
                  Text(
                    speaker.title!,
                    style: const TextStyle(
                      color: _kTextMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          // Chevron only when a full profile is navigable (speakerId known).
          if (speaker.speakerId != null)
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: _kTextMuted,
            ),
        ],
      ),
    );
  }
}

/// Returns the correct image widget for a [SessionSpeaker] photo:
/// - asset path  → Image.asset  (bundled, works offline)
/// - network URL → Image.network (Firebase Storage download URL)
/// - absent      → initials avatar fallback
Widget _speakerPhoto(SessionSpeaker speaker, {double size = 38}) {
  final url = speaker.imageUrl;
  if (url == null || url.isEmpty) return _SpeakerInitialsAvatar(speaker.name);

  if (url.startsWith('assets/')) {
    return Image.asset(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _SpeakerInitialsAvatar(speaker.name),
    );
  }

  return Image.network(
    url,
    width: size,
    height: size,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => _SpeakerInitialsAvatar(speaker.name),
  );
}

/// Polished initials avatar — derives background color from the speaker's name
/// so each person gets a consistent, distinct color.
class _SpeakerInitialsAvatar extends StatelessWidget {
  const _SpeakerInitialsAvatar(this.name);
  final String name;

  /// Deterministic color from name string — cycles through a palette of
  /// pleasant accent colors that look good on dark backgrounds.
  static const _palette = [
    Color(0xFF6D4CFF), // purple
    Color(0xFF3E7D4C), // green
    Color(0xFFE0B646), // gold
    Color(0xFF4C7FE0), // blue
    Color(0xFFE0614C), // coral
    Color(0xFF4CE0C6), // teal
    Color(0xFFB44CE0), // violet
    Color(0xFFE04CAA), // pink
  ];

  Color _colorFor(String name) {
    var hash = 0;
    for (final c in name.codeUnits) {
      hash = (hash * 31 + c) & 0xFFFFFFFF;
    }
    return _palette[hash % _palette.length];
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final bg = _colorFor(name);
    return Container(
      color: bg.withValues(alpha: 0.85),
      child: Center(
        child: Text(
          _initials(name),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ─── Speaker Bottom Sheet ─────────────────────────────────────────────────────

class _SpeakerBottomSheet extends StatelessWidget {
  const _SpeakerBottomSheet({
    required this.speaker,
    required this.theme,
  });

  final SessionSpeaker speaker;
  final _EventTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Large avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.primary.withOpacity(0.30),
                  width: 2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _speakerPhoto(speaker, size: 80),
            ),
            const SizedBox(height: 14),

            // Name
            Text(
              speaker.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),

            // Title
            if (speaker.title != null && speaker.title!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                speaker.title!,
                style: const TextStyle(
                  color: _kTextMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // Bio
            if (speaker.bio != null && speaker.bio!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
                child: Text(
                  speaker.bio!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.80),
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            ],

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

// ─── Material Download Row ────────────────────────────────────────────────────

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({
    required this.theme,
    required this.title,
    required this.typeLabel,
    required this.onTap,
  });

  final _EventTheme theme;
  final String title;
  final String typeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.cardBackgroundColor.withOpacity(0.68),
                theme.cardBackgroundColor.withOpacity(0.62),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              // Download icon box
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.cardBackgroundColor.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
                ),
                child: const Icon(
                  Icons.download_rounded,
                  size: 18,
                  color: _kGreenAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$title ($typeLabel)',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Announcements Empty State ────────────────────────────────────────────────

class _AnnouncementsEmpty extends StatelessWidget {
  const _AnnouncementsEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: EventTokens.spacingXL),
      child: Center(
        child: Text(
          'No announcements yet.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.70),
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
