/**
 * TEMPORARY: Delete all attendance for nlc-2026 (seed data).
 *
 * DEV ONLY — aborts if --dev not passed or database is prod.
 *
 * Match the app's database (see lib/src/config/firestore_config.dart).
 * App uses (default) → use --database=(default) or omit (default).
 *
 * Run:
 *   cd functions && node scripts/delete-seed-attendance-dev.js --dev
 *   cd functions && node scripts/delete-seed-attendance-dev.js "--database=(default)" --dev
 *   cd functions && node scripts/delete-seed-attendance-dev.js --database=event-hub-dev --dev
 *
 * Requires: gcloud auth application-default login
 */

const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');
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

async function deleteCollection(path, batchSize = 400) {
  const ref = db.collection(path);
  let totalDeleted = 0;

  const deleteQueryBatch = async () => {
    const snapshot = await ref.limit(batchSize).get();
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
    if (deleted > 0) process.stdout.write('.');
  } while (deleted > 0);

  return totalDeleted;
}

async function run() {
  console.log('Deleting all attendance (DEV ONLY) database=' + databaseId + ' event=' + EVENT_ID);

  const sessionsSnap = await db.collection(`events/${EVENT_ID}/sessions`).get();
  const sessionIds = sessionsSnap.docs.map((d) => d.id);
  console.log('Found', sessionIds.length, 'session(s):', sessionIds.join(', ') || '(none)');

  if (sessionIds.length === 0) {
    console.log('No sessions — nothing to delete.');
    return;
  }

  let total = 0;
  for (const sessionDoc of sessionsSnap.docs) {
    const path = `events/${EVENT_ID}/sessions/${sessionDoc.id}/attendance`;
    const count = await deleteCollection(path);
    total += count;
    console.log(' ', sessionDoc.id + ':', count, 'deleted');
  }

  console.log('Done. Deleted', total, 'attendance docs total.');
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
