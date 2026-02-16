/**
 * TEMPORARY: Seed attendance for dev/testing.
 * 82% of registrants get main-checkin; uneven random distribution across all other sessions.
 * Check-ins are spread across hours 7 AM–2 PM (weighted peak ~9–10 AM) for chart trend testing.
 *
 * DEV ONLY — aborts if --dev not passed or database is prod.
 *
 * Run:
 *   cd functions && node scripts/seed-attendance-dev.js --database=event-hub-dev --dev
 *
 * After seeding, run backfill to update analytics/global hourlyCheckins:
 *   cd functions && node scripts/backfill-analytics-dev.js --database=event-hub-dev --dev
 *
 * Requires: gcloud auth application-default login
 *
 * If you see "invalid_grant" or "reauth related error (invalid_rapt)":
 *   gcloud auth application-default login
 * For Google Workspace orgs, try: gcloud auth login && gcloud auth application-default login
 */

const admin = require('firebase-admin');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'aisaiah-event-hub';

const hasDev = process.argv.includes('--dev');
const dbArg = process.argv.find((a) => a.startsWith('--database='));
const databaseId = dbArg ? dbArg.replace(/^--database=/, '').trim() : '(default)';

if (!hasDev) {
  console.error('ABORT: This script must not run without --dev. Add --dev to confirm dev environment.');
  process.exit(1);
}
if (databaseId === 'event-hub-prod' || databaseId.toLowerCase().includes('prod')) {
  console.error('ABORT: This script must not run in prod. Use --database=(default) or --database=event-hub-dev');
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = getFirestore(databaseId);

const EVENT_ID = 'nlc-2026';
const MAIN_CHECKIN = 'main-checkin';
const MAIN_PCT = 0.82; // 82% get main-checkin
// Per-other-session probability (of those who have main-checkin). Uneven distribution.
const OTHER_SESSION_PCTS = [0.55, 0.35, 0.25]; // 1st other: 55%, 2nd: 35%, 3rd: 25%, etc.

// Spread check-ins across hours for chart testing. Hours 7–14 = 7 AM–2 PM.
// Weighted distribution: peak around 9–10 AM, taper at edges.
const HOUR_WEIGHTS = [0.05, 0.15, 0.35, 0.45, 0.40, 0.25, 0.15, 0.08]; // 7,8,9,10,11,12,13,14

function randomCheckInTime(baseDate) {
  const d = new Date(baseDate);
  d.setHours(0, 0, 0, 0);
  const cumul = [];
  let sum = 0;
  for (const w of HOUR_WEIGHTS) {
    sum += w;
    cumul.push(sum);
  }
  const r = Math.random() * sum;
  let hour = 7;
  for (let i = 0; i < cumul.length; i++) {
    if (r <= cumul[i]) {
      hour = 7 + i;
      break;
    }
  }
  const min = Math.floor(Math.random() * 60);
  d.setHours(hour, min, 0, 0);
  return admin.firestore.Timestamp.fromDate(d);
}

function shuffle(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

async function run() {
  console.log('Seeding attendance (DEV ONLY) database=' + databaseId + ' event=' + EVENT_ID);

  const registrantsSnap = await db.collection(`events/${EVENT_ID}/registrants`).get();
  const registrantIds = registrantsSnap.docs.map((d) => d.id);
  if (registrantIds.length === 0) {
    console.log('No registrants found. Run registrant seed first.');
    return;
  }

  const shuffled = shuffle(registrantIds);
  const mainCount = Math.max(1, Math.floor(registrantIds.length * MAIN_PCT));
  const mainRegistrants = shuffled.slice(0, mainCount);

  // Don't use orderBy('order') — dialogue sessions may not have 'order' field and would be excluded
  const sessionsSnap = await db.collection(`events/${EVENT_ID}/sessions`).get();
  const sessionIds = sessionsSnap.docs.map((d) => d.id);
  if (sessionIds.length < 2) {
    console.log('Need at least 2 sessions (main-checkin + 1 more). Found:', sessionIds.length);
  }

  const otherSessions = sessionIds.filter((s) => s !== MAIN_CHECKIN);
  const sessionsToSeed = [MAIN_CHECKIN, ...otherSessions];
  console.log('Sessions:', sessionsToSeed, '(main-checkin +', otherSessions.length, 'others)');

  let written = 0;
  const batchSize = 400;
  let batch = db.batch();
  let opCount = 0;

  // Base date for check-in times (today, so chart shows current-day trend)
  const baseDate = new Date();

  for (const registrantId of mainRegistrants) {
    const extraSessions = otherSessions.filter((_, i) => {
      const pct = OTHER_SESSION_PCTS[i] ?? 0.2;
      return Math.random() < pct;
    });
    const sessionIdsForReg = [...new Set([MAIN_CHECKIN, ...extraSessions])];

    // One check-in time per registrant; spread across hours for chart trend
    const checkInAt = randomCheckInTime(baseDate);

    for (const sessionId of sessionIdsForReg) {
      const ref = db.doc(`events/${EVENT_ID}/sessions/${sessionId}/attendance/${registrantId}`);
      batch.set(ref, {
        checkedInAt: checkInAt,
        checkedInBy: 'seed-script',
      }, { merge: true });
      opCount++;
      written++;
    }

    if (opCount >= batchSize) {
      await batch.commit();
      batch = db.batch();
      opCount = 0;
    }
  }

  if (opCount > 0) {
    await batch.commit();
  }

  console.log('Done. Wrote', written, 'attendance docs (spread 7 AM–2 PM).');
  console.log('  Main-checkin:', mainRegistrants.length, 'registrants (', Math.round(MAIN_PCT * 100) + '% )');
  console.log('  Run backfill to update analytics: node scripts/backfill-analytics-dev.js --database=' + databaseId + ' --dev');
  otherSessions.forEach((s, i) => {
    const pct = OTHER_SESSION_PCTS[i] ?? 0.2;
    console.log('  Session', s + ':', Math.round(mainRegistrants.length * pct), 'approx');
  });
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
