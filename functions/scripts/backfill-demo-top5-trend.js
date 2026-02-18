/**
 * Demo-only backfill: updates only Top 5 Regions, Top 5 Ministries, and Check-In Trend.
 * Writes only regionCounts, ministryCounts, hourlyCheckins (and lastUpdated) to
 * events/nlc-2026/analytics/global. Does not touch session summaries, attendeeIndex,
 * totalCheckins, earliestCheckin, etc. Use after the gradual check-in demo script.
 *
 * App uses (default). Run from functions/ with same database:
 *
 *   node scripts/backfill-demo-top5-trend.js "--database=(default)" --dev
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
  console.error('ABORT: Add --dev to confirm dev environment.');
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

function getString(data, ...keys) {
  if (!data) return null;
  for (const key of keys) {
    const profile = data.profile || {};
    const answers = data.answers || {};
    const v = data[key] ?? profile[key] ?? answers[key];
    if (v != null && typeof v === 'string' && v.trim()) return v.trim();
  }
  return null;
}

const safe = (s) => String(s).replace(/\./g, '_');

/** 15-minute bucket: YYYY-MM-DD-HH-mm. Matches Cloud Function and chart parser. */
function quarterHourBucket(ts) {
  const d = ts.toDate();
  const y = d.getFullYear();
  const M = String(d.getMonth() + 1).padStart(2, '0');
  const d_ = String(d.getDate()).padStart(2, '0');
  const H = String(d.getHours()).padStart(2, '0');
  const min15 = Math.floor(d.getMinutes() / 15) * 15;
  const mm = String(min15).padStart(2, '0');
  return `${y}-${M}-${d_}-${H}-${mm}`;
}

async function run() {
  console.log('Backfill demo (Top 5 + trend only) database=' + databaseId + ' event=' + EVENT_ID);

  const globalRegionCounts = {};
  const globalMinistryCounts = {};
  const globalHourlyCheckins = {};

  const sessionsSnap = await db.collection(`events/${EVENT_ID}/sessions`).get();
  if (sessionsSnap.empty) {
    console.error('No sessions found. Run bootstrap first: node scripts/ensure-nlc-event-doc.js "--database=(default)"');
    process.exit(1);
  }
  console.log('  Sessions found: ' + sessionsSnap.docs.map((d) => d.id).join(', '));

  let totalAttendance = 0;
  for (const sessionDoc of sessionsSnap.docs) {
    const sessionId = sessionDoc.id;
    const attendanceSnap = await db
      .collection(`events/${EVENT_ID}/sessions/${sessionId}/attendance`)
      .get();
    if (attendanceSnap.size > 0) {
      console.log('  Attendance in ' + sessionId + ': ' + attendanceSnap.size + ' docs');
    }

    for (const attDoc of attendanceSnap.docs) {
      const registrantId = attDoc.id;
      const attData = attDoc.data();
      const checkedInAt = attData?.checkedInAt;
      const ts = checkedInAt ?? admin.firestore.Timestamp.now();

      const registrantSnap = await db.doc(`events/${EVENT_ID}/registrants/${registrantId}`).get();
      const r = registrantSnap.data() || {};
      const region = getString(r, 'region', 'regionMembership', 'Region') ?? 'Unknown';
      const ministry = getString(r, 'ministryMembership', 'ministry', 'Ministry') ?? 'Unknown';
      const rk = safe(region);
      const mk = safe(ministry);
      const hk = quarterHourBucket(ts);

      globalRegionCounts[rk] = (globalRegionCounts[rk] ?? 0) + 1;
      globalMinistryCounts[mk] = (globalMinistryCounts[mk] ?? 0) + 1;
      globalHourlyCheckins[hk] = (globalHourlyCheckins[hk] ?? 0) + 1;
      totalAttendance++;
    }
  }

  const rcKeys = Object.keys(globalRegionCounts).length;
  const mcKeys = Object.keys(globalMinistryCounts).length;
  const hcKeys = Object.keys(globalHourlyCheckins).length;

  await db.doc(`events/${EVENT_ID}/analytics/global`).set({
    regionCounts: globalRegionCounts,
    ministryCounts: globalMinistryCounts,
    hourlyCheckins: globalHourlyCheckins,
    lastUpdated: FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log('Done. Updated only Top 5 + Check-In Trend in analytics/global');
  console.log('  attendance processed: ' + totalAttendance);
  console.log('  regionCounts (Top 5 Regions): ' + rcKeys + ' keys');
  console.log('  ministryCounts (Top 5 Ministries): ' + mcKeys + ' keys');
  console.log('  hourlyCheckins (Check-In Trend): ' + hcKeys + ' keys');
  if (rcKeys === 0 && mcKeys === 0 && hcKeys === 0) {
    console.log('  >>> No attendance found. Run the gradual check-in script first, then this backfill.');
  }
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
