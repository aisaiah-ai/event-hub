/**
 * Sets the smallest-capacity session (contraception-ivf-abortion-dialogue, cap 72)
 * to 70 checked-in attendees — leaving exactly 2 open slots.
 *
 * Use this to test the "nearly full / full" UI in dev.
 *
 * What it does:
 *   1. Reads up to 70 real registrant IDs from Firestore.
 *   2. Writes attendance docs to sessions/contraception-ivf-abortion-dialogue/attendance/.
 *   3. Sets attendanceCount: 70 directly on the session doc so the UI reflects it immediately.
 *
 * DEV ONLY — aborts if --dev not passed or database is prod.
 *
 * Run: cd functions && node scripts/seed-near-full-session-dev.js "--database=(default)" --dev
 *      cd functions && node scripts/seed-near-full-session-dev.js --database=event-hub-dev --dev
 *
 * Requires: gcloud auth application-default login
 */

const admin = require('firebase-admin');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'aisaiah-event-hub';

const hasDev = process.argv.includes('--dev');
const dbArg = process.argv.find((a) => a.startsWith('--database='));
const databaseId = dbArg ? dbArg.replace(/^--database=/, '').trim() : '(default)';

if (!hasDev) {
  console.error('ABORT: Pass --dev to confirm dev environment.');
  process.exit(1);
}
if (databaseId === 'event-hub-prod' || databaseId.toLowerCase().includes('prod')) {
  console.error('ABORT: This script must not run in prod.');
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = databaseId === '(default)' ? getFirestore() : getFirestore(databaseId);

const EVENT_ID = 'nlc-2026';
const SESSION_ID = 'contraception-ivf-abortion-dialogue';
const CAPACITY = 72;
const TARGET_CHECKED_IN = CAPACITY - 2; // 70 — leaves 2 slots open

async function run() {
  console.log(`database=${databaseId}  session=${SESSION_ID}`);
  console.log(`Target: ${TARGET_CHECKED_IN}/${CAPACITY} checked in (${CAPACITY - TARGET_CHECKED_IN} remaining)`);

  // Fetch real registrant IDs to use as attendance doc IDs.
  const registrantsSnap = await db
    .collection(`events/${EVENT_ID}/registrants`)
    .limit(TARGET_CHECKED_IN)
    .get();

  if (registrantsSnap.empty) {
    console.error('No registrants found. Run registrant seed first (see demo.md one-time setup).');
    process.exit(1);
  }

  const registrantIds = registrantsSnap.docs.map((d) => d.id);
  console.log(`Using ${registrantIds.length} registrant IDs for attendance docs.`);

  // Write attendance docs in batches of 500 (Firestore batch limit).
  const BATCH_SIZE = 400;
  let written = 0;
  for (let i = 0; i < registrantIds.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = registrantIds.slice(i, i + BATCH_SIZE);
    for (const rid of chunk) {
      const ref = db.doc(`events/${EVENT_ID}/sessions/${SESSION_ID}/attendance/${rid}`);
      batch.set(ref, {
        checkedInAt: FieldValue.serverTimestamp(),
        checkedInBy: 'seed-near-full',
      }, { merge: true });
    }
    await batch.commit();
    written += chunk.length;
    console.log(`  Attendance docs written: ${written}/${registrantIds.length}`);
  }

  // Update attendanceCount on the session doc directly so the UI sees it immediately
  // (Cloud Functions may also recompute this, but this ensures it's correct right away).
  const sessionRef = db.doc(`events/${EVENT_ID}/sessions/${SESSION_ID}`);
  await sessionRef.update({ attendanceCount: TARGET_CHECKED_IN });

  console.log(`\nDone.`);
  console.log(`  session doc attendanceCount → ${TARGET_CHECKED_IN}`);
  console.log(`  remaining seats → ${CAPACITY - TARGET_CHECKED_IN}`);
  console.log(`\nNow open the session check-in page and verify the "2 remaining" / near-full state.`);
  console.log(`Check in 2 more registrants to trigger the "Full" state.`);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
