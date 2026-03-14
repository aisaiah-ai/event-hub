import 'dart:async';
import 'dart:math';

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
/// Full-screen hero with countdown, action buttons, and live schedule.
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
    // Tick every second for countdown, also refreshes schedule "ago" label.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
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
      final event = await _repo.getEventBySlug(widget.eventSlug);
      if (event != null) {
        final sessions = await _repo.getSessions(
          event.id,
          slug: widget.eventSlug,
        );
        // Filter out the background check-in session from schedule display.
        final visible = sessions
            .where((s) => s.id != 'main' && s.id != 'main-checkin')
            .toList();
        setState(() {
          _event = event;
          _sessions = visible;
          _scheduleUpdatedAt = DateTime.now();
          _loading = false;
        });
      } else {
        setState(() {
          _event = null;
          _loading = false;
        });
      }
    } catch (e) {
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
    if (_error != null) return _buildError();
    if (_event == null) return _buildNotFound();
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
            const Icon(
              Icons.search_off,
              color: EventTokens.textOffWhite,
              size: 48,
            ),
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
    final now = DateTime.now();

    // Sort sessions: upcoming/current first, past at bottom.
    final upcoming = <EventSession>[];
    final past = <EventSession>[];
    for (final s in _sessions) {
      if (s.endAt != null && s.endAt!.isBefore(now)) {
        past.add(s);
      } else {
        upcoming.add(s);
      }
    }
    final sortedSessions = [...upcoming, ...past];

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            // ── Full-screen hero section ──
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.85,
                child: _HeroSection(
                  event: event,
                  theme: theme,
                  onOpenMaps: () => _openMaps(event.effectiveVenue),
                  onRegister: () {
                    final uri = Uri(
                      path: '/events/${event.slug}/rsvp',
                      queryParameters: widget.queryParams.isNotEmpty
                          ? widget.queryParams
                          : null,
                    );
                    context.push(uri.toString());
                  },
                  onViewAgenda: () {
                    // Scroll down to schedule
                    Scrollable.ensureVisible(
                      _scheduleKey.currentContext ?? context,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  },
                  onSpeakers: () =>
                      context.push('/events/${event.slug}/dashboard'),
                  onCheckin: () =>
                      context.push('/events/${event.slug}/checkin'),
                ),
              ),
            ),

            // ── Schedule section ──
            SliverToBoxAdapter(
              key: _scheduleKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _TabsHeader(
                      tab: _tab,
                      updatedAt: _scheduleUpdatedAt,
                      theme: theme,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // ── Tab content ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  height: max(
                    MediaQuery.of(context).size.height * 0.90,
                    sortedSessions.length * 140.0 + 300,
                  ),
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _ScheduleTab(
                        event: event,
                        sessions: sortedSessions,
                        pastSessionIds: past.map((s) => s.id).toSet(),
                        theme: theme,
                        onCheckIn: () =>
                            context.push('/events/${event.slug}/checkin'),
                      ),
                      const _AnnouncementsEmpty(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  final _scheduleKey = GlobalKey();
}

// ─── Design tokens (dark theme matching mockup) ─────────────────────────────

const _kCard = Color(0xFF141420);
const _kTextMuted = Color(0xFFA7A7B3);
const _kRail = Color(0x33FFFFFF);
const _kGreenAccent = Color(0xFF7AE3A5);

/// Lightweight branding token holder derived from [EventModel].
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

// ─── Full-screen Hero Section ─────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.event,
    required this.theme,
    required this.onOpenMaps,
    required this.onRegister,
    required this.onViewAgenda,
    required this.onSpeakers,
    required this.onCheckin,
  });

  final EventModel event;
  final _EventTheme theme;
  final VoidCallback onOpenMaps;
  final VoidCallback onRegister;
  final VoidCallback onViewAgenda;
  final VoidCallback onSpeakers;
  final VoidCallback onCheckin;

  @override
  Widget build(BuildContext context) {
    final venue = event.effectiveVenue;
    final logoUrl = event.effectiveLogoUrl;
    final hasLogo = logoUrl != null && logoUrl.isNotEmpty;

    // Time range from metadata
    final rallyTime = event.rallyTimeText;
    final dinnerTime = event.dinnerTimeText;
    String timeRange = '';
    if (rallyTime != null) {
      final startPart = rallyTime.split('–').first.split('-').first.trim();
      if (dinnerTime != null) {
        final endPart = dinnerTime.split('–').last.split('-').last.trim();
        timeRange = '$startPart – $endPart';
      } else {
        timeRange = rallyTime;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // Logo
          if (hasLogo) ...[
            _EventHeaderLogo(logoUrl: logoUrl, size: 100),
            const SizedBox(height: 16),
          ],

          // Event name
          Text(
            event.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.3,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 14),

          // Date, time, location row
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 6,
            children: [
              _InfoChip(
                icon: Icons.calendar_today_rounded,
                label: DateFormat('MMMM d, yyyy').format(event.startDate),
              ),
              if (timeRange.isNotEmpty)
                _InfoChip(icon: Icons.access_time_rounded, label: timeRange),
              if (venue.name.isNotEmpty)
                _InfoChip(
                  icon: Icons.location_on_outlined,
                  label: venue.city.isNotEmpty
                      ? '${venue.name}, ${venue.city}'
                      : venue.name,
                  onTap: onOpenMaps,
                ),
            ],
          ),

          const SizedBox(height: 24),

          // Action buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Opacity(
                opacity: 0.5,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _ActionButton(
                      label: 'Register Now',
                      onTap: () {},
                      textColor: theme.accent.withOpacity(0.4),
                      borderColor: theme.accent.withOpacity(0.2),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'CLOSED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _ActionButton(
                label: 'View Agenda',
                onTap: onViewAgenda,
                filled: true,
                fillColor: theme.primary,
                textColor: Colors.white,
                borderColor: theme.primary,
              ),
              const SizedBox(width: 10),
              _ActionButton(
                label: 'Check In',
                onTap: onCheckin,
                filled: true,
                fillColor: const Color(0xFF2B9E7A),
                textColor: Colors.white,
                borderColor: const Color(0xFF2B9E7A),
              ),
              const SizedBox(width: 10),
              _ActionButton(
                label: 'Dashboard',
                onTap: onSpeakers,
                textColor: Colors.white.withOpacity(0.85),
                borderColor: Colors.white.withOpacity(0.2),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Countdown timer
          _CountdownTimer(eventDate: event.startDate, theme: theme),

          const Spacer(flex: 3),

          // Scroll hint
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white.withOpacity(0.4),
            size: 32,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Info chip (date, time, location) ─────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white.withOpacity(0.6)),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: child);
    }
    return child;
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    required this.textColor,
    required this.borderColor,
    this.filled = false,
    this.fillColor,
  });

  final String label;
  final VoidCallback onTap;
  final Color textColor;
  final Color borderColor;
  final bool filled;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? fillColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─── Countdown Timer ──────────────────────────────────────────────────────────

class _CountdownTimer extends StatelessWidget {
  const _CountdownTimer({required this.eventDate, required this.theme});

  final DateTime eventDate;
  final _EventTheme theme;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final target = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final diff = target.difference(now);

    // If event is today or past, show "Event is live!" or "Event has ended"
    if (diff.isNegative && diff.inDays < -1) {
      return _buildLabel('Event has ended');
    }

    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;

    if (days <= 0 && hours <= 0 && minutes <= 0) {
      return _buildLabel('Event is live!');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF141420).withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CountdownUnit(value: days, label: 'DAYS'),
          _countdownSeparator(),
          _CountdownUnit(value: hours, label: 'HOURS'),
          _countdownSeparator(),
          _CountdownUnit(value: minutes, label: 'MIN'),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141420).withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: theme.accent,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _countdownSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text(
        ':',
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 28,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}

class _CountdownUnit extends StatelessWidget {
  const _CountdownUnit({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─── Event Header Logo ────────────────────────────────────────────────────────

class _EventHeaderLogo extends StatelessWidget {
  const _EventHeaderLogo({required this.logoUrl, this.size = 72});

  final String logoUrl;
  final double size;

  static bool _isAssetPath(String path) => path.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    if (_isAssetPath(logoUrl)) {
      return SizedBox(
        height: size,
        width: size * 1.5,
        child: Image.asset(
          logoUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => SizedBox(height: size, width: size * 1.5),
        ),
      );
    }
    return SizedBox(
      height: size,
      width: size * 1.5,
      child: CachedNetworkImage(
        imageUrl: logoUrl,
        fit: BoxFit.contain,
        fadeInDuration: const Duration(milliseconds: 300),
        errorWidget: (_, _, _) => const SizedBox.shrink(),
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
                  border: Border.all(
                    color: Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
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
                  border: Border.all(
                    color: Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 16,
                      color: theme.primary,
                    ),
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
    required this.pastSessionIds,
    required this.theme,
    required this.onCheckIn,
  });

  final EventModel event;
  final List<EventSession> sessions;
  final Set<String> pastSessionIds;
  final _EventTheme theme;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(EventTokens.spacingL),
        child: Text(
          'No sessions yet.',
          style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 14),
        ),
      );
    }

    // Find separator index between upcoming and past
    final firstPastIndex = sessions.indexWhere(
      (s) => pastSessionIds.contains(s.id),
    );

    return ListView.separated(
      padding: const EdgeInsets.only(top: 6, bottom: 120),
      itemCount:
          sessions.length +
          1 + // ANCOP campaign card
          (firstPastIndex > 0 ? 1 : 0), // past divider
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        // Insert "Past Sessions" divider
        if (firstPastIndex > 0 && i == firstPastIndex) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'PAST',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ],
            ),
          );
        }

        // Adjust index for past divider
        final sessionIndex = firstPastIndex > 0 && i > firstPastIndex
            ? i - 1
            : i;

        if (sessionIndex < sessions.length) {
          final s = sessions[sessionIndex];
          final isPast = pastSessionIds.contains(s.id);
          return Opacity(
            opacity: isPast ? 0.5 : 1.0,
            child: _SessionTimelineCard(
              session: s,
              eventSlug: event.slug,
              showCheckIn: event.allowCheckin,
              theme: theme,
              onCheckIn: onCheckIn,
              isPast: isPast,
            ),
          );
        }
        // ANCOP Campaign card at the end
        return const _AncopCampaignCard();
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
    this.isPast = false,
  });

  final EventSession session;
  final String eventSlug;
  final bool showCheckIn;
  final _EventTheme theme;
  final VoidCallback onCheckIn;
  final bool isPast;

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat.jm().format(dt);
  }

  /// Check if this session is currently happening.
  bool get _isLive {
    final now = DateTime.now();
    return session.startAt != null &&
        session.endAt != null &&
        now.isAfter(session.startAt!) &&
        now.isBefore(session.endAt!);
  }

  @override
  Widget build(BuildContext context) {
    final hasContent =
        session.speaker != null ||
        session.materials.isNotEmpty ||
        (session.description != null && session.description!.isNotEmpty);
    final isMainCheckIn = session.id == 'main-checkin';
    final isLive = _isLive;

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
          color: isLive
              ? _kGreenAccent.withOpacity(0.4)
              : isMainCheckIn
              ? theme.checkInButtonColor.withOpacity(0.25)
              : Colors.white.withOpacity(0.05),
          width: isLive ? 1.5 : 1,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatTime(session.startAt),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (isLive)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _kGreenAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: _kGreenAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
              ],
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
                  color: isLive
                      ? _kGreenAccent
                      : theme.primary.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 6),
              Container(width: 2, height: hasContent ? 48 : 24, color: _kRail),
            ],
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

                if (showCheckIn && session.registrationRequired) ...[
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

// ─── Session check-in button ──────────────────────────────────────────────────

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
      final brighter = Color.lerp(theme.checkInButtonColor, Colors.white, 0.2)!;
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
            side: BorderSide(color: brighter.withOpacity(0.45)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: Text(
            checkedIn ? 'Checked In ✓' : 'Event Check In',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
  final String eventSlug;
  final _EventTheme theme;

  void _navigate(BuildContext context) {
    final speakerId = speaker.speakerId;
    if (speakerId != null && speakerId.isNotEmpty) {
      context.push(
        Uri(
          path: '/speaker/$speakerId',
          queryParameters: {'eventSlug': eventSlug},
        ).toString(),
      );
    } else {
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
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
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

/// Speaker photo helper.
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

class _SpeakerInitialsAvatar extends StatelessWidget {
  const _SpeakerInitialsAvatar(this.name);
  final String name;

  static const _palette = [
    Color(0xFF6D4CFF),
    Color(0xFF3E7D4C),
    Color(0xFFE0B646),
    Color(0xFF4C7FE0),
    Color(0xFFE0614C),
    Color(0xFF4CE0C6),
    Color(0xFFB44CE0),
    Color(0xFFE04CAA),
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
  const _SpeakerBottomSheet({required this.speaker, required this.theme});

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
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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
            Text(
              speaker.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
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
            if (speaker.bio != null && speaker.bio!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
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
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.cardBackgroundColor.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
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
          style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 14),
        ),
      ),
    );
  }
}

// ─── ANCOP Campaign Card ────────────────────────────────────────────────────

class _AncopCampaignCard extends StatelessWidget {
  const _AncopCampaignCard();

  static const _campaignUrl = 'https://ancop.app.link/FpkHxKCkzTb';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2E1A), Color(0xFF0F1F14), Color(0xFF162016)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A4A2A)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CE0A0).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _launchCampaign(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF4A340), Color(0xFFE87D2E)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite, size: 12, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(
                        'COMMUNITY CAMPAIGN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Content row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFF4A340),
                          width: 2,
                        ),
                        image: const DecorationImage(
                          image: AssetImage(
                            'assets/images/speakers/art_barlaan.jpg',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Bro Art's Big 70th Birthday\nANCOP Campaign",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'A personal campaign sponsored by Arthur Barlaan',
                            style: TextStyle(
                              color: const Color(0xFFA7A7B3),
                              fontSize: 13,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // CTA button
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF4A340), Color(0xFFE87D2E)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _launchCampaign(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.open_in_new,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Support This Campaign',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchCampaign() async {
    final uri = Uri.parse(_campaignUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
