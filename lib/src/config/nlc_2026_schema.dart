/// NLC 2026 Firestore data model — single source of truth.
///
/// Do not assume any document exists. Bootstrap (initializeNlc2026 or
/// ensure-nlc-event-doc.js) must create event, sessions, and stats/overview
/// with these exact paths and fields before the app works.
class Nlc2026Schema {
  Nlc2026Schema._();

  static const String eventId = 'nlc-2026';

  // ----- Paths -----
  static String eventPath() => 'events/$eventId';
  static String sessionsPath() => 'events/$eventId/sessions';
  static String sessionPath(String sessionId) => 'events/$eventId/sessions/$sessionId';
  static String registrantsPath() => 'events/$eventId/registrants';
  static String registrantPath(String registrantId) => 'events/$eventId/registrants/$registrantId';
  static String attendancePath(String sessionId, String registrantId) =>
      'events/$eventId/sessions/$sessionId/attendance/$registrantId';
  static String statsOverviewPath() => 'events/$eventId/stats/overview';
  static String adminsPath() => 'events/$eventId/admins';

  // ----- 1. Event document fields -----
  static const String eventName = 'name';
  static const String eventVenue = 'venue';
  static const String eventCreatedAt = 'createdAt';
  static const String eventIsActive = 'isActive';
  static const String eventMetadata = 'metadata';
  static const String metadataSelfCheckinEnabled = 'selfCheckinEnabled';
  static const String metadataSessionsEnabled = 'sessionsEnabled';

  // ----- 2. Session document fields -----
  static const String sessionName = 'name';
  static const String sessionLocation = 'location';
  static const String sessionOrder = 'order';
  static const String sessionIsActive = 'isActive';

  // ----- 3. Registrant document fields (app + Cloud Functions use these) -----
  static const String registrantProfile = 'profile';
  static const String registrantAnswers = 'answers';
  static const String registrantEventAttendance = 'eventAttendance';
  static const String registrantCheckInSource = 'checkInSource';
  static const String registrantSessionsCheckedIn = 'sessionsCheckedIn';
  static const String registrantRegisteredAt = 'registeredAt';
  static const String registrantCreatedAt = 'createdAt';
  static const String registrantUpdatedAt = 'updatedAt';
  // eventAttendance sub-map
  static const String eventAttendanceCheckedIn = 'checkedIn';
  static const String eventAttendanceCheckedInAt = 'checkedInAt';
  static const String eventAttendanceCheckedInBy = 'checkedInBy';
  // Optional top-level (spec): firstName, lastName, email, region, regionOtherText, ministryMembership, service, isEarlyBird
  static const String registrantFirstName = 'firstName';
  static const String registrantLastName = 'lastName';
  static const String registrantEmail = 'email';
  static const String registrantRegion = 'region';
  static const String registrantRegionOtherText = 'regionOtherText';
  static const String registrantMinistryMembership = 'ministryMembership';
  static const String registrantService = 'service';
  static const String registrantIsEarlyBird = 'isEarlyBird';

  // ----- 4. Attendance document fields -----
  static const String attendanceCheckedInAt = 'checkedInAt';
  static const String attendanceCheckedInBy = 'checkedInBy';

  // ----- 5. Stats overview document fields (must all exist after bootstrap) -----
  static const String statsTotalRegistrations = 'totalRegistrations';
  static const String statsTotalCheckedIn = 'totalCheckedIn';
  static const String statsEarlyBirdCount = 'earlyBirdCount';
  static const String statsRegionCounts = 'regionCounts';
  static const String statsRegionOtherTextCounts = 'regionOtherTextCounts';
  static const String statsMinistryCounts = 'ministryCounts';
  static const String statsServiceCounts = 'serviceCounts';
  static const String statsSessionTotals = 'sessionTotals';
  static const String statsFirstCheckInAt = 'firstCheckInAt';
  static const String statsFirstCheckInRegistrantId = 'firstCheckInRegistrantId';
  static const String statsUpdatedAt = 'updatedAt';

  // ----- 6. Checkin document fields -----
  static const String checkinEventId = 'eventId';
  static const String checkinRegistrantId = 'registrantId';
  static const String checkinSessionId = 'sessionId';
  static const String checkinMethod = 'method';
  static const String checkinTimestamp = 'timestamp';
  static const String checkinSource = 'source';
  static const String checkinCreatedAt = 'createdAt';
}
