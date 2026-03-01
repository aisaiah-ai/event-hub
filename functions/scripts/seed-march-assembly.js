/**
 * Seed March Assembly (March Cluster) — test event for National Youth Conference Portland.
 *
 * Creates in Firestore:
 * 1. events/march-assembly — event doc with branding (flier-style: gold/blue), mock logo, schedule metadata
 * 2. events/march-assembly/sessions — main-checkin, evangelization-rally, birthdays-anniversaries (with startAt, endAt, description, materials PDFs)
 * 3. events/march-assembly/speakers — mock speaker profiles with photo URLs
 * 4. events/march-assembly/stats/overview — stats structure for analytics
 *
 * Branding matches March Cluster Assembly flier: primary #0E3A5D, accent #F4A340 (EventTokens).
 * Session materials are PDF URLs (mock); speakers have name, bio, photoUrl.
 *
 * Database: (default) or --database=event-hub-dev / event-hub-prod.
 * Run from project root (event-hub):
 *   cd functions && node scripts/seed-march-assembly.js
 *   cd functions && node scripts/seed-march-assembly.js "--database=(default)"
 * If you see "no such file or directory: functions", you are not in event-hub; run: cd path/to/event-hub first.
 * Requires: gcloud auth application-default login (or GOOGLE_APPLICATION_CREDENTIALS).
 */

const admin = require('firebase-admin');
const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'aisaiah-event-hub';

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = admin.firestore();

const dbArg = process.argv.find((a) => a.startsWith('--database='));
const databaseId = dbArg ? dbArg.replace(/^--database=/, '').trim() : '(default)';
if (databaseId !== '(default)') {
  db.settings({ databaseId });
}

const EVENT_ID = 'march-assembly';
const SLUG = 'march-cluster-2026';

// Saturday March 14, 2026 — same as flier
const EVENT_DATE = new Date('2026-03-14T00:00:00.000Z');
const ts = (d) => admin.firestore.Timestamp.fromDate(d);

// ----- 1. Event document (EventModel + NLC-style) — matches actual invite -----
const EVENT_DATA = {
  // EventModel (RSVP / landing)
  name: 'MARCH CLUSTER ASSEMBLY: Central B Cluster (BBS, Tampa, Port Charlotte) — Evangelization Rally & Fellowship Night',
  slug: SLUG,
  startDate: ts(EVENT_DATE),
  endDate: ts(EVENT_DATE),
  locationName: "St. Michael's Hall",
  address: 'Incarnation Catholic Church, 8220 W Hillsborough Ave, Tampa, FL 33615',
  isActive: true,
  allowRsvp: true,
  allowCheckin: false,
  metadata: {
    rallyTime: '3:00 – 6:00 PM',
    dinnerTime: '7:00 PM – 9:00 PM',
    rsvpDeadline: 'March 7',
    selfCheckinEnabled: false,
    sessionsEnabled: true,
  },
  // Branding (flier: primary blue, accent gold; In the One we are one! logo)
  branding: {
    logoUrl: 'assets/images/march_assembly_logo.png',
    primaryColorHex: '0E3A5D',
    accentColorHex: 'F4A340',
    organizationName: 'Couples for Christ',
    backgroundPatternUrl: null,
    backgroundImageUrl: 'assets/images/march_assembly_background.png',
  },
  // Short description shown on event detail page (below header)
  shortDescription:
    "Join us for an afternoon of evangelization, worship, and fellowship. " +
    "The rally runs 3:00–6:00 PM; dinner and celebration 7:00–9:00 PM. " +
    "RSVP by March 7.",
  // NLC-style fields (optional for future check-in)
  venue: "St. Michael's Hall, Incarnation Catholic Church",
  startAt: ts(EVENT_DATE),
  endAt: ts(new Date('2026-03-14T23:59:59.999Z')),
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
};

// ----- 2. Sessions (Main Check-In 1:30 PM, Rally 3–6 PM, Dinner & Fellowship 7–9 PM) + materials -----
const SESSIONS = [
  {
    id: 'main-checkin',
    name: 'Main Check-In',
    title: 'Main Check-In',
    location: 'Registration',
    order: 0,
    isActive: true,
    startAt: ts(new Date('2026-03-14T17:30:00.000Z')), // 1:30 PM EDT
    endAt: ts(new Date('2026-03-14T18:30:00.000Z')),   // 2:30 PM EDT
    materials: [],
  },
  {
    id: 'evangelization-rally',
    name: 'Evangelization Rally',
    title: 'Evangelization Rally',
    description: 'A time of worship, inspiration, and renewal as we recommit ourselves to the call to evangelize.',
    location: "St. Michael's Hall",
    order: 1,
    isActive: true,
    speakerIds: ['rommel-dolar'],
    startAt: ts(new Date('2026-03-14T19:00:00.000Z')), // 3:00 PM EDT
    endAt: ts(new Date('2026-03-14T22:00:00.000Z')),  // 6:00 PM EDT
    materials: [
      { title: 'Rally Program & Reflections', url: 'https://example.com/march-assembly/materials/rally-program.pdf', type: 'pdf' },
      { title: 'Small Group Discussion Guide', url: 'https://example.com/march-assembly/materials/rally-discussion-guide.pdf', type: 'pdf' },
      { title: 'Worship Song Sheet', url: 'https://example.com/march-assembly/materials/worship-songs.pdf', type: 'pdf' },
    ],
  },
  {
    id: 'dinner-fellowship',
    name: 'Birthdays & Anniversaries Celebration',
    title: 'Birthdays & Anniversaries Celebration',
    description: 'Dinner, fellowship, and dancing as we celebrate milestones, relationships, and the joy of community life.',
    location: "St. Michael's Hall",
    order: 2,
    isActive: true,
    speakerIds: ['mike-suela'],
    startAt: ts(new Date('2026-03-14T23:00:00.000Z')), // 7:00 PM EDT
    endAt: ts(new Date('2026-03-15T01:00:00.000Z')),   // 9:00 PM EDT
    materials: [
      { title: 'Birthdays & Anniversaries Program', url: 'https://example.com/march-assembly/materials/celebration-program.pdf', type: 'pdf' },
      { title: 'Fellowship Night Agenda', url: 'https://example.com/march-assembly/materials/fellowship-agenda.pdf', type: 'pdf' },
    ],
  },
];

// ----- 3. Speakers (full profile for Speaker Details page + list) -----
const SPEAKERS = [
  {
    id: 'rommel-dolar',
    name: 'Bro Rommel Dolar',
    fullName: 'Rommel Dolar',
    displayName: 'Bro Rommel Dolar',
    title: 'House Hold Head',
    cluster: 'Central B Cluster',
    photoUrl: 'assets/images/speakers/rommel_dolar.png',
    bio:
      'Bro Rommel serves as House Hold Head for the Central B Cluster, supporting families in BBS, Tampa, and Port Charlotte. ' +
      'He has been active in Couples for Christ for over a decade, with a heart for evangelization and community building.',
    yearsInCfc: 12,
    familiesMentored: 8,
    talksGiven: 24,
    location: 'Tampa, FL',
    topics: ['Evangelization', 'Household Leadership', 'Community Life', 'Worship'],
    quote:
      'In the One we are one — when we walk together in Christ, our families and our cluster become a light to the world.',
    email: 'rommel.dolar@example.com',
    phone: '+1 (813) 555-0101',
    facebookUrl: 'https://www.facebook.com/example.rommel',
    order: 0,
  },
  {
    id: 'mike-suela',
    name: 'Bro. Mike Suela',
    fullName: 'Mike Suela',
    displayName: 'Bro. Mike Suela',
    title: 'Unit Head',
    cluster: 'Central B Cluster',
    photoUrl: 'assets/images/speakers/mike_suela.png',
    bio:
      'Bro. Mike Suela leads as Unit Head, coordinating birthdays, anniversaries, and fellowship events for the cluster. ' +
      'He is passionate about celebrating milestones and strengthening bonds within the community.',
    yearsInCfc: 8,
    familiesMentored: 5,
    talksGiven: 12,
    location: 'Port Charlotte, FL',
    topics: ['Fellowship', 'Celebration', 'Family Life', 'Service'],
    quote:
      'Every birthday and anniversary is a chance to thank God for His faithfulness and to encourage one another in the mission.',
    email: 'mike.suela@example.com',
    phone: '+1 (941) 555-0102',
    facebookUrl: null,
    order: 1,
  },
];

// ----- 4. Stats overview -----
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

async function run() {
  const batch = db.batch();

  const eventRef = db.doc(`events/${EVENT_ID}`);
  batch.set(eventRef, EVENT_DATA, { merge: true });

  for (const s of SESSIONS) {
    const { materials, ...sessionFields } = s;
    const ref = db.doc(`events/${EVENT_ID}/sessions/${s.id}`);
    batch.set(ref, { ...sessionFields, materials: materials || [] }, { merge: true });
  }

  for (const sp of SPEAKERS) {
    const { id, ...fields } = sp;
    const ref = db.doc(`events/${EVENT_ID}/speakers/${id}`);
    batch.set(ref, fields, { merge: true });
  }

  const statsRef = db.doc(`events/${EVENT_ID}/stats/overview`);
  batch.set(statsRef, STATS_OVERVIEW, { merge: true });

  await batch.commit();
  console.log('OK: database=' + databaseId);
  console.log('OK: events/' + EVENT_ID + ' (event + branding, slug=' + SLUG + ')');
  console.log('OK: events/' + EVENT_ID + '/sessions (main-checkin, evangelization-rally, birthdays-anniversaries 7–9 PM with materials)');
  console.log('OK: events/' + EVENT_ID + '/speakers (' + SPEAKERS.length + ' speakers: Bro Rommel Dolar, Bro. Mike Suela)');
  console.log('OK: events/' + EVENT_ID + '/stats/overview');
}

function isAuthError(err) {
  const msg = (err && err.message) || '';
  return (
    msg.includes('invalid_grant') ||
    msg.includes('invalid_rapt') ||
    msg.includes('Getting metadata from plugin failed') ||
    msg.includes('Could not load the default credentials')
  );
}

function printManualSteps() {
  console.error('');
  console.error('--- If you cannot fix auth, add shortDescription manually ---');
  console.error('1. Open Firebase Console → Firestore → events → march-assembly');
  console.error('2. Add or edit field: shortDescription (string)');
  console.error('3. Value: "Join us for an afternoon of evangelization, worship, and fellowship. The rally runs 3:00–6:00 PM; dinner and celebration 7:00–9:00 PM. RSVP by March 7."');
  console.error('');
  console.error('The app still shows the short description via in-code fallback when this doc is missing or unread.');
}

run()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Failed:', err.message);
    if (isAuthError(err)) {
      console.error('');
      console.error('Google auth failed. Re-authenticate then re-run this script:');
      console.error('  gcloud auth application-default login');
      printManualSteps();
    }
    process.exit(1);
  });
