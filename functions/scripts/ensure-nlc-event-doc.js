/**
 * NLC 2026 full data model bootstrap. Do not assume any document exists.
 *
 * Creates in Firestore:
 * 1. events/nlc-2026 — event doc (name, venue, createdAt, isActive, metadata)
 * 2. events/nlc-2026/sessions/{id} — main-checkin only (name, location, order, isActive)
 * 3. events/nlc-2026/stats/overview — stats doc (all fields required for analytics)
 * 4. events/nlc-2026/analytics/global — dashboard doc (hourlyCheckins, regionCounts, etc.; Cloud Function updates on check-in)
 *
 * Database: event-hub-dev (default for script), event-hub-prod, or (default).
 * When app uses (default) in dev (useEventHubDevInDev=false), run with --database=(default) so check-in works.
 * Run: cd functions && node scripts/ensure-nlc-event-doc.js
 *      cd functions && node scripts/ensure-nlc-event-doc.js --database=event-hub-prod
 *      cd functions && node scripts/ensure-nlc-event-doc.js "--database=(default)"
 * Requires: gcloud auth application-default login (or GOOGLE_APPLICATION_CREDENTIALS).
 */

const admin = require('firebase-admin');
const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'aisaiah-event-hub';

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = admin.firestore();

const dbArg = process.argv.find((a) => a.startsWith('--database='));
const databaseId = dbArg
  ? dbArg.replace(/^--database=/, '').trim()
  : '(default)';
if (databaseId !== '(default)') {
  db.settings({ databaseId });
}
const EVENT_ID = 'nlc-2026';

// ----- 1. Event document (all required fields) -----
const EVENT_DATA = {
  name: 'National Leaders Conference 2026',
  slug: 'nlc-2026',
  venue: 'Hyatt Regency Valencia',
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
  isActive: true,
  metadata: {
    selfCheckinEnabled: true,
    sessionsEnabled: true,
  },
};

// Breakout session date: February 21, 2026 2:15 PM Pacific (start only; stored as UTC).
const BREAKOUT_START = new Date(Date.UTC(2026, 1, 21, 22, 15, 0));  // 2:15 PM Pacific

// ----- 2. Sessions (name, location, capacity, colorHex, order, isMain, startAt for breakouts) -----
// Official breakout colors: Gender Identity (Blue), Abortion & Contraception (Orange), Immigration (Yellow).
const SESSIONS = [
  { id: 'main-checkin', name: 'Main Check-In', location: 'Registration', capacity: 0, colorHex: '#1E3A5F', order: 0, isMain: true },
  { id: 'gender-ideology-dialogue', name: 'Gender Ideology Dialogue', location: 'Main Ballroom', capacity: 450, colorHex: '#2563EB', order: 1, isMain: false, startAt: BREAKOUT_START },
  { id: 'immigration-dialogue', name: 'Immigration Dialogue', location: 'Valencia Ballroom', capacity: 192, colorHex: '#EAB308', order: 2, isMain: false, startAt: BREAKOUT_START },
  { id: 'contraception-ivf-abortion-dialogue', name: 'Contraception/IVF/Abortion Dialogue', location: 'Saugus/Castaic', capacity: 72, colorHex: '#EA580C', order: 3, isMain: false, startAt: BREAKOUT_START },
];

// ----- 3. Stats overview (all fields — Cloud Functions require these) -----
const STATS_OVERVIEW = {
  totalRegistrations: 0,
  totalCheckedIn: 0,
  earlyBirdCount: 0,
  regionCounts: {},
  regionOtherTextCounts: {},
  ministryCounts: {},
  serviceCounts: {},
  sessionTotals: {},
  firstCheckInAt: null,
  firstCheckInRegistrantId: null,
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
};

// ----- 4. Analytics global (dashboard reads this; Cloud Function updates on check-in) -----
const ANALYTICS_GLOBAL = {
  totalCheckins: 0,
  totalUniqueAttendees: 0,
  totalRegistrants: 0,
  regionCounts: {},
  ministryCounts: {},
  hourlyCheckins: {},
  lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
};

async function run() {
  const batch = db.batch();

  const eventRef = db.doc(`events/${EVENT_ID}`);
  batch.set(eventRef, EVENT_DATA, { merge: true });

  for (const s of SESSIONS) {
    const ref = db.doc(`events/${EVENT_ID}/sessions/${s.id}`);
    const sessionData = {
      name: s.name,
      location: s.location || '',
      order: s.order,
      isActive: true,
      isMain: s.isMain === true,
      capacity: s.capacity != null ? s.capacity : 0,
      attendanceCount: 0,
      status: 'open',
      colorHex: s.colorHex || '',
    };
    if (s.startAt) sessionData.startAt = admin.firestore.Timestamp.fromDate(s.startAt);
    batch.set(ref, sessionData, { merge: true });
  }

  const statsRef = db.doc(`events/${EVENT_ID}/stats/overview`);
  batch.set(statsRef, STATS_OVERVIEW, { merge: true });

  const analyticsGlobalRef = db.doc(`events/${EVENT_ID}/analytics/global`);
  batch.set(analyticsGlobalRef, ANALYTICS_GLOBAL, { merge: true });

  await batch.commit();
  console.log('OK: database=' + databaseId);
  console.log('OK: events/' + EVENT_ID + ' (event doc with name, venue, createdAt, isActive, metadata)');
  console.log('OK: events/' + EVENT_ID + '/sessions (main-checkin + dialogue sessions)');
  console.log('OK: events/' + EVENT_ID + '/stats/overview (full stats structure)');
  console.log('OK: events/' + EVENT_ID + '/analytics/global (check-in trend and Top 5 updated by Cloud Function)');
}

run().then(() => process.exit(0)).catch((err) => {
  console.error('Failed:', err.message);
  process.exit(1);
});
