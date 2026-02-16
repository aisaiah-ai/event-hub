import 'nlc_sessions.dart';

/// Maps session ID or slug to display name.
String sessionDisplayName(String sessionIdOrSlug) {
  switch (sessionIdOrSlug) {
    case 'main-checkin':
    case 'arrival':
      return 'Main Check-In';
    case 'day1-main':
      return 'Day 1 – Main Session';
    case 'day2-main':
      return 'Day 2 – Main Session';
    case 'breakout-a':
      return 'Breakout – Leadership Formation';
    case NlcSessions.genderIdeologySlug:
    case 'gender-ideology-dialogue':
      return NlcSessions.genderIdeology.displayName;
    case NlcSessions.contraceptionIvfAbortionSlug:
    case 'contraception-ivf-abortion-dialogue':
      return NlcSessions.contraceptionIvfAbortion.displayName;
    case NlcSessions.immigrationSlug:
    case 'immigration-dialogue':
      return NlcSessions.immigration.displayName;
    default:
      return sessionIdOrSlug.replaceAll('-', ' ').split(' ').map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}').join(' ');
  }
}

/// Resolve session ID from route param (slug or id).
String sessionIdFromRouteParam(String param) {
  final session = NlcSessions.sessionForSlug(param);
  if (session != null) return session.id;
  return param;
}
