/**
 * Seed analytics/global with synthetic hourlyCheckins for chart testing.
 * Overwrites ONLY hourlyCheckins (and lastUpdated). Use when seed+backfill
 * didn't run or you want to test the chart with multi-hour data.
 *
 * App uses (default) database. Run with same database the app reads from.
 *
 * Run:
 *   cd functions && node scripts/seed-hourly-checkins-dev.js --database=(default) --dev
 *   cd functions && node scripts/seed-hourly-checkins-dev.js --database=event-hub-dev --dev
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
  console.error('ABORT: Add --dev to confirm.');
  process.exit(1);
}
if (databaseId.toLowerCase().includes('prod')) {
  console.error('ABORT: Must not run in prod.');
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = getFirestore(databaseId);
const EVENT_ID = 'nlc-2026';

// Hours 7–14 = 7 AM–2 PM. Weighted peak ~9–10 AM.
const HOUR_COUNTS = [40, 85, 120, 145, 130, 95, 70, 45]; // 7,8,9,10,11,12,13,14

async function run() {
  const today = new Date();
  const y = today.getFullYear();
  const m = String(today.getMonth() + 1).padStart(2, '0');
  const d = String(today.getDate()).padStart(2, '0');

  const hourlyCheckins = {};
  let totalCheckins = 0;
  for (let i = 0; i < 8; i++) {
    const hour = 7 + i;
    const key = `${y}-${m}-${d}-${String(hour).padStart(2, '0')}`;
    hourlyCheckins[key] = HOUR_COUNTS[i];
    totalCheckins += HOUR_COUNTS[i];
  }

  const ref = db.doc(`events/${EVENT_ID}/analytics/global`);
  await ref.set({
    hourlyCheckins,
    totalCheckins,
    totalUniqueAttendees: 350, // placeholder
    lastUpdated: FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log('Done. Updated analytics/global in database=' + databaseId);
  console.log('  hourlyCheckins: 8 hours (7 AM–2 PM), total=' + totalCheckins);
  console.log('  Keys:', Object.keys(hourlyCheckins).join(', '));
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
