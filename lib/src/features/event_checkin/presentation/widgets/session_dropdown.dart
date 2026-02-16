import 'package:flutter/material.dart';

import '../../../../models/session.dart';
import '../theme/checkin_theme.dart';

/// Session dropdown — height 56, borderRadius 14, #E4E1DC.
class SessionDropdown extends StatelessWidget {
  const SessionDropdown({
    super.key,
    required this.sessions,
    required this.selectedSession,
    required this.onSessionSelected,
  });

  final List<Session> sessions;
  final Session? selectedSession;
  final ValueChanged<Session?> onSessionSelected;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) return const SizedBox.shrink();
    final session = selectedSession ?? sessions.first;
    final isSingle = sessions.length == 1;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.sessionDropdownBg,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.insideCards),
      child: isSingle
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    'Session: ${session.displayName}',
                    style: AppTypography.sessionDropdown(context),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: AppColors.textPrimary87),
              ],
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<Session>(
                value: selectedSession,
                hint: Text(
                  'Session: Select session',
                  style: AppTypography.sessionDropdown(context),
                ),
                isExpanded: true,
                dropdownColor: AppColors.sessionDropdownBg,
                icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textPrimary87),
                items: sessions
                    .map((s) => DropdownMenuItem<Session>(
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
