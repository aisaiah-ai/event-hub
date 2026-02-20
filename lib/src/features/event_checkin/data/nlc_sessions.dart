import '../../../models/session.dart';

/// NLC 2026 dialogue sessions — each has its own check-in page and QR code.
/// Main check-in is a session: sessions/main-checkin (same attendance model).
class NlcSessions {
  NlcSessions._();

  /// Session ID for main/arrival check-in. Treated like any other session.
  /// Create doc at events/{eventId}/sessions/main-checkin in Firestore (bootstrap).
  static const String mainCheckInSessionId = 'main-checkin';

  static const Session mainCheckIn = Session(
    id: 'main-checkin',
    title: 'Main Check-In',
    name: 'Main Check-In',
    isActive: true,
  );

  static const String genderIdeologySlug = 'gender-ideology';
  static const String contraceptionIvfAbortionSlug = 'contraception-ivf-abortion';
  static const String immigrationSlug = 'immigration';

  static const Session genderIdeology = Session(
    id: 'gender-ideology-dialogue',
    title: 'Gender Ideology Dialogue',
    name: 'Gender Ideology Dialogue',
    isActive: true,
  );

  static const Session contraceptionIvfAbortion = Session(
    id: 'contraception-ivf-abortion-dialogue',
    title: 'Contraception/IVF/Abortion Dialogue',
    name: 'Contraception/IVF/Abortion Dialogue',
    isActive: true,
  );

  static const Session immigration = Session(
    id: 'immigration-dialogue',
    title: 'Immigration Dialogue',
    name: 'Immigration Dialogue',
    isActive: true,
  );

  static const List<Session> all = [
    genderIdeology,
    contraceptionIvfAbortion,
    immigration,
  ];

  static Session? sessionForSlug(String slug) {
    switch (slug) {
      case genderIdeologySlug:
        return genderIdeology;
      case contraceptionIvfAbortionSlug:
        return contraceptionIvfAbortion;
      case immigrationSlug:
        return immigration;
      default:
        return null;
    }
  }

  /// Route slug for a session id (e.g. gender-ideology-dialogue → gender-ideology).
  static String? slugForSessionId(String sessionId) {
    switch (sessionId) {
      case mainCheckInSessionId:
        return 'main-checkin';
      case 'gender-ideology-dialogue':
        return genderIdeologySlug;
      case 'contraception-ivf-abortion-dialogue':
        return contraceptionIvfAbortionSlug;
      case 'immigration-dialogue':
        return immigrationSlug;
      default:
        return null;
    }
  }

  static bool isNlcSessionSlug(String slug) =>
      slug == genderIdeologySlug ||
      slug == contraceptionIvfAbortionSlug ||
      slug == immigrationSlug;
}
