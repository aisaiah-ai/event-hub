/**
 * TEMPORARY: Delete all attendance for nlc-2026 and reset analytics so the dashboard shows empty.
 *
 * DEV ONLY — aborts if --dev not passed or database is prod.
 *
 * 1. Deletes all attendance subcollections (per session).
 * 2. Resets analytics/global, stats/overview, and each session's analytics/summary so Top 5 / metrics show no data.
 *
 * Run:
 *   cd functions && node scripts/delete-seed-attendance-dev.js --dev
 *   cd functions && node scripts/delete-seed-attendance-dev.js "--database=(default)" --dev
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

const db = databaseId === '(default)' ? getFirestore() : getFirestore(databaseId);

const EVENT_ID = 'nlc-2026';
const BATCH_SIZE = 500;

async function deleteCollection(path, sessionId) {
  const ref = db.collection(path);
  let totalDeleted = 0;

  const deleteQueryBatch = async () => {
    const snapshot = await ref.limit(BATCH_SIZE).get();
    if (snapshot.size === 0) return 0;
    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    return snapshot.size;
  };

  let deleted;
  do {
    deleted = await deleteQueryBatch();
    totalDeleted += deleted;
    if (deleted > 0) {
      console.log(`  [${sessionId}] ${totalDeleted} deleted so far`);
    }
  } while (deleted > 0);

  return { sessionId, totalDeleted };
}

async function run() {
  console.log('Deleting all attendance (DEV ONLY) database=' + databaseId + ' event=' + EVENT_ID);
  console.log('Sessions run in parallel; progress updates below.\n');

  const sessionsSnap = await db.collection(`events/${EVENT_ID}/sessions`).get();
  const sessions = sessionsSnap.docs.map((d) => ({ id: d.id, path: `events/${EVENT_ID}/sessions/${d.id}/attendance` }));
  if (sessions.length === 0) {
    console.log('No sessions — nothing to delete.');
    return;
  }

  console.log('Sessions:', sessions.map((s) => s.id).join(', '));

  const results = await Promise.all(
    sessions.map((s) => deleteCollection(s.path, s.id))
  );

  console.log('\n');
  let total = 0;
  for (const r of results) {
    console.log(' ', r.sessionId + ':', r.totalDeleted, 'deleted');
    total += r.totalDeleted;
  }
  console.log('Deleted', total, 'attendance docs.');

  console.log('Resetting analytics so dashboard shows empty (no bars, 0 counts, no trend)...');
  const bucketsPath = `events/${EVENT_ID}/stats/overview/checkinBuckets`;
  const bucketsDeleted = await deleteCollection(bucketsPath, 'checkinBuckets');
  if (bucketsDeleted > 0) {
    console.log('  Deleted', bucketsDeleted, 'checkin bucket docs (trend/sparkline data).');
  }
  const globalRef = db.doc(`events/${EVENT_ID}/analytics/global`);
  await globalRef.set({
    totalUniqueAttendees: 0,
    totalCheckins: 0,
    regionCounts: {},
    ministryCounts: {},
    hourlyCheckins: {},
    earliestCheckin: null,
    earliestRegistration: null,
    lastUpdated: FieldValue.serverTimestamp(),
  }, { merge: true });
  const statsRef = db.doc(`events/${EVENT_ID}/stats/overview`);
  await statsRef.set({
    totalCheckedIn: 0,
    regionCounts: {},
    ministryCounts: {},
    sessionTotals: {},
    firstCheckInAt: null,
    firstCheckInRegistrantId: null,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  for (const s of sessionsSnap.docs) {
    await db.doc(`events/${EVENT_ID}/sessions/${s.id}/analytics/summary`).set({
      attendanceCount: 0,
      regionCounts: {},
      ministryCounts: {},
      lastUpdated: FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  console.log('Done. Dashboard should show no Top 5 bars, 0 counts, and empty check-in trend.');
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
