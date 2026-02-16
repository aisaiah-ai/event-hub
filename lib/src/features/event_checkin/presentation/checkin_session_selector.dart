import 'package:flutter/material.dart';

import '../../../models/session.dart';
import '../../events/event_tokens.dart';

/// Session selector for check-in. Dropdown or segmented when multiple.
class CheckinSessionSelector extends StatelessWidget {
  const CheckinSessionSelector({
    super.key,
    required this.sessions,
    required this.selectedSession,
    required this.onSessionSelected,
    required this.accentColor,
  });

  final List<Session> sessions;
  final Session? selectedSession;
  final ValueChanged<Session?> onSessionSelected;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) return const SizedBox.shrink();
    final session = selectedSession ?? sessions.first;
    final isSingleSession = sessions.length == 1;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: EventTokens.buttonSecondary,
        borderRadius: BorderRadius.circular(EventTokens.radiusMedium),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: EventTokens.spacingM,
        vertical: EventTokens.spacingM,
      ),
      child: isSingleSession
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    'Session: ${session.displayName}',
                    style: TextStyle(
                      color: EventTokens.textPrimary.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, color: EventTokens.textPrimary),
              ],
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<Session>(
                value: selectedSession,
                hint: Text(
                  'Session: Select session',
                  style: TextStyle(
                    color: EventTokens.textPrimary.withValues(alpha: 0.7),
                    fontSize: 16,
                  ),
                ),
                isExpanded: true,
                dropdownColor: EventTokens.buttonSecondary,
                style: TextStyle(
                  color: EventTokens.textPrimary.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
                icon: const Icon(Icons.keyboard_arrow_down, color: EventTokens.textPrimary),
                items: sessions
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text('Session: ${s.displayName}'),
                        ))
                    .toList(),
                onChanged: onSessionSelected,
              ),
            ),
    );
  }
}
