/**
 * NLC 2026 Check-In Analytics — Production Audit
 *
 * Triggers:
 * - events/{eventId}/registrants/{registrantId} onUpdate:
 *   - event check-in: eventAttendance.checkedInAt null → timestamp
 *   - session check-in: sessionsCheckedIn.{sessionId} key added
 * - events/{eventId}/registrants/{registrantId} onCreate: totalRegistrations, earlyBird
 * - events/{eventId}/sessions/{sessionId}/attendance/{registrantId} onCreate: session-only check-in
 *
 * All aggregates use transactions for atomicity and idempotency.
 * Stats: events/{eventId}/stats/overview
 * Buckets: events/{eventId}/stats/checkinBuckets/{yyyyMMddHHmm}
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

/** Look up string from registrant doc: top-level, profile, or answers. Keys tried in order. */
function getString(
  data: admin.firestore.DocumentData | undefined,
  ...keys: string[]
): string | null {
  if (!data) return null;
  const d = data as Record<string, unknown>;
  const profile = (d.profile as Record<string, unknown>) || {};
  const answers = (d.answers as Record<string, unknown>) || {};
  for (const key of keys) {
    const v = d[key] ?? profile[key] ?? answers[key];
    if (v != null && typeof v === "string" && (v as string).trim()) return (v as string).trim();
  }
  return null;
}

function isEarlyBird(data: admin.firestore.DocumentData | undefined): boolean {
  if (!data) return false;
  const v =
    data.isEarlyBird ??
    (data.profile as Record<string, unknown>)?.isEarlyBird ??
    (data.answers as Record<string, unknown>)?.isEarlyBird;
  return v === true || v === "true" || v === "yes";
}

function getRegisteredAt(data: admin.firestore.DocumentData | undefined): admin.firestore.Timestamp | null {
  if (!data) return null;
  const v = data.registeredAt ?? data.createdAt;
  return v && typeof v?.toDate === "function" ? v : null;
}

/** Normalize for regionOtherText: trim, lowercase, collapse whitespace */
function normalizeRegionOther(text: string): string {
  return text
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ") || "(empty)";
}

const safe = (s: string) => s.replace(/\./g, "_");

/** 15-minute bucket: YYYY-MM-DD-HH-mm (mm = 00, 15, 30, 45). Used for check-in trend graph. */
function quarterHourBucket(ts: admin.firestore.Timestamp): string {
  const d = ts.toDate();
  const y = d.getFullYear();
  const M = String(d.getMonth() + 1).padStart(2, "0");
  const d_ = String(d.getDate()).padStart(2, "0");
  const H = String(d.getHours()).padStart(2, "0");
  const min15 = Math.floor(d.getMinutes() / 15) * 15;
  const mm = String(min15).padStart(2, "0");
  return `${y}-${M}-${d_}-${H}-${mm}`;
}

/** Bucket ID: yyyyMMddHHmm */
function bucketId(ts: admin.firestore.Timestamp): string {
  const d = ts.toDate();
  const y = d.getFullYear();
  const M = String(d.getMonth() + 1).padStart(2, "0");
  const d_ = String(d.getDate()).padStart(2, "0");
  const H = String(d.getHours()).padStart(2, "0");
  const m = String(d.getMinutes()).padStart(2, "0");
  return `${y}${M}${d_}${H}${m}`;
}

function top5(m: Record<string, number>): { name: string; count: number }[] {
  return Object.entries(m)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([name, count]) => ({ name, count }));
}

/** Full stats/overview structure per NLC 2026 data model. Must exist before analytics. */
const STATS_OVERVIEW_INITIAL: Record<string, unknown> = {
  totalRegistrations: 0,
  totalCheckedIn: 0,
  earlyBirdCount: 0,
  regionCounts: {},
  regionOtherTextCounts: {},
  ministryCounts: {},
  serviceCounts: {},
  sessionTotals: {},
  firstCheckInAt: null,
  firstCheckInRegistrantId: null,
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
};

/** Ensure stats doc exists (merge). */
async function ensureStatsDoc(eventId: string): Promise<void> {
  const ref = db.doc(`events/${eventId}/stats/overview`);
  await ref.set(STATS_OVERVIEW_INITIAL, { merge: true });
}

const NLC_2026_EVENT_ID = "nlc-2026";

/** Default sessions created by bootstrap if missing. */
const NLC_2026_DEFAULT_SESSIONS: { id: string; name: string; location: string; order: number }[] = [
  { id: "opening-plenary", name: "Opening Plenary", location: "Grand Ballroom", order: 1 },
  { id: "leadership-session-1", name: "Leadership Session 1", location: "Grand Ballroom", order: 2 },
  { id: "mass", name: "Mass", location: "Main Chapel", order: 3 },
  { id: "closing", name: "Closing", location: "Grand Ballroom", order: 4 },
];

/**
 * Callable: initializeNlc2026()
 * Creates event doc, sessions, and stats/overview if missing. Idempotent. Admin only.
 */
export const initializeNlc2026 = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be authenticated");
  }
  const email = context.auth.token.email;
  if (!email) {
    throw new functions.https.HttpsError("permission-denied", "No email");
  }
  const eventRef = db.doc(`events/${NLC_2026_EVENT_ID}`);
  const eventSnap = await eventRef.get();
  const adminsRef = db.doc(`events/${NLC_2026_EVENT_ID}/admins/${email}`);
  const adminSnap = await adminsRef.get();
  const isAdmin = adminSnap.exists && (adminSnap.data()?.role === "ADMIN" || adminSnap.data()?.role === "STAFF");
  if (!isAdmin) {
    throw new functions.https.HttpsError("permission-denied", "Only admin can run initializeNlc2026");
  }

  const batch = db.batch();

  if (!eventSnap.exists) {
    batch.set(eventRef, {
      name: "National Leaders Conference 2026",
      venue: "Hyatt Regency Valencia",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isActive: true,
      metadata: { selfCheckinEnabled: true, sessionsEnabled: true },
    }, { merge: true });
  } else {
    batch.set(eventRef, {
      metadata: { selfCheckinEnabled: true, sessionsEnabled: true },
    }, { merge: true });
  }

  for (const s of NLC_2026_DEFAULT_SESSIONS) {
    const sessionRef = db.doc(`events/${NLC_2026_EVENT_ID}/sessions/${s.id}`);
    batch.set(sessionRef, {
      name: s.name,
      location: s.location,
      order: s.order,
      isActive: true,
    }, { merge: true });
  }

  const statsRef = db.doc(`events/${NLC_2026_EVENT_ID}/stats/overview`);
  batch.set(statsRef, STATS_OVERVIEW_INITIAL, { merge: true });

  await batch.commit();
  return { ok: true, message: "NLC 2026 event, sessions, and stats/overview initialized (or updated)." };
});

/**
 * onRegistrantCheckIn: events/{eventId}/registrants/{registrantId} onUpdate
 * Idempotent: only act on (1) event check-in: checkedInAt null→set (2) session: newly added keys.
 */
export const onRegistrantCheckIn = functions.firestore
  .document("events/{eventId}/registrants/{registrantId}")
  .onUpdate(async (change, context) => {
    const eventId = context.params.eventId as string;
    const registrantId = context.params.registrantId as string;

    const before = change.before.data();
    const after = change.after.data();

    const beforeCheckedInAt = before?.eventAttendance?.checkedInAt ?? null;
    const afterCheckedInAt = after?.eventAttendance?.checkedInAt ?? null;

    const beforeSessions = (before?.sessionsCheckedIn ?? {}) as Record<string, admin.firestore.Timestamp>;
    const afterSessions = (after?.sessionsCheckedIn ?? {}) as Record<string, admin.firestore.Timestamp>;
    const beforeKeys = new Set(Object.keys(beforeSessions));
    const afterKeys = new Set(Object.keys(afterSessions));
    const addedSessionIds = [...afterKeys].filter((k) => !beforeKeys.has(k));

    const isEventCheckIn = beforeCheckedInAt == null && afterCheckedInAt != null;
    const hasNewSessions = addedSessionIds.length > 0;

    if (!isEventCheckIn && !hasNewSessions) return null;

    const statsRef = db.doc(`events/${eventId}/stats/overview`);

    await db.runTransaction(async (tx) => {
      const statsSnap = await tx.get(statsRef);
      const stats = statsSnap.exists ? (statsSnap.data() ?? {}) : {};

      const region = getString(after, "region", "regionMembership", "Region") ?? "Unknown";
      const regionOther = getString(after, "regionOtherText", "regionOther");
      const ministry = getString(after, "ministryMembership", "ministry", "Ministry") ?? "Unknown";
      const service = getString(after, "service") ?? "Unknown";
      const earlyBird = isEarlyBird(after);

      const regionCounts = { ...(stats.regionCounts as Record<string, number> || {}) };
      const ministryCounts = { ...(stats.ministryCounts as Record<string, number> || {}) };
      const serviceCounts = { ...(stats.serviceCounts as Record<string, number> || {}) };
      const sessionTotals = { ...(stats.sessionTotals as Record<string, number> || {}) };
      const regionOtherTextCounts = { ...(stats.regionOtherTextCounts as Record<string, number> || {}) };
      const firstSessionCheckIn = { ...(stats.firstSessionCheckIn as Record<string, { at: admin.firestore.Timestamp; registrantId: string }> || {}) };

      if (isEventCheckIn) {
        regionCounts[safe(region)] = (regionCounts[safe(region)] ?? 0) + 1;
        ministryCounts[safe(ministry)] = (ministryCounts[safe(ministry)] ?? 0) + 1;
        serviceCounts[safe(service)] = (serviceCounts[safe(service)] ?? 0) + 1;
        if (regionOther && (region?.toLowerCase() === "other" || regionOther)) {
          const norm = normalizeRegionOther(regionOther);
          regionOtherTextCounts[safe(norm)] = (regionOtherTextCounts[safe(norm)] ?? 0) + 1;
        }
      }

      for (const sid of addedSessionIds) {
        sessionTotals[safe(sid)] = (sessionTotals[safe(sid)] ?? 0) + 1;
        if (!firstSessionCheckIn[safe(sid)]) {
          const ts = afterSessions[sid] ?? afterCheckedInAt;
          if (ts) {
            firstSessionCheckIn[safe(sid)] = { at: ts, registrantId };
          }
        }
      }

      const updates: Record<string, unknown> = {
        totalCheckedIn: admin.firestore.FieldValue.increment(isEventCheckIn ? 1 : 0),
        ...(isEventCheckIn && earlyBird
          ? { earlyBirdCount: admin.firestore.FieldValue.increment(1) }
          : {}),
        regionCounts,
        ministryCounts,
        serviceCounts,
        sessionTotals,
        regionOtherTextCounts,
        firstSessionCheckIn,
        top5Regions: top5(regionCounts),
        top5Ministries: top5(ministryCounts),
        top5Services: top5(serviceCounts),
        top5RegionOtherText: top5(regionOtherTextCounts),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (isEventCheckIn) {
        if (!stats.firstCheckInAt) {
          updates.firstCheckInAt = afterCheckedInAt;
          updates.firstCheckInRegistrantId = registrantId;
        }
      }

      tx.set(statsRef, updates, { merge: true });
    });

    if (isEventCheckIn && afterCheckedInAt) {
      await updateCheckInBucket(eventId, afterCheckedInAt as admin.firestore.Timestamp);
    }

    return null;
  });

async function updateCheckInBucket(eventId: string, ts: admin.firestore.Timestamp): Promise<void> {
  const bid = bucketId(ts);
  const bucketRef = db.doc(`events/${eventId}/stats/overview/checkinBuckets/${bid}`);
  await bucketRef.set(
    { count: admin.firestore.FieldValue.increment(1) },
    { merge: true }
  );

  const bucketSnap = await bucketRef.get();
  const count = (bucketSnap.data()?.count as number) ?? 0;
  const statsRef = db.doc(`events/${eventId}/stats/overview`);
  const statsSnap = await statsRef.get();
  const stats = statsSnap.data() ?? {};
  const peak = (stats.peakMinuteCount as number) ?? 0;
  if (count > peak) {
    await statsRef.update({
      peakMinuteBucketId: bid,
      peakMinuteCount: count,
      peakCheckInMinute: bid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

/**
 * onRegistrantCreate: totalRegistrations, earlyBirdCount, firstEarlyBird*.
 * Ensure stats doc exists.
 */
export const onRegistrantCreate = functions.firestore
  .document("events/{eventId}/registrants/{registrantId}")
  .onCreate(async (snap, context) => {
    const eventId = context.params.eventId as string;
    const registrantId = context.params.registrantId as string;
    const data = snap.data();

    const statsRef = db.doc(`events/${eventId}/stats/overview`);
    const globalAnalyticsRef = db.doc(`events/${eventId}/analytics/global`);
    const registeredAt = getRegisteredAt(data);

    await db.runTransaction(async (tx) => {
      const statsSnap = await tx.get(statsRef);
      const stats = statsSnap.data() ?? {};
      const ensureExists = !statsSnap.exists;

      const updates: Record<string, unknown> = {
        totalRegistrations: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (ensureExists) {
        updates.totalCheckedIn = 0;
        updates.earlyBirdCount = 0;
      }

      const early = isEarlyBird(data);
      if (early) {
        updates.earlyBirdCount = admin.firestore.FieldValue.increment(1);
        if (registeredAt) {
          const existing = stats.firstEarlyBirdRegisteredAt as admin.firestore.Timestamp | undefined;
          const existingAt = existing?.toDate?.()?.getTime?.() ?? Infinity;
          const newAt = registeredAt.toDate?.()?.getTime?.() ?? 0;
          if (newAt < existingAt || !existing) {
            updates.firstEarlyBirdRegisteredAt = registeredAt;
            updates.firstEarlyBirdRegistrantId = registrantId;
          }
        }
      }

      tx.set(statsRef, updates, { merge: true });
      tx.set(globalAnalyticsRef, {
        totalRegistrants: admin.firestore.FieldValue.increment(1),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    });

    return null;
  });

/**
 * onAttendanceCreate: sessions/{sessionId}/attendance/{registrantId} onCreate
 * Pure Session Architecture: updates scalable analytics counters.
 * 1. Increment session analytics/summary attendanceCount, regionCounts, ministryCounts
 * 2. Increment global analytics totalCheckins, regionCounts, ministryCounts, hourlyCheckins
 * 3. If attendeeIndex does NOT exist: create it and increment totalUniqueAttendees
 * 4. Update earliestCheckin if earlier
 * Also keeps stats/overview for legacy dashboard compatibility.
 */
export const onAttendanceCreate = functions.firestore
  .document("events/{eventId}/sessions/{sessionId}/attendance/{registrantId}")
  .onCreate(async (snap, context) => {
    const eventId = context.params.eventId as string;
    const sessionId = context.params.sessionId as string;
    const registrantId = context.params.registrantId as string;

    const data = snap.data();
    const checkedInAt = data?.checkedInAt as admin.firestore.Timestamp | undefined;
    const ts = checkedInAt ?? admin.firestore.Timestamp.now();

    const registrantRef = db.doc(`events/${eventId}/registrants/${registrantId}`);
    const registrantSnap = await registrantRef.get();
    const r = registrantSnap.data();
    // Region/ministry from registration: try common keys (top-level, profile, answers).
    const region = getString(r, "region", "regionMembership", "Region") ?? "Unknown";
    const ministry = getString(r, "ministryMembership", "ministry", "Ministry") ?? "Unknown";

    const statsRef = db.doc(`events/${eventId}/stats/overview`);
    const globalAnalyticsRef = db.doc(`events/${eventId}/analytics/global`);
    const sessionAnalyticsRef = db.doc(`events/${eventId}/sessions/${sessionId}/analytics/summary`);
    const attendeeIndexRef = db.doc(`events/${eventId}/attendeeIndex/${registrantId}`);

    await db.runTransaction(async (tx) => {
      const attendeeIndexSnap = await tx.get(attendeeIndexRef);
      const isNewUniqueAttendee = !attendeeIndexSnap.exists;

      const globalSnap = await tx.get(globalAnalyticsRef);
      const global = globalSnap.data() ?? {};
      const sessionSnap = await tx.get(sessionAnalyticsRef);
      const sessionData = sessionSnap.data() ?? {};

      const regionKey = safe(region);
      const ministryKey = safe(ministry);
      const hourKey = quarterHourBucket(ts);

      const globalRegionCounts = { ...(global.regionCounts as Record<string, number> || {}) };
      const globalMinistryCounts = { ...(global.ministryCounts as Record<string, number> || {}) };
      const globalHourlyCheckins = { ...(global.hourlyCheckins as Record<string, number> || {}) };

      globalRegionCounts[regionKey] = (globalRegionCounts[regionKey] ?? 0) + 1;
      globalMinistryCounts[ministryKey] = (globalMinistryCounts[ministryKey] ?? 0) + 1;
      globalHourlyCheckins[hourKey] = (globalHourlyCheckins[hourKey] ?? 0) + 1;

      const sessionRegionCounts = { ...(sessionData.regionCounts as Record<string, number> || {}) };
      const sessionMinistryCounts = { ...(sessionData.ministryCounts as Record<string, number> || {}) };
      sessionRegionCounts[regionKey] = (sessionRegionCounts[regionKey] ?? 0) + 1;
      sessionMinistryCounts[ministryKey] = (sessionMinistryCounts[ministryKey] ?? 0) + 1;

      const existingEarliest = global.earliestCheckin as { timestamp: admin.firestore.Timestamp } | undefined;
      const existingTs = existingEarliest?.timestamp?.toDate?.()?.getTime?.() ?? Infinity;
      const newTs = ts.toDate?.()?.getTime?.() ?? 0;
      const shouldUpdateEarliest = newTs < existingTs || !existingEarliest;

      const globalUpdates: Record<string, unknown> = {
        totalCheckins: admin.firestore.FieldValue.increment(1),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        regionCounts: globalRegionCounts,
        ministryCounts: globalMinistryCounts,
        hourlyCheckins: globalHourlyCheckins,
      };
      if (isNewUniqueAttendee) {
        (globalUpdates as Record<string, unknown>).totalUniqueAttendees = admin.firestore.FieldValue.increment(1);
      }
      if (shouldUpdateEarliest) {
        (globalUpdates as Record<string, unknown>).earliestCheckin = {
          registrantId,
          sessionId,
          timestamp: ts,
        };
      }
      tx.set(globalAnalyticsRef, globalUpdates, { merge: true });

      tx.set(sessionAnalyticsRef, {
        attendanceCount: admin.firestore.FieldValue.increment(1),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        regionCounts: sessionRegionCounts,
        ministryCounts: sessionMinistryCounts,
      }, { merge: true });

      if (isNewUniqueAttendee) {
        tx.set(attendeeIndexRef, {
          firstSession: sessionId,
          firstCheckinTime: ts,
        });
      }

      const statsSnap = await tx.get(statsRef);
      const stats = statsSnap.data() ?? {};
      const sessionTotals = { ...(stats.sessionTotals as Record<string, number> || {}) };
      const firstSessionCheckIn = { ...(stats.firstSessionCheckIn as Record<string, { at: admin.firestore.Timestamp; registrantId: string }> || {}) };
      const sk = safe(sessionId);
      sessionTotals[sk] = (sessionTotals[sk] ?? 0) + 1;
      if (!firstSessionCheckIn[sk] && checkedInAt) {
        firstSessionCheckIn[sk] = { at: checkedInAt, registrantId };
      }
      tx.set(statsRef, {
        sessionTotals,
        firstSessionCheckIn,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    });

    return null;
  });

/** Callable: backfill stats doc. Admin only. */
export const backfillStats = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be authenticated");
  }
  const eventId = data?.eventId as string;
  if (!eventId) {
    throw new functions.https.HttpsError("invalid-argument", "eventId required");
  }
  await ensureStatsDoc(eventId);
  return { ok: true, eventId };
});

/**
 * Callable: backfill analytics docs (global, session summary, attendeeIndex).
 * Rebuilds: totalCheckins, totalUniqueAttendees, regionCounts, ministryCounts,
 * hourlyCheckins, earliestCheckin, session summaries.
 * Scans registrants for earliestRegistration.
 * Admin only. Run once for existing data.
 */
export const backfillAnalytics = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be authenticated");
  }
  const eventId = data?.eventId as string;
  if (!eventId) {
    throw new functions.https.HttpsError("invalid-argument", "eventId required");
  }
  const email = context.auth?.token?.email;
  if (!email) {
    throw new functions.https.HttpsError("permission-denied", "No email");
  }
  const adminsRef = db.doc(`events/${eventId}/admins/${email}`);
  const adminSnap = await adminsRef.get();
  const isAdmin = adminSnap.exists && (adminSnap.data()?.role === "ADMIN" || adminSnap.data()?.role === "STAFF");
  if (!isAdmin) {
    throw new functions.https.HttpsError("permission-denied", "Only admin can run backfillAnalytics");
  }

  const globalRegionCounts: Record<string, number> = {};
  const globalMinistryCounts: Record<string, number> = {};
  const globalHourlyCheckins: Record<string, number> = {};
  let earliestCheckin: { registrantId: string; sessionId: string; timestamp: admin.firestore.Timestamp } | null = null;
  const sessionData: Record<string, { attendance: number; regionCounts: Record<string, number>; ministryCounts: Record<string, number> }> = {};
  const seenRegistrants = new Set<string>();

  const sessionsSnap = await db.collection(`events/${eventId}/sessions`).get();

  for (const sessionDoc of sessionsSnap.docs) {
    const sessionId = sessionDoc.id;
    if (!sessionData[sessionId]) {
      sessionData[sessionId] = { attendance: 0, regionCounts: {}, ministryCounts: {} };
    }
    const sd = sessionData[sessionId];

    const attendanceSnap = await db
      .collection(`events/${eventId}/sessions/${sessionId}/attendance`)
      .get();

    for (const attDoc of attendanceSnap.docs) {
      const registrantId = attDoc.id;
      const attData = attDoc.data();
      const checkedInAt = attData?.checkedInAt as admin.firestore.Timestamp | undefined;
      const ts = checkedInAt ?? admin.firestore.Timestamp.now();
      const isNew = !seenRegistrants.has(registrantId);
      if (isNew) seenRegistrants.add(registrantId);

      sd.attendance++;

      const registrantSnap = await db.doc(`events/${eventId}/registrants/${registrantId}`).get();
      const r = registrantSnap.data();
      const region = getString(r, "region", "regionMembership", "Region") ?? "Unknown";
      const ministry = getString(r, "ministryMembership", "ministry", "Ministry") ?? "Unknown";
      const rk = safe(region);
      const mk = safe(ministry);
      const hk = quarterHourBucket(ts);

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
        await db.doc(`events/${eventId}/attendeeIndex/${registrantId}`).set({
          firstSession: sessionId,
          firstCheckinTime: ts,
        }, { merge: true });
      }
    }

    await db.doc(`events/${eventId}/sessions/${sessionId}/analytics/summary`).set({
      attendanceCount: sd.attendance,
      regionCounts: sd.regionCounts,
      ministryCounts: sd.ministryCounts,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  let earliestRegistration: { registrantId: string; timestamp: admin.firestore.Timestamp } | null = null;
  const registrantsSnap = await db.collection(`events/${eventId}/registrants`).get();
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
  const globalRef = db.doc(`events/${eventId}/analytics/global`);
  await globalRef.set({
    totalUniqueAttendees: seenRegistrants.size,
    totalCheckins,
    totalRegistrants: registrantsSnap.size,
    regionCounts: globalRegionCounts,
    ministryCounts: globalMinistryCounts,
    hourlyCheckins: globalHourlyCheckins,
    earliestCheckin: earliestCheckin ?? null,
    earliestRegistration: earliestRegistration ?? null,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  return {
    ok: true,
    eventId,
    totalUniqueAttendees: seenRegistrants.size,
    totalCheckins,
    sessionsProcessed: sessionsSnap.size,
  };
});

export * from "./checkinAnalytics";
