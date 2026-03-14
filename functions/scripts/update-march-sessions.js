/**
 * Update March Assembly sessions in Firestore to match the new schedule.
 * Deletes old sessions and writes the full detailed schedule.
 *
 * Run: cd functions && node scripts/update-march-sessions.js
 * Requires: gcloud auth application-default login
 */

const admin = require('firebase-admin');
const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'aisaiah-event-hub';

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = admin.firestore();
const ts = (d) => admin.firestore.Timestamp.fromDate(d);

const EVENT_ID = 'march-assembly';

// All times in UTC. Event is EDT (UTC-4) on March 14, 2026.
const SESSIONS = [
  {
    id: 'main',
    name: 'Event Check-In',
    title: 'Event Check-In',
    description: 'Main event registration and check-in',
    order: 0,
    isActive: true,
    startAt: ts(new Date('2026-03-14T00:00:00.000Z')),
    endAt: ts(new Date('2026-03-14T23:59:59.000Z')),
    materials: [],
  },
  {
    id: 'setup',
    name: 'Set Up',
    title: 'Set Up',
    description: 'CFC — Tampa Bay, Tech Set-up by Bro. Irwin Goingo',
    order: 2,
    isActive: true,
    startAt: ts(new Date('2026-03-14T17:00:00.000Z')), // 1:00 PM EDT
    endAt: ts(new Date('2026-03-14T19:00:00.000Z')),   // 3:00 PM EDT
    materials: [],
  },
  {
    id: 'parade',
    name: 'Parade',
    title: 'Parade',
    description: 'Parade by Chapter',
    speaker: 'Bro. Ernie Angeles',
    speakerTitle: 'Emcee',
    order: 3,
    isActive: true,
    startAt: ts(new Date('2026-03-14T19:00:00.000Z')), // 3:00 PM EDT
    endAt: ts(new Date('2026-03-14T19:20:00.000Z')),   // 3:20 PM EDT
    materials: [],
  },
  {
    id: 'cheer',
    name: 'Cheer',
    title: 'Cheer',
    description: 'Cheer by Chapter',
    order: 4,
    isActive: true,
    startAt: ts(new Date('2026-03-14T19:20:00.000Z')), // 3:20 PM EDT
    endAt: ts(new Date('2026-03-14T19:40:00.000Z')),   // 3:40 PM EDT
    materials: [],
  },
  {
    id: 'gathering-song',
    name: 'Gathering Song',
    title: 'Gathering Song',
    description: 'CFC Theme Song 2026 — In The One, We Are One. CFC Kids will use the St. John\'s Room.',
    order: 5,
    isActive: true,
    startAt: ts(new Date('2026-03-14T19:40:00.000Z')), // 3:40 PM EDT
    endAt: ts(new Date('2026-03-14T19:45:00.000Z')),   // 3:45 PM EDT
    materials: [],
  },
  {
    id: 'worship',
    name: 'Worship',
    title: 'Worship',
    description: 'BBS Music Ministry',
    speaker: 'Bro. Mike Suela',
    speakerTitle: 'Worship Leader',
    order: 6,
    isActive: true,
    startAt: ts(new Date('2026-03-14T19:45:00.000Z')), // 3:45 PM EDT
    endAt: ts(new Date('2026-03-14T20:00:00.000Z')),   // 4:00 PM EDT
    materials: [],
  },
  {
    id: 'talk-1',
    name: 'Talk 1: The Great Commission',
    title: 'Talk 1: The Great Commission',
    description: 'CFC Kids will use the St. John\'s Room',
    speaker: 'Bro. Eric Zalamea',
    order: 7,
    isActive: true,
    startAt: ts(new Date('2026-03-14T20:00:00.000Z')), // 4:00 PM EDT
    endAt: ts(new Date('2026-03-14T20:35:00.000Z')),   // 4:35 PM EDT
    materials: [],
  },
  {
    id: 'talk-2',
    name: 'Talk 2: Evangelization in CFC',
    title: 'Talk 2: Evangelization in CFC',
    speaker: 'Bro Art Barlaan',
    order: 8,
    isActive: true,
    startAt: ts(new Date('2026-03-14T20:35:00.000Z')), // 4:35 PM EDT
    endAt: ts(new Date('2026-03-14T21:10:00.000Z')),   // 5:10 PM EDT
    materials: [],
  },
  {
    id: 'declaration-of-goals',
    name: 'Declaration of Goals',
    title: 'Declaration of Goals',
    description: 'By Chapter — with slides presentation',
    order: 9,
    isActive: true,
    startAt: ts(new Date('2026-03-14T21:10:00.000Z')), // 5:10 PM EDT
    endAt: ts(new Date('2026-03-14T21:30:00.000Z')),   // 5:30 PM EDT
    materials: [],
  },
  {
    id: 'welcoming-new-members',
    name: 'Welcoming of New CFC Members',
    title: 'Welcoming of New CFC Members',
    speaker: 'Bro. Francis Navales',
    order: 10,
    isActive: true,
    startAt: ts(new Date('2026-03-14T21:30:00.000Z')), // 5:30 PM EDT
    endAt: ts(new Date('2026-03-14T21:40:00.000Z')),   // 5:40 PM EDT
    materials: [],
  },
  {
    id: 'prayover',
    name: 'Prayover',
    title: 'Prayover',
    description: 'March Birthday and Anniversary Celebrants',
    speaker: 'Bro. Ron Ares, Bro. Sam Jutba',
    order: 11,
    isActive: true,
    startAt: ts(new Date('2026-03-14T21:40:00.000Z')), // 5:40 PM EDT
    endAt: ts(new Date('2026-03-14T21:50:00.000Z')),   // 5:50 PM EDT
    materials: [],
  },
  {
    id: 'announcements',
    name: 'Announcements',
    title: 'Announcements',
    order: 12,
    isActive: true,
    startAt: ts(new Date('2026-03-14T21:50:00.000Z')), // 5:50 PM EDT
    endAt: ts(new Date('2026-03-14T21:55:00.000Z')),   // 5:55 PM EDT
    materials: [],
  },
  {
    id: 'closing',
    name: 'Closing Message, Closing Prayer & Closing Song',
    title: 'Closing Message, Closing Prayer & Closing Song',
    description: 'BBS Music Ministry',
    speaker: 'Bro. Ed Bilbao',
    order: 13,
    isActive: true,
    startAt: ts(new Date('2026-03-14T21:55:00.000Z')), // 5:55 PM EDT
    endAt: ts(new Date('2026-03-14T22:00:00.000Z')),   // 6:00 PM EDT
    materials: [],
  },
  {
    id: 'fellowship',
    name: 'Fellowship',
    title: 'Fellowship',
    description: "Bro. Art's 70th Birthday Celebration",
    speaker: 'Bro. Irwin Goingo',
    order: 14,
    isActive: true,
    startAt: ts(new Date('2026-03-14T22:00:00.000Z')), // 6:00 PM EDT
    endAt: ts(new Date('2026-03-15T01:00:00.000Z')),   // 9:00 PM EDT
    materials: [],
  },
];

async function run() {
  const sessionsRef = db.collection(`events/${EVENT_ID}/sessions`);

  // 1. Delete all existing sessions
  const existing = await sessionsRef.get();
  console.log(`Deleting ${existing.size} existing sessions...`);
  const deleteBatch = db.batch();
  for (const doc of existing.docs) {
    deleteBatch.delete(doc.ref);
  }
  await deleteBatch.commit();

  // 2. Write new sessions
  console.log(`Writing ${SESSIONS.length} new sessions...`);
  const writeBatch = db.batch();
  for (const s of SESSIONS) {
    const { id, ...fields } = s;
    const ref = sessionsRef.doc(id);
    writeBatch.set(ref, fields);
  }
  await writeBatch.commit();

  console.log('Done! Sessions updated for events/' + EVENT_ID);
  for (const s of SESSIONS) {
    console.log(`  ${s.order}. ${s.name}`);
  }
}

run()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Failed:', err.message);
    process.exit(1);
  });
