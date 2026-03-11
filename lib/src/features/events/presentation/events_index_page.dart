import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../data/event_model.dart';
import '../data/event_repository.dart';

/// Events index — /events
/// Shows a schedule of upcoming events with tags (e.g. "Regional Event").
class EventsIndexPage extends StatefulWidget {
  const EventsIndexPage({super.key, this.repository});

  final EventRepository? repository;

  @override
  State<EventsIndexPage> createState() => _EventsIndexPageState();
}

class _EventsIndexPageState extends State<EventsIndexPage> {
  late EventRepository _repo;
  bool _loading = true;
  List<EventModel> _events = [];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? EventRepository();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final events = await _repo.listUpcomingEvents();
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFF4A340)),
              )
            : _events.isEmpty
            ? _buildEmpty()
            : _buildEventsList(),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_busy,
            color: Colors.white.withValues(alpha: 0.4),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'No upcoming events',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new events.',
            style: GoogleFonts.inter(
              color: const Color(0xFF8888A0),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'UPCOMING EVENTS',
                style: GoogleFonts.inter(
                  color: const Color(0xFFF4A340),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Events Schedule',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),

              // Event cards
              ..._events.map(
                (event) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _EventCard(
                    event: event,
                    onTap: () => context.go('/events/${event.slug}'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatefulWidget {
  const _EventCard({required this.event, required this.onTap});
  final EventModel event;
  final VoidCallback onTap;

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final isPast = event.endDate.isBefore(DateTime.now());
    final isMultiDay =
        event.startDate != event.endDate &&
        event.endDate.difference(event.startDate).inDays >= 1;

    String dateText;
    if (isMultiDay) {
      dateText =
          '${DateFormat('MMM d').format(event.startDate)} – ${DateFormat('d, y').format(event.endDate)}';
    } else {
      dateText = DateFormat('MMMM d, y').format(event.startDate);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFF1A1A2E) : const Color(0xFF12121E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered
                  ? const Color(0xFFF4A340).withValues(alpha: 0.3)
                  : const Color(0xFF2A2A3A),
            ),
          ),
          child: Row(
            children: [
              // Date block
              Container(
                width: 60,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4A340).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMM').format(event.startDate).toUpperCase(),
                      style: GoogleFonts.inter(
                        color: const Color(0xFFF4A340),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      '${event.startDate.day}',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Event details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tags row
                    Row(
                      children: [
                        if (event.tag != null) ...[
                          _TagChip(label: event.tag!),
                          const SizedBox(width: 8),
                        ],
                        if (isPast)
                          _TagChip(
                            label: 'PAST',
                            color: const Color(0xFF8888A0),
                          )
                        else if (event.startDate
                                .difference(DateTime.now())
                                .inDays <=
                            7)
                          _TagChip(
                            label: 'UPCOMING',
                            color: const Color(0xFF7AE3A5),
                          ),
                      ],
                    ),
                    if (event.tag != null || isPast) const SizedBox(height: 6),
                    // Event name
                    Text(
                      event.name,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Date + location
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          dateText,
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (event.locationName.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '\u00B7',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              event.locationName,
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (event.shortDescription != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        event.shortDescription!,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF8888A0),
                          fontSize: 12,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, this.color = const Color(0xFFF4A340)});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
