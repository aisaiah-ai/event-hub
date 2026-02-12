import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/event_model.dart';
import '../data/event_repository.dart';
import '../data/event_rsvp.dart';
import '../event_tokens.dart';
import '../widgets/event_page_scaffold.dart';

/// RSVP page — /events/:eventSlug/rsvp
/// Matches March Cluster Assembly flyer design.
class EventRsvpPage extends StatefulWidget {
  const EventRsvpPage({
    super.key,
    required this.eventSlug,
    this.source,
    this.repository,
  });

  final String eventSlug;
  final String? source;
  final EventRepository? repository;

  @override
  State<EventRsvpPage> createState() => _EventRsvpPageState();
}

class _EventRsvpPageState extends State<EventRsvpPage> {
  late EventRepository _repo;
  EventModel? _event;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  bool _submitted = false;

  final _nameController = TextEditingController();
  final _householdController = TextEditingController();
  final _celebrationController = TextEditingController();
  final _cfcIdController = TextEditingController();
  bool _attendingRally = true;
  bool _attendingDinner = true;
  int _attendeesCount = 1;
  String? _area; // Required: BBS, Tampa, Port Charlotte, or Others

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? EventRepository();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _householdController.dispose();
    _celebrationController.dispose();
    _cfcIdController.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final household = _householdController.text.trim();
    if (name.isEmpty || household.isEmpty) {
      setState(() => _error = 'Please enter your name and household.');
      return;
    }
    if (_area == null || _area!.isEmpty) {
      setState(() => _error = 'Please select your area.');
      return;
    }
    if (_event == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final rsvp = EventRsvp(
        name: name,
        household: household,
        attendingRally: _attendingRally,
        attendingDinner: _attendingDinner,
        attendeesCount: _attendeesCount,
        celebrationType: _celebrationController.text.trim().isEmpty
            ? null
            : _celebrationController.text.trim(),
        createdAt: DateTime.now(),
        source: widget.source,
        area: _area!,
        cfcId: _cfcIdController.text.trim().isEmpty
            ? null
            : _cfcIdController.text.trim(),
      );
      await _repo.submitRsvp(_event!.id, rsvp);
      HapticFeedback.mediumImpact();
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: EventTokens.textOffWhite),
      );
    }
    if (_error != null && _event == null) {
      return _buildError();
    }
    if (_submitted) {
      return _buildSuccess();
    }
    return _buildForm(_event!);
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

  void _resetFormForAnother() {
    setState(() {
      _submitted = false;
      _nameController.clear();
      _householdController.clear();
      _celebrationController.clear();
      _cfcIdController.clear();
      _attendingRally = true;
      _attendingDinner = true;
      _attendeesCount = 1;
      _area = null;
    });
  }

  Widget _buildSuccess() {
    final eventName = _event?.name ?? 'Event';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(EventTokens.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🎉 RSVP Confirmed',
              style: GoogleFonts.fraunces(
                color: EventTokens.textOffWhite,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: EventTokens.spacingL),
            Text(
              'Thank you for registering for',
              style: TextStyle(
                color: EventTokens.textOffWhite.withValues(alpha: 0.9),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: EventTokens.spacingS),
            Text(
              eventName,
              textAlign: TextAlign.center,
              style: GoogleFonts.fraunces(
                color: EventTokens.accentGold,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: EventTokens.spacingXL),
            FilledButton(
              onPressed: _resetFormForAnother,
              style: FilledButton.styleFrom(
                backgroundColor: EventTokens.accentGold,
                foregroundColor: EventTokens.textPrimary,
              ),
              child: const Text('Register Another Person?'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(EventModel event) {
    final rallyTime = event.rallyTimeText ?? '3:00 PM - 6:00 PM';
    final dinnerTime = event.dinnerTimeText ?? '6:00 PM - 9:00 PM';
    final rsvpDeadline = event.rsvpDeadlineText ?? 'March 10';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: EventTokens.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: EventTokens.spacingS),
          Center(child: EventLogo(logoUrl: event.logoUrl, size: 72)),
          const SizedBox(height: EventTokens.spacingM),
          Center(
            child: Text(
              "You're Invited!",
              style: GoogleFonts.dancingScript(
                color: EventTokens.accentGold,
                fontSize: 32,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: EventTokens.spacingS),
          Text(
            event.name,
            textAlign: TextAlign.center,
            style: GoogleFonts.fraunces(
              color: EventTokens.textOffWhite,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: EventTokens.spacingXL),
          _SectionHeader(icon: Icons.calendar_today, title: 'Event Details'),
          const SizedBox(height: EventTokens.spacingS),
          _DetailRow(
            icon: Icons.calendar_month,
            label: 'Date',
            value: event.displayDate,
          ),
          const SizedBox(height: EventTokens.spacingS),
          _DetailRow(
            icon: Icons.location_on,
            label: 'Location',
            value: '${event.locationName}\n${event.address}',
          ),
          const SizedBox(height: EventTokens.spacingL),
          _SectionHeader(icon: Icons.schedule, title: 'Program Schedule'),
          const SizedBox(height: EventTokens.spacingS),
          _ScheduleRow(
            icon: Icons.volunteer_activism,
            title: 'Evangelization Rally',
            time: rallyTime,
            description: 'Join us for an afternoon of faith and fellowship.',
          ),
          const SizedBox(height: EventTokens.spacingM),
          _ScheduleRow(
            icon: Icons.restaurant,
            title: 'Dinner & Fellowship',
            time: dinnerTime,
            description: 'Birthdays & Anniversaries Celebration.',
          ),
          const SizedBox(height: EventTokens.spacingL),
          _SectionHeader(icon: Icons.people, title: 'Please RSVP'),
          const SizedBox(height: EventTokens.spacingS),
          Text(
            'Let us know your plans to attend:',
            style: TextStyle(
              color: EventTokens.textOffWhite.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: EventTokens.spacingM),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(EventTokens.spacingM),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(EventTokens.radiusMedium),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
            const SizedBox(height: EventTokens.spacingM),
          ],
          _RsvpCheckbox(
            label: 'Evangelization Rally ($rallyTime)',
            value: _attendingRally,
            onChanged: (v) => setState(() => _attendingRally = v ?? true),
          ),
          const SizedBox(height: EventTokens.spacingS),
          _RsvpCheckbox(
            label: 'Dinner & Fellowship ($dinnerTime)',
            value: _attendingDinner,
            onChanged: (v) => setState(() => _attendingDinner = v ?? true),
          ),
          const SizedBox(height: EventTokens.spacingL),
          TextField(
            controller: _nameController,
            decoration: _inputDecoration('Name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: EventTokens.spacingM),
          TextField(
            controller: _householdController,
            decoration: _inputDecoration('Household'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: EventTokens.spacingM),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Area:',
                style: TextStyle(color: EventTokens.textOffWhite, fontSize: 14),
              ),
              const SizedBox(width: EventTokens.spacingM),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: EventTokens.spacingS,
                  ),
                  decoration: BoxDecoration(
                    color: EventTokens.surfaceCard.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(
                      EventTokens.radiusMedium,
                    ),
                  ),
                  child: DropdownButton<String>(
                    value: _area,
                    isExpanded: true,
                    underline: const SizedBox(),
                    hint: Text(
                      'Select area',
                      style: TextStyle(
                        color: EventTokens.textMuted,
                        fontSize: 14,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'BBS',
                        child: Text(
                          'BBS',
                          style: TextStyle(color: EventTokens.textPrimary),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Tampa',
                        child: Text(
                          'Tampa',
                          style: TextStyle(color: EventTokens.textPrimary),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Port Charlotte',
                        child: Text(
                          'Port Charlotte',
                          style: TextStyle(color: EventTokens.textPrimary),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Others',
                        child: Text(
                          'Others',
                          style: TextStyle(color: EventTokens.textPrimary),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _area = v),
                    dropdownColor: EventTokens.surfaceCard,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: EventTokens.spacingM),
          TextField(
            controller: _cfcIdController,
            decoration: _inputDecoration('CFC ID (optional)'),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: EventTokens.spacingM),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Number of attendees:',
                style: TextStyle(color: EventTokens.textOffWhite, fontSize: 14),
              ),
              const SizedBox(width: EventTokens.spacingM),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: EventTokens.spacingS,
                ),
                decoration: BoxDecoration(
                  color: EventTokens.surfaceCard.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(EventTokens.radiusMedium),
                ),
                child: DropdownButton<int>(
                  value: _attendeesCount,
                  underline: const SizedBox(),
                  items: List.generate(
                    20,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(color: EventTokens.textPrimary),
                      ),
                    ),
                  ),
                  onChanged: (v) => setState(() => _attendeesCount = v ?? 1),
                  dropdownColor: EventTokens.surfaceCard,
                ),
              ),
            ],
          ),
          const SizedBox(height: EventTokens.spacingM),
          TextField(
            controller: _celebrationController,
            decoration: _inputDecoration('Birthday or Anniversary? (optional)'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: EventTokens.spacingXL),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: EventTokens.accentGold,
              foregroundColor: EventTokens.textPrimary,
              minimumSize: const Size.fromHeight(52),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit RSVP'),
          ),
          const SizedBox(height: EventTokens.spacingM),
          Center(
            child: Text(
              'RSVP by $rsvpDeadline',
              style: TextStyle(
                color: EventTokens.accentGold.withValues(alpha: 0.9),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: EventTokens.spacingXL),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: EventTokens.textMuted),
      filled: true,
      fillColor: EventTokens.surfaceCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EventTokens.radiusMedium),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EventTokens.radiusMedium),
        borderSide: BorderSide(
          color: EventTokens.textPrimary.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: EventTokens.accentGold, size: 22),
        const SizedBox(width: EventTokens.spacingS),
        Text(
          title,
          style: const TextStyle(
            color: EventTokens.accentGold,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: EventTokens.accentGold, size: 20),
        const SizedBox(width: EventTokens.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: EventTokens.textOffWhite.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: EventTokens.textOffWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.icon,
    required this.title,
    required this.time,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String time;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(EventTokens.spacingM),
      decoration: BoxDecoration(
        color: EventTokens.surfaceCard.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(EventTokens.radiusMedium),
        border: Border.all(
          color: EventTokens.accentGold.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: EventTokens.accentGold, size: 24),
          const SizedBox(width: EventTokens.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: EventTokens.textOffWhite,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    color: EventTokens.accentGold.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: EventTokens.textOffWhite.withValues(alpha: 0.8),
                    fontSize: 13,
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

class _RsvpCheckbox extends StatelessWidget {
  const _RsvpCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(EventTokens.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: EventTokens.spacingS),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: value,
                  onChanged: onChanged,
                  fillColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return EventTokens.accentGold;
                    }
                    return Colors.transparent;
                  }),
                  checkColor: EventTokens.textPrimary,
                  side: BorderSide(color: EventTokens.accentGold),
                ),
              ),
              const SizedBox(width: EventTokens.spacingM),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: EventTokens.textOffWhite,
                    fontSize: 14,
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
