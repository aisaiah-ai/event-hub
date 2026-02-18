/**
 * Print events/nlc-2026/analytics/global (including hourlyCheckins) so you can
 * verify the check-in trend has data. Use the same database as the app (default).
 *
 * Run:
 *   cd functions && node scripts/inspect-analytics-global.js "--database=(default)" --dev
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
  console.error('ABORT: Add --dev');
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = databaseId === '(default)' ? getFirestore() : getFirestore(databaseId);
const EVENT_ID = 'nlc-2026';

async function run() {
  console.log('Database:', databaseId);
  console.log('Path: events/' + EVENT_ID + '/analytics/global');
  console.log('');

  const ref = db.doc(`events/${EVENT_ID}/analytics/global`);
  const snap = await ref.get();

  if (!snap.exists) {
    console.log('Document does NOT exist. Create attendance and run the Cloud Function (onAttendanceCreate), or run backfill:');
    console.log('  node scripts/backfill-analytics-dev.js "--database=(default)" --dev');
    console.log('Or seed fake trend data:');
    console.log('  node scripts/seed-hourly-checkins-dev.js "--database=(default)" --dev');
    process.exit(0);
  }

  const data = snap.data();
  console.log('Document exists.');
  console.log('totalCheckins:', data.totalCheckins);
  console.log('totalRegistrants:', data.totalRegistrants);
  console.log('totalUniqueAttendees:', data.totalUniqueAttendees);
  console.log('');

  const rc = data.regionCounts;
  const mc = data.ministryCounts;
  const rcOk = rc && typeof rc === 'object' && !Array.isArray(rc);
  const mcOk = mc && typeof mc === 'object' && !Array.isArray(mc);

  console.log('regionCounts (Top 5 Regions):', rcOk ? Object.keys(rc).length + ' entries' : 'missing or not a map');
  if (rcOk && Object.keys(rc).length > 0) {
    Object.entries(rc).sort((a, b) => b[1] - a[1]).slice(0, 5).forEach(([k, v]) => console.log('  ', k, '=>', v));
  } else if (rcOk) {
    console.log('  (empty — run backfill to populate from registrants + attendance)');
  }
  console.log('');

  console.log('ministryCounts (Top 5 Ministries):', mcOk ? Object.keys(mc).length + ' entries' : 'missing or not a map');
  if (mcOk && Object.keys(mc).length > 0) {
    Object.entries(mc).sort((a, b) => b[1] - a[1]).slice(0, 5).forEach(([k, v]) => console.log('  ', k, '=>', v));
  } else if (mcOk) {
    console.log('  (empty — run backfill to populate from registrants + attendance)');
  }
  console.log('');

  const hc = data.hourlyCheckins;
  if (!hc || typeof hc !== 'object' || Array.isArray(hc)) {
    console.log('hourlyCheckins: missing or not a map (Check-In Trend chart empty). Expected keys YYYY-MM-DD-HH-mm (15-min).');
  } else {
    const keys = Object.keys(hc).sort();
    console.log('hourlyCheckins (Check-In Trend):', keys.length, 'keys');
    if (keys.length === 0) {
      console.log('  (empty — run backfill or create new check-ins)');
    } else {
      keys.slice(0, 20).forEach((k) => console.log('  ', k, '=>', hc[k]));
      if (keys.length > 20) console.log('  ... and', keys.length - 20, 'more');
    }
  }

  const hcEmpty = !hc || typeof hc !== 'object' || Array.isArray(hc) || Object.keys(hc).length === 0;
  const allEmpty = (!rcOk || Object.keys(rc).length === 0) && (!mcOk || Object.keys(mc).length === 0) && hcEmpty;
  if (allEmpty) {
    console.log('');
    console.log('>>> All dashboard aggregates are empty. Populate from existing attendance:');
    console.log('    node scripts/backfill-analytics-dev.js "--database=' + databaseId + '" --dev');
    console.log('(Backfill reads registrants for region/ministry and attendance for counts; use same database as the app.)');
  }
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
