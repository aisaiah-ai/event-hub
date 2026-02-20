import 'package:intl/intl.dart';

import '../../../../models/session.dart';

/// NLC 2026 breakout session IDs (dialogue sessions).
const Set<String> nlcBreakoutSessionIds = {
  'gender-ideology-dialogue',
  'contraception-ivf-abortion-dialogue',
  'immigration-dialogue',
};

/// Default date for NLC breakout sessions when Firestore has no startAt (start time only).
const String nlcBreakoutDateFallback = 'Feb 21, 2026 · 2:15 PM';

bool isNlcBreakoutSession(String sessionId) => nlcBreakoutSessionIds.contains(sessionId);

/// Returns the session date string for display. Uses startAt/endAt when set;
/// for NLC breakout sessions with no startAt, returns [nlcBreakoutDateFallback].
/// Otherwise returns empty string (no date to show).
String getSessionDateDisplay(Session session) {
  if (session.startAt != null) {
    String s = '${DateFormat.MMMd().format(session.startAt!)} · ${DateFormat.jm().format(session.startAt!)}';
    if (session.endAt != null) {
      s += ' – ${DateFormat.jm().format(session.endAt!)}';
    }
    return s;
  }
  if (isNlcBreakoutSession(session.id)) return nlcBreakoutDateFallback;
  return '';
}
