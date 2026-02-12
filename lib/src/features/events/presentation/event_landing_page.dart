import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/event_model.dart';
import '../data/event_repository.dart';
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

class _EventLandingPageState extends State<EventLandingPage> {
  late EventRepository _repo;
  EventModel? _event;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? EventRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final event = await _repo.getEventBySlug(widget.eventSlug);
      setState(() {
        _event = event;
        _loading = false;
      });
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
            Text(
              'Something went wrong',
              style: const TextStyle(
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
            Text(
              'Event not found',
              style: const TextStyle(
                color: EventTokens.textOffWhite,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: EventTokens.spacingS),
            Text(
              'The event you\'re looking for doesn\'t exist or has been removed.',
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
    final orgName = event.organizationName ?? 'Couples for Christ';
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(EventTokens.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: EventTokens.spacingL),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EventLogo(logoUrl: event.logoUrl),
                const SizedBox(width: EventTokens.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        orgName,
                        style: TextStyle(
                          color: EventTokens.textOffWhite.withValues(
                            alpha: 0.9,
                          ),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: EventTokens.spacingS),
                      Text(
                        event.name,
                        style: const TextStyle(
                          color: EventTokens.textOffWhite,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: EventTokens.spacingS),
                      Text(
                        '${event.dateRangeText} • ${event.locationName}',
                        style: TextStyle(
                          color: EventTokens.textOffWhite.withValues(
                            alpha: 0.9,
                          ),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: EventTokens.spacingXL),
            if (event.allowRsvp)
              _ActionButton(
                label: 'RSVP',
                icon: Icons.edit_note,
                onTap: () {
                  final uri = Uri(
                    path: '/events/${event.slug}/rsvp',
                    queryParameters: widget.queryParams.isNotEmpty
                        ? widget.queryParams
                        : null,
                  );
                  context.push(uri.toString());
                },
              ),
            if (event.allowRsvp && event.allowCheckin)
              const SizedBox(height: EventTokens.spacingM),
            if (event.allowCheckin) ...[
              _ActionButton(
                label: 'Check-in',
                icon: Icons.qr_code_scanner,
                onTap: () => context.push('/events/${event.slug}/checkin'),
              ),
              const SizedBox(height: EventTokens.spacingM),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EventTokens.radiusLarge),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: EventTokens.surfaceCard,
            borderRadius: BorderRadius.circular(EventTokens.radiusLarge),
            border: Border.all(
              color: EventTokens.textPrimary.withValues(alpha: 0.15),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: EventTokens.spacingM),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: EventTokens.textPrimary, size: 24),
              const SizedBox(width: EventTokens.spacingM),
              Text(
                label,
                style: const TextStyle(
                  color: EventTokens.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
