/**
 * Delete the extra session documents that were created by the old bootstrap
 * (opening-plenary, leadership-session-1, mass, closing) so they don't clutter the DB.
 *
 * Run: cd functions && node scripts/delete-extra-sessions.js "--database=(default)"
 *      cd functions && node scripts/delete-extra-sessions.js --database=event-hub-dev
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
  : 'event-hub-dev';
if (databaseId !== '(default)') {
  db.settings({ databaseId });
}

const EVENT_ID = 'nlc-2026';

const SESSION_IDS_TO_DELETE = [
  'opening-plenary',
  'leadership-session-1',
  'mass',
  'closing',
];

async function run() {
  const batch = db.batch();
  for (const sessionId of SESSION_IDS_TO_DELETE) {
    const ref = db.doc(`events/${EVENT_ID}/sessions/${sessionId}`);
    batch.delete(ref);
  }
  await batch.commit();
  console.log('Deleted sessions in database=' + databaseId + ': ' + SESSION_IDS_TO_DELETE.join(', '));
  console.log('Note: Any attendance subcollections under these sessions are left as-is. Delete them in Console if needed.');
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
