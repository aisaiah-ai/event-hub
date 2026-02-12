import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/event_model.dart';
import '../data/event_repository.dart';
import '../event_tokens.dart';
import '../widgets/event_page_scaffold.dart';

/// Check-in entry placeholder — /events/:eventSlug/checkin
/// "Staff Login Required" until role-based auth is implemented.
/// Uses dynamic branding from event.
class EventCheckinEntryPage extends StatefulWidget {
  const EventCheckinEntryPage({
    super.key,
    required this.eventSlug,
    this.repository,
  });

  final String eventSlug;
  final EventRepository? repository;

  @override
  State<EventCheckinEntryPage> createState() => _EventCheckinEntryPageState();
}

class _EventCheckinEntryPageState extends State<EventCheckinEntryPage> {
  late EventRepository _repo;
  EventModel? _event;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? EventRepository();
    _load();
  }

  Future<void> _load() async {
    try {
      final event = await _repo.getEventBySlug(widget.eventSlug);
      if (mounted) {
        setState(() {
          _event = event;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return EventPageScaffold(
      event: _event,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: EventTokens.textOffWhite),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/events/${widget.eventSlug}'),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: EventTokens.textOffWhite),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(EventTokens.spacingL),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 64,
                      color: EventTokens.textOffWhite.withValues(alpha: 0.8),
                    ),
                    const SizedBox(height: EventTokens.spacingL),
                    Text(
                      'Staff Login Required',
                      style: const TextStyle(
                        color: EventTokens.textOffWhite,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: EventTokens.spacingM),
                    Text(
                      'Check-in is available to authorized staff only. '
                      'Please sign in to access the check-in portal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: EventTokens.textOffWhite.withValues(alpha: 0.8),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: EventTokens.spacingXL),
                    FilledButton(
                      onPressed: () {
                        final q = <String, String>{
                          'eventId': _event?.id ?? widget.eventSlug,
                          if (_event != null) 'eventTitle': _event!.name,
                          if (_event != null)
                            'eventVenue':
                                '${_event!.locationName}, ${_event!.address}',
                          if (_event != null)
                            'eventDate': _event!.startDate
                                .toIso8601String()
                                .split('T')
                                .first,
                        };
                        context.go(
                          Uri(path: '/checkin', queryParameters: q).toString(),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            _event?.accentColor ?? EventTokens.accentGold,
                        foregroundColor: EventTokens.textPrimary,
                      ),
                      child: const Text('Go to Check-in'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
