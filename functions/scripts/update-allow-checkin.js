/**
 * Set allowCheckin: true on events/march-assembly.
 *
 * Option A – Firebase Console (no credentials):
 *   1. Firebase Console → Firestore → select database event-hub-dev (or the one your app uses)
 *   2. events → march-assembly → Add field allowCheckin (boolean) = true → Save
 *
 * Option B – This script (requires gcloud auth or GOOGLE_APPLICATION_CREDENTIALS):
 *   cd functions && node scripts/update-allow-checkin.js
 *   cd functions && node scripts/update-allow-checkin.js --database=event-hub-prod
 */
const admin = require('firebase-admin');
const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'aisaiah-event-hub';
const DOC_PATH = 'events/march-assembly';

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = admin.firestore();
const dbArg = process.argv.find((a) => a.startsWith('--database='));
const databaseId = dbArg ? dbArg.replace(/^--database=/, '').trim() : 'event-hub-dev';
if (databaseId !== '(default)') {
  db.settings({ databaseId });
}

db.doc(DOC_PATH)
  .update({ allowCheckin: true })
  .then(() => {
    console.log(`Updated ${DOC_PATH} in database=${databaseId}: allowCheckin = true`);
  })
  .catch((e) => {
    console.error('Update failed:', e.message);
    if (e.code === 5) console.error('Document not found. Create events/march-assembly first or use the correct database.');
    process.exit(1);
  });
