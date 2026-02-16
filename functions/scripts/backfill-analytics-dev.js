/**
 * Backfill analytics docs from existing attendance.
 * Use after seeding attendance when onAttendanceCreate didn't run (or to fix stale analytics).
 *
 * Match the app's database. App uses (default).
 *
 * Run:
 *   cd functions && node scripts/backfill-analytics-dev.js --dev
 *   cd functions && node scripts/backfill-analytics-dev.js "--database=(default)" --dev
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

const db = getFirestore(databaseId);
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

function getRegisteredAt(data) {
  if (!data) return null;
  const v = data.registeredAt ?? data.createdAt;
  return v && typeof v?.toDate === 'function' ? v : null;
}

const safe = (s) => String(s).replace(/\./g, '_');

function hourBucket(ts) {
  const d = ts.toDate();
  const y = d.getFullYear();
  const M = String(d.getMonth() + 1).padStart(2, '0');
  const d_ = String(d.getDate()).padStart(2, '0');
  const H = String(d.getHours()).padStart(2, '0');
  return `${y}-${M}-${d_}-${H}`;
}

async function run() {
  console.log('Backfilling analytics (DEV) database=' + databaseId + ' event=' + EVENT_ID);

  const globalRegionCounts = {};
  const globalMinistryCounts = {};
  const globalHourlyCheckins = {};
  let earliestCheckin = null;
  const sessionData = {};
  const seenRegistrants = new Set();

  const sessionsSnap = await db.collection(`events/${EVENT_ID}/sessions`).get();

  for (const sessionDoc of sessionsSnap.docs) {
    const sessionId = sessionDoc.id;
    if (!sessionData[sessionId]) {
      sessionData[sessionId] = { attendance: 0, regionCounts: {}, ministryCounts: {} };
    }
    const sd = sessionData[sessionId];

    const attendanceSnap = await db
      .collection(`events/${EVENT_ID}/sessions/${sessionId}/attendance`)
      .get();

    for (const attDoc of attendanceSnap.docs) {
      const registrantId = attDoc.id;
      const attData = attDoc.data();
      const checkedInAt = attData?.checkedInAt;
      const ts = checkedInAt ?? admin.firestore.Timestamp.now();
      const isNew = !seenRegistrants.has(registrantId);
      if (isNew) seenRegistrants.add(registrantId);

      sd.attendance++;

      const registrantSnap = await db.doc(`events/${EVENT_ID}/registrants/${registrantId}`).get();
      const r = registrantSnap.data() || {};
      const region = getString(r, 'region', 'regionMembership') ?? 'Unknown';
      const ministry = getString(r, 'ministryMembership', 'ministry') ?? 'Unknown';
      const rk = safe(region);
      const mk = safe(ministry);
      const hk = hourBucket(ts);

      globalRegionCounts[rk] = (globalRegionCounts[rk] ?? 0) + 1;
      globalMinistryCounts[mk] = (globalMinistryCounts[mk] ?? 0) + 1;
      globalHourlyCheckins[hk] = (globalHourlyCheckins[hk] ?? 0) + 1;
      sd.regionCounts[rk] = (sd.regionCounts[rk] ?? 0) + 1;
      sd.ministryCounts[mk] = (sd.ministryCounts[mk] ?? 0) + 1;

      const existingTs = earliestCheckin?.timestamp?.toDate?.()?.getTime?.() ?? Infinity;
      const newTs = ts.toDate?.()?.getTime?.() ?? 0;
      if (newTs < existingTs || !earliestCheckin) {
        earliestCheckin = { registrantId, sessionId, timestamp: ts };
      }

      if (isNew) {
        await db.doc(`events/${EVENT_ID}/attendeeIndex/${registrantId}`).set({
          firstSession: sessionId,
          firstCheckinTime: ts,
        }, { merge: true });
      }
    }

    await db.doc(`events/${EVENT_ID}/sessions/${sessionId}/analytics/summary`).set({
      attendanceCount: sd.attendance,
      regionCounts: sd.regionCounts,
      ministryCounts: sd.ministryCounts,
      lastUpdated: FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log('  Session', sessionId + ':', sd.attendance, 'attendance');
  }

  let earliestRegistration = null;
  const registrantsSnap = await db.collection(`events/${EVENT_ID}/registrants`).get();
  for (const doc of registrantsSnap.docs) {
    const regAt = getRegisteredAt(doc.data());
    if (regAt) {
      const existingTs = earliestRegistration?.timestamp?.toDate?.()?.getTime?.() ?? Infinity;
      const newTs = regAt.toDate?.()?.getTime?.() ?? 0;
      if (newTs < existingTs || !earliestRegistration) {
        earliestRegistration = { registrantId: doc.id, timestamp: regAt };
      }
    }
  }

  const totalCheckins = Object.values(sessionData).reduce((a, s) => a + s.attendance, 0);
  await db.doc(`events/${EVENT_ID}/analytics/global`).set({
    totalUniqueAttendees: seenRegistrants.size,
    totalCheckins,
    regionCounts: globalRegionCounts,
    ministryCounts: globalMinistryCounts,
    hourlyCheckins: globalHourlyCheckins,
    earliestCheckin: earliestCheckin ?? null,
    earliestRegistration: earliestRegistration ?? null,
    lastUpdated: FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log('Done. analytics/global: totalCheckins=' + totalCheckins + ', unique=' + seenRegistrants.size);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
