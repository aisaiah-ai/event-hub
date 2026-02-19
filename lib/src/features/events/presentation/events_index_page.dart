import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/environment.dart';
import '../data/event_repository.dart';
import '../event_tokens.dart';

/// Events index — /events
/// Redirects to active event if one exists, otherwise shows "no event" message.
class EventsIndexPage extends StatefulWidget {
  const EventsIndexPage({super.key, this.repository});

  final EventRepository? repository;

  @override
  State<EventsIndexPage> createState() => _EventsIndexPageState();
}

class _EventsIndexPageState extends State<EventsIndexPage> {
  late EventRepository _repo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? EventRepository();
    _redirectOrShow();
  }

  Future<void> _redirectOrShow() async {
    // Dev: default to NLC check-in. Prod: use active event (RSVP).
    if (Environment.isDev) {
      if (!mounted) return;
      context.go('/events/nlc/main-checkin');
      return;
    }
    try {
      final event = await _repo.getActiveEvent();
      if (!mounted) return;
      if (event != null) {
        context.go('/events/${event.slug}/rsvp');
        return;
      }
    } catch (_) {
      if (!mounted) return;
      context.go('/events/march-cluster-2026/rsvp');
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: EventTokens.primaryBlue,
        body: const Center(
          child: CircularProgressIndicator(color: EventTokens.textOffWhite),
        ),
      );
    }
    return Scaffold(
      backgroundColor: EventTokens.primaryBlue,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(EventTokens.spacingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No active event',
                style: const TextStyle(
                  color: EventTokens.textOffWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: EventTokens.spacingM),
              Text(
                'Check back later or visit a specific event URL.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: EventTokens.textOffWhite.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
