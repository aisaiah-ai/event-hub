/// Flow at entry/landing: event (with optional session dropdown) or session (locked).
enum CheckInFlowType {
  event,
  session,
}

/// Mode for the check-in flow: always session-scoped. No conference/checkins.
/// Every check-in writes to events/{eventId}/sessions/{sessionId}/attendance/{registrantId}.
class CheckInMode {
  const CheckInMode({
    required this.eventId,
    required this.sessionId,
    required this.displayName,
  });

  final String eventId;
  final String sessionId;
  final String displayName;
}
