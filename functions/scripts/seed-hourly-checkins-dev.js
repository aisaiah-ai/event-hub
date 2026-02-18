/**
 * Seed analytics/global with synthetic hourlyCheckins for chart testing (15-minute buckets).
 * Overwrites ONLY hourlyCheckins (and lastUpdated). Use when seed+backfill
 * didn't run or you want to test the chart with multi-hour data.
 *
 * Keys: YYYY-MM-DD-HH-mm (15-min). App uses (default) database.
 *
 * Run:
 *   cd functions && node scripts/seed-hourly-checkins-dev.js --database=(default) --dev
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

const db = databaseId === '(default)' ? getFirestore() : getFirestore(databaseId);
const EVENT_ID = 'nlc-2026';

// Hours 7–14 = 7 AM–2 PM. Weight spread across 4 x 15-min buckets per hour.
const HOUR_COUNTS = [40, 85, 120, 145, 130, 95, 70, 45];

async function run() {
  const today = new Date();
  const y = today.getFullYear();
  const m = String(today.getMonth() + 1).padStart(2, '0');
  const day = String(today.getDate()).padStart(2, '0');

  const hourlyCheckins = {};
  let totalCheckins = 0;
  const quarters = ['00', '15', '30', '45'];
  for (let i = 0; i < 8; i++) {
    const hour = 7 + i;
    const H = String(hour).padStart(2, '0');
    const perQuarter = Math.max(1, Math.floor(HOUR_COUNTS[i] / 4));
    for (const mm of quarters) {
      const key = `${y}-${m}-${day}-${H}-${mm}`;
      hourlyCheckins[key] = perQuarter;
      totalCheckins += perQuarter;
    }
  }

  const ref = db.doc(`events/${EVENT_ID}/analytics/global`);
  await ref.set({
    hourlyCheckins,
    totalCheckins,
    totalUniqueAttendees: 350, // placeholder
    lastUpdated: FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log('Done. Updated analytics/global in database=' + databaseId);
  console.log('  hourlyCheckins: 32 x 15-min buckets (7 AM–2 PM), total=' + totalCheckins);
  console.log('  Keys (sample):', Object.keys(hourlyCheckins).slice(0, 5).join(', ') + ' ...');
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
