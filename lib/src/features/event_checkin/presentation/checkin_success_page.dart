import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../events/data/event_model.dart';
import '../../events/data/event_repository.dart';
import '../../events/event_tokens.dart';
import '../../events/widgets/event_page_scaffold.dart';

/// Success page after check-in. Auto-returns to landing after 3 seconds.
class CheckinSuccessPage extends StatefulWidget {
  const CheckinSuccessPage({
    super.key,
    required this.name,
    required this.sessionName,
    required this.eventSlug,
    this.returnPath,
  });

  final String name;
  final String sessionName;
  final String eventSlug;
  /// Where to redirect after 3s; defaults to /events/:slug/checkin.
  final String? returnPath;

  @override
  State<CheckinSuccessPage> createState() => _CheckinSuccessPageState();
}

class _CheckinSuccessPageState extends State<CheckinSuccessPage> {
  Timer? _timer;
  EventModel? _event;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _loadEvent();
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        context.go(widget.returnPath ?? '/events/${widget.eventSlug}/checkin');
      }
    });
  }

  Future<void> _loadEvent() async {
    final event = await EventRepository().getEventBySlug(widget.eventSlug);
    if (mounted) setState(() => _event = event);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EventPageScaffold(
      event: _event,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(EventTokens.spacingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: EventTokens.accentGold,
                size: 80,
              ),
              const SizedBox(height: EventTokens.spacingL),
              Text(
                'Checked In Successfully',
                style: GoogleFonts.fraunces(
                  color: EventTokens.textOffWhite,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: EventTokens.spacingL),
              Text(
                widget.name,
                style: const TextStyle(
                  color: EventTokens.textOffWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: EventTokens.spacingS),
              Text(
                widget.sessionName,
                style: TextStyle(
                  color: EventTokens.textOffWhite.withValues(alpha: 0.9),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: EventTokens.spacingS),
              Text(
                _formatTime(DateTime.now()),
                style: TextStyle(
                  color: EventTokens.textOffWhite.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: EventTokens.spacingXL),
              Text(
                'Returning to check-in in 3 seconds...',
                style: TextStyle(
                  color: EventTokens.textOffWhite.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final am = t.hour < 12 ? 'AM' : 'PM';
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m $am';
  }
}
