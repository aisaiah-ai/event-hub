"use strict";
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
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __exportStar = (this && this.__exportStar) || function(m, exports) {
    for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports, p)) __createBinding(exports, m, p);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.backfillAnalytics = exports.backfillStats = exports.onAttendanceCreateDev = exports.onAttendanceCreateProd = exports.onAttendanceCreate = exports.onRegistrantCreateDev = exports.onRegistrantCreateProd = exports.onRegistrantCreate = exports.onRegistrantCheckIn = exports.initializeNlc2026 = void 0;
const functions = __importStar(require("firebase-functions"));
const firestore_1 = require("firebase-functions/v2/firestore");
const admin = __importStar(require("firebase-admin"));
const firestore_2 = require("firebase-admin/firestore");
admin.initializeApp();
const db = admin.firestore();
// Named database instances for v2 triggers.
const DB_PROD = "event-hub-prod";
const DB_DEV = "event-hub-dev";
/** Look up string from registrant doc: top-level, profile, or answers. Keys tried in order. */
function getString(data, ...keys) {
    var _a, _b;
    if (!data)
        return null;
    const d = data;
    const profile = d.profile || {};
    const answers = d.answers || {};
    for (const key of keys) {
        const v = (_b = (_a = d[key]) !== null && _a !== void 0 ? _a : profile[key]) !== null && _b !== void 0 ? _b : answers[key];
        if (v != null && typeof v === "string" && v.trim())
            return v.trim();
    }
    return null;
}
function isEarlyBird(data) {
    var _a, _b, _c, _d;
    if (!data)
        return false;
    const v = (_c = (_a = data.isEarlyBird) !== null && _a !== void 0 ? _a : (_b = data.profile) === null || _b === void 0 ? void 0 : _b.isEarlyBird) !== null && _c !== void 0 ? _c : (_d = data.answers) === null || _d === void 0 ? void 0 : _d.isEarlyBird;
    return v === true || v === "true" || v === "yes";
}
function getRegisteredAt(data) {
    var _a;
    if (!data)
        return null;
    const v = (_a = data.registeredAt) !== null && _a !== void 0 ? _a : data.createdAt;
    return v && typeof (v === null || v === void 0 ? void 0 : v.toDate) === "function" ? v : null;
}
/** Normalize for regionOtherText: trim, lowercase, collapse whitespace */
function normalizeRegionOther(text) {
    return text
        .trim()
        .toLowerCase()
        .replace(/\s+/g, " ") || "(empty)";
}
const safe = (s) => s.replace(/\./g, "_");
/** 15-minute bucket: YYYY-MM-DD-HH-mm (mm = 00, 15, 30, 45). Used for check-in trend graph. */
function quarterHourBucket(ts) {
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
function bucketId(ts) {
    const d = ts.toDate();
    const y = d.getFullYear();
    const M = String(d.getMonth() + 1).padStart(2, "0");
    const d_ = String(d.getDate()).padStart(2, "0");
    const H = String(d.getHours()).padStart(2, "0");
    const m = String(d.getMinutes()).padStart(2, "0");
    return `${y}${M}${d_}${H}${m}`;
}
function top5(m) {
    return Object.entries(m)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5)
        .map(([name, count]) => ({ name, count }));
}
/** Full stats/overview structure per NLC 2026 data model. Must exist before analytics. */
const STATS_OVERVIEW_INITIAL = {
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
async function ensureStatsDoc(eventId) {
    const ref = db.doc(`events/${eventId}/stats/overview`);
    await ref.set(STATS_OVERVIEW_INITIAL, { merge: true });
}
const NLC_2026_EVENT_ID = "nlc-2026";
/** Default sessions created by bootstrap if missing. */
const NLC_2026_DEFAULT_SESSIONS = [
    { id: "opening-plenary", name: "Opening Plenary", location: "Grand Ballroom", order: 1 },
    { id: "leadership-session-1", name: "Leadership Session 1", location: "Grand Ballroom", order: 2 },
    { id: "mass", name: "Mass", location: "Main Chapel", order: 3 },
    { id: "closing", name: "Closing", location: "Grand Ballroom", order: 4 },
];
/**
 * Callable: initializeNlc2026()
 * Creates event doc, sessions, and stats/overview if missing. Idempotent. Admin only.
 */
exports.initializeNlc2026 = functions.https.onCall(async (data, context) => {
    var _a, _b;
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
    const isAdmin = adminSnap.exists && (((_a = adminSnap.data()) === null || _a === void 0 ? void 0 : _a.role) === "ADMIN" || ((_b = adminSnap.data()) === null || _b === void 0 ? void 0 : _b.role) === "STAFF");
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
    }
    else {
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
exports.onRegistrantCheckIn = functions.firestore
    .document("events/{eventId}/registrants/{registrantId}")
    .onUpdate(async (change, context) => {
    var _a, _b, _c, _d, _e, _f;
    const eventId = context.params.eventId;
    const registrantId = context.params.registrantId;
    const before = change.before.data();
    const after = change.after.data();
    const beforeCheckedInAt = (_b = (_a = before === null || before === void 0 ? void 0 : before.eventAttendance) === null || _a === void 0 ? void 0 : _a.checkedInAt) !== null && _b !== void 0 ? _b : null;
    const afterCheckedInAt = (_d = (_c = after === null || after === void 0 ? void 0 : after.eventAttendance) === null || _c === void 0 ? void 0 : _c.checkedInAt) !== null && _d !== void 0 ? _d : null;
    const beforeSessions = ((_e = before === null || before === void 0 ? void 0 : before.sessionsCheckedIn) !== null && _e !== void 0 ? _e : {});
    const afterSessions = ((_f = after === null || after === void 0 ? void 0 : after.sessionsCheckedIn) !== null && _f !== void 0 ? _f : {});
    const beforeKeys = new Set(Object.keys(beforeSessions));
    const afterKeys = new Set(Object.keys(afterSessions));
    const addedSessionIds = [...afterKeys].filter((k) => !beforeKeys.has(k));
    const isEventCheckIn = beforeCheckedInAt == null && afterCheckedInAt != null;
    const hasNewSessions = addedSessionIds.length > 0;
    if (!isEventCheckIn && !hasNewSessions)
        return null;
    const statsRef = db.doc(`events/${eventId}/stats/overview`);
    await db.runTransaction(async (tx) => {
        var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k;
        const statsSnap = await tx.get(statsRef);
        const stats = statsSnap.exists ? ((_a = statsSnap.data()) !== null && _a !== void 0 ? _a : {}) : {};
        const region = (_b = getString(after, "region", "regionMembership", "Region")) !== null && _b !== void 0 ? _b : "Unknown";
        const regionOther = getString(after, "regionOtherText", "regionOther");
        const ministry = (_c = getString(after, "ministryMembership", "ministry", "Ministry")) !== null && _c !== void 0 ? _c : "Unknown";
        const service = (_d = getString(after, "service")) !== null && _d !== void 0 ? _d : "Unknown";
        const earlyBird = isEarlyBird(after);
        const regionCounts = Object.assign({}, (stats.regionCounts || {}));
        const ministryCounts = Object.assign({}, (stats.ministryCounts || {}));
        const serviceCounts = Object.assign({}, (stats.serviceCounts || {}));
        const sessionTotals = Object.assign({}, (stats.sessionTotals || {}));
        const regionOtherTextCounts = Object.assign({}, (stats.regionOtherTextCounts || {}));
        const firstSessionCheckIn = Object.assign({}, (stats.firstSessionCheckIn || {}));
        if (isEventCheckIn) {
            regionCounts[safe(region)] = ((_e = regionCounts[safe(region)]) !== null && _e !== void 0 ? _e : 0) + 1;
            ministryCounts[safe(ministry)] = ((_f = ministryCounts[safe(ministry)]) !== null && _f !== void 0 ? _f : 0) + 1;
            serviceCounts[safe(service)] = ((_g = serviceCounts[safe(service)]) !== null && _g !== void 0 ? _g : 0) + 1;
            if (regionOther && ((region === null || region === void 0 ? void 0 : region.toLowerCase()) === "other" || regionOther)) {
                const norm = normalizeRegionOther(regionOther);
                regionOtherTextCounts[safe(norm)] = ((_h = regionOtherTextCounts[safe(norm)]) !== null && _h !== void 0 ? _h : 0) + 1;
            }
        }
        for (const sid of addedSessionIds) {
            sessionTotals[safe(sid)] = ((_j = sessionTotals[safe(sid)]) !== null && _j !== void 0 ? _j : 0) + 1;
            if (!firstSessionCheckIn[safe(sid)]) {
                const ts = (_k = afterSessions[sid]) !== null && _k !== void 0 ? _k : afterCheckedInAt;
                if (ts) {
                    firstSessionCheckIn[safe(sid)] = { at: ts, registrantId };
                }
            }
        }
        const updates = Object.assign(Object.assign({ totalCheckedIn: admin.firestore.FieldValue.increment(isEventCheckIn ? 1 : 0) }, (isEventCheckIn && earlyBird
            ? { earlyBirdCount: admin.firestore.FieldValue.increment(1) }
            : {})), { regionCounts,
            ministryCounts,
            serviceCounts,
            sessionTotals,
            regionOtherTextCounts,
            firstSessionCheckIn, top5Regions: top5(regionCounts), top5Ministries: top5(ministryCounts), top5Services: top5(serviceCounts), top5RegionOtherText: top5(regionOtherTextCounts), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
        if (isEventCheckIn) {
            if (!stats.firstCheckInAt) {
                updates.firstCheckInAt = afterCheckedInAt;
                updates.firstCheckInRegistrantId = registrantId;
            }
        }
        tx.set(statsRef, updates, { merge: true });
    });
    if (isEventCheckIn && afterCheckedInAt) {
        await updateCheckInBucket(eventId, afterCheckedInAt);
    }
    return null;
});
async function updateCheckInBucket(eventId, ts) {
    var _a, _b, _c, _d;
    const bid = bucketId(ts);
    const bucketRef = db.doc(`events/${eventId}/stats/overview/checkinBuckets/${bid}`);
    await bucketRef.set({ count: admin.firestore.FieldValue.increment(1) }, { merge: true });
    const bucketSnap = await bucketRef.get();
    const count = (_b = (_a = bucketSnap.data()) === null || _a === void 0 ? void 0 : _a.count) !== null && _b !== void 0 ? _b : 0;
    const statsRef = db.doc(`events/${eventId}/stats/overview`);
    const statsSnap = await statsRef.get();
    const stats = (_c = statsSnap.data()) !== null && _c !== void 0 ? _c : {};
    const peak = (_d = stats.peakMinuteCount) !== null && _d !== void 0 ? _d : 0;
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
 * Shared logic for registrant creation analytics update.
 */
async function handleRegistrantCreate(targetDb, eventId, registrantId, data) {
    const statsRef = targetDb.doc(`events/${eventId}/stats/overview`);
    const globalAnalyticsRef = targetDb.doc(`events/${eventId}/analytics/global`);
    const registeredAt = getRegisteredAt(data);
    await targetDb.runTransaction(async (tx) => {
        var _a, _b, _c, _d, _e, _f, _g, _h, _j;
        const statsSnap = await tx.get(statsRef);
        const stats = (_a = statsSnap.data()) !== null && _a !== void 0 ? _a : {};
        const ensureExists = !statsSnap.exists;
        const updates = {
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
                const existing = stats.firstEarlyBirdRegisteredAt;
                const existingAt = (_e = (_d = (_c = (_b = existing === null || existing === void 0 ? void 0 : existing.toDate) === null || _b === void 0 ? void 0 : _b.call(existing)) === null || _c === void 0 ? void 0 : _c.getTime) === null || _d === void 0 ? void 0 : _d.call(_c)) !== null && _e !== void 0 ? _e : Infinity;
                const newAt = (_j = (_h = (_g = (_f = registeredAt.toDate) === null || _f === void 0 ? void 0 : _f.call(registeredAt)) === null || _g === void 0 ? void 0 : _g.getTime) === null || _h === void 0 ? void 0 : _h.call(_g)) !== null && _j !== void 0 ? _j : 0;
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
}
/**
 * onRegistrantCreate (v1): fires on (default) database.
 * Updates totalRegistrations, earlyBirdCount, totalRegistrants in analytics/global.
 */
exports.onRegistrantCreate = functions.firestore
    .document("events/{eventId}/registrants/{registrantId}")
    .onCreate(async (snap, context) => {
    await handleRegistrantCreate(db, context.params.eventId, context.params.registrantId, snap.data());
    return null;
});
/**
 * onRegistrantCreateProd (v2): fires on event-hub-prod database.
 * Keeps analytics/global.totalRegistrants accurate in production.
 */
exports.onRegistrantCreateProd = (0, firestore_1.onDocumentCreated)({
    document: "events/{eventId}/registrants/{registrantId}",
    database: DB_PROD,
}, async (event) => {
    if (!event.data)
        return;
    const dbProd = (0, firestore_2.getFirestore)(DB_PROD);
    await handleRegistrantCreate(dbProd, event.params.eventId, event.params.registrantId, event.data.data());
});
/**
 * onRegistrantCreateDev (v2): fires on event-hub-dev database.
 */
exports.onRegistrantCreateDev = (0, firestore_1.onDocumentCreated)({
    document: "events/{eventId}/registrants/{registrantId}",
    database: DB_DEV,
}, async (event) => {
    if (!event.data)
        return;
    const dbDev = (0, firestore_2.getFirestore)(DB_DEV);
    await handleRegistrantCreate(dbDev, event.params.eventId, event.params.registrantId, event.data.data());
});
/**
 * Shared logic for attendance creation analytics update.
 * Called by v1 (default DB) and v2 (named DB) triggers.
 */
async function handleAttendanceCreate(targetDb, eventId, sessionId, registrantId, data) {
    var _a, _b;
    const checkedInAt = data === null || data === void 0 ? void 0 : data.checkedInAt;
    const ts = checkedInAt !== null && checkedInAt !== void 0 ? checkedInAt : admin.firestore.Timestamp.now();
    const registrantRef = targetDb.doc(`events/${eventId}/registrants/${registrantId}`);
    const registrantSnap = await registrantRef.get();
    const r = registrantSnap.data();
    const region = (_a = getString(r, "region", "regionMembership", "Region")) !== null && _a !== void 0 ? _a : "Unknown";
    const ministry = (_b = getString(r, "ministryMembership", "ministry", "Ministry")) !== null && _b !== void 0 ? _b : "Unknown";
    const statsRef = targetDb.doc(`events/${eventId}/stats/overview`);
    const globalAnalyticsRef = targetDb.doc(`events/${eventId}/analytics/global`);
    const sessionAnalyticsRef = targetDb.doc(`events/${eventId}/sessions/${sessionId}/analytics/summary`);
    const attendeeIndexRef = targetDb.doc(`events/${eventId}/attendeeIndex/${registrantId}`);
    await targetDb.runTransaction(async (tx) => {
        var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p, _q, _r, _s, _t;
        const attendeeIndexSnap = await tx.get(attendeeIndexRef);
        const isNewUniqueAttendee = !attendeeIndexSnap.exists;
        const globalSnap = await tx.get(globalAnalyticsRef);
        const global = (_a = globalSnap.data()) !== null && _a !== void 0 ? _a : {};
        const sessionSnap = await tx.get(sessionAnalyticsRef);
        const sessionData = (_b = sessionSnap.data()) !== null && _b !== void 0 ? _b : {};
        const regionKey = safe(region);
        const ministryKey = safe(ministry);
        const hourKey = quarterHourBucket(ts);
        const globalRegionCounts = Object.assign({}, (global.regionCounts || {}));
        const globalMinistryCounts = Object.assign({}, (global.ministryCounts || {}));
        const globalHourlyCheckins = Object.assign({}, (global.hourlyCheckins || {}));
        globalRegionCounts[regionKey] = ((_c = globalRegionCounts[regionKey]) !== null && _c !== void 0 ? _c : 0) + 1;
        globalMinistryCounts[ministryKey] = ((_d = globalMinistryCounts[ministryKey]) !== null && _d !== void 0 ? _d : 0) + 1;
        globalHourlyCheckins[hourKey] = ((_e = globalHourlyCheckins[hourKey]) !== null && _e !== void 0 ? _e : 0) + 1;
        const sessionRegionCounts = Object.assign({}, (sessionData.regionCounts || {}));
        const sessionMinistryCounts = Object.assign({}, (sessionData.ministryCounts || {}));
        sessionRegionCounts[regionKey] = ((_f = sessionRegionCounts[regionKey]) !== null && _f !== void 0 ? _f : 0) + 1;
        sessionMinistryCounts[ministryKey] = ((_g = sessionMinistryCounts[ministryKey]) !== null && _g !== void 0 ? _g : 0) + 1;
        const existingEarliest = global.earliestCheckin;
        const existingTs = (_m = (_l = (_k = (_j = (_h = existingEarliest === null || existingEarliest === void 0 ? void 0 : existingEarliest.timestamp) === null || _h === void 0 ? void 0 : _h.toDate) === null || _j === void 0 ? void 0 : _j.call(_h)) === null || _k === void 0 ? void 0 : _k.getTime) === null || _l === void 0 ? void 0 : _l.call(_k)) !== null && _m !== void 0 ? _m : Infinity;
        const newTs = (_r = (_q = (_p = (_o = ts.toDate) === null || _o === void 0 ? void 0 : _o.call(ts)) === null || _p === void 0 ? void 0 : _p.getTime) === null || _q === void 0 ? void 0 : _q.call(_p)) !== null && _r !== void 0 ? _r : 0;
        const shouldUpdateEarliest = newTs < existingTs || !existingEarliest;
        const globalUpdates = {
            totalCheckins: admin.firestore.FieldValue.increment(1),
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            regionCounts: globalRegionCounts,
            ministryCounts: globalMinistryCounts,
            hourlyCheckins: globalHourlyCheckins,
        };
        if (isNewUniqueAttendee) {
            globalUpdates.totalUniqueAttendees = admin.firestore.FieldValue.increment(1);
        }
        if (shouldUpdateEarliest) {
            globalUpdates.earliestCheckin = { registrantId, sessionId, timestamp: ts };
        }
        tx.set(globalAnalyticsRef, globalUpdates, { merge: true });
        tx.set(sessionAnalyticsRef, {
            attendanceCount: admin.firestore.FieldValue.increment(1),
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            regionCounts: sessionRegionCounts,
            ministryCounts: sessionMinistryCounts,
        }, { merge: true });
        if (isNewUniqueAttendee) {
            tx.set(attendeeIndexRef, { firstSession: sessionId, firstCheckinTime: ts });
        }
        const statsSnap = await tx.get(statsRef);
        const stats = (_s = statsSnap.data()) !== null && _s !== void 0 ? _s : {};
        const sessionTotals = Object.assign({}, (stats.sessionTotals || {}));
        const firstSessionCheckIn = Object.assign({}, (stats.firstSessionCheckIn || {}));
        const sk = safe(sessionId);
        sessionTotals[sk] = ((_t = sessionTotals[sk]) !== null && _t !== void 0 ? _t : 0) + 1;
        if (!firstSessionCheckIn[sk] && checkedInAt) {
            firstSessionCheckIn[sk] = { at: checkedInAt, registrantId };
        }
        tx.set(statsRef, {
            sessionTotals,
            firstSessionCheckIn,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    });
}
/**
 * onAttendanceCreate (v1): fires on (default) database only.
 * Pure Session Architecture: updates analytics/global (regionCounts, ministryCounts,
 * hourlyCheckins, totalCheckins) and session analytics/summary.
 */
exports.onAttendanceCreate = functions.firestore
    .document("events/{eventId}/sessions/{sessionId}/attendance/{registrantId}")
    .onCreate(async (snap, context) => {
    await handleAttendanceCreate(db, context.params.eventId, context.params.sessionId, context.params.registrantId, snap.data());
    return null;
});
/**
 * onAttendanceCreateProd (v2): fires on event-hub-prod database.
 * Keeps analytics/global real-time for the production app.
 */
exports.onAttendanceCreateProd = (0, firestore_1.onDocumentCreated)({
    document: "events/{eventId}/sessions/{sessionId}/attendance/{registrantId}",
    database: DB_PROD,
}, async (event) => {
    if (!event.data)
        return;
    const dbProd = (0, firestore_2.getFirestore)(DB_PROD);
    await handleAttendanceCreate(dbProd, event.params.eventId, event.params.sessionId, event.params.registrantId, event.data.data());
});
/**
 * onAttendanceCreateDev (v2): fires on event-hub-dev database.
 * Keeps analytics/global real-time for the dev app.
 */
exports.onAttendanceCreateDev = (0, firestore_1.onDocumentCreated)({
    document: "events/{eventId}/sessions/{sessionId}/attendance/{registrantId}",
    database: DB_DEV,
}, async (event) => {
    if (!event.data)
        return;
    const dbDev = (0, firestore_2.getFirestore)(DB_DEV);
    await handleAttendanceCreate(dbDev, event.params.eventId, event.params.sessionId, event.params.registrantId, event.data.data());
});
/** Callable: backfill stats doc. Admin only. */
exports.backfillStats = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Must be authenticated");
    }
    const eventId = data === null || data === void 0 ? void 0 : data.eventId;
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
exports.backfillAnalytics = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p, _q, _r, _s, _t, _u, _v, _w, _x, _y, _z, _0, _1, _2, _3, _4;
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Must be authenticated");
    }
    const eventId = data === null || data === void 0 ? void 0 : data.eventId;
    if (!eventId) {
        throw new functions.https.HttpsError("invalid-argument", "eventId required");
    }
    const email = (_b = (_a = context.auth) === null || _a === void 0 ? void 0 : _a.token) === null || _b === void 0 ? void 0 : _b.email;
    if (!email) {
        throw new functions.https.HttpsError("permission-denied", "No email");
    }
    const adminsRef = db.doc(`events/${eventId}/admins/${email}`);
    const adminSnap = await adminsRef.get();
    const isAdmin = adminSnap.exists && (((_c = adminSnap.data()) === null || _c === void 0 ? void 0 : _c.role) === "ADMIN" || ((_d = adminSnap.data()) === null || _d === void 0 ? void 0 : _d.role) === "STAFF");
    if (!isAdmin) {
        throw new functions.https.HttpsError("permission-denied", "Only admin can run backfillAnalytics");
    }
    const globalRegionCounts = {};
    const globalMinistryCounts = {};
    const globalHourlyCheckins = {};
    let earliestCheckin = null;
    const sessionData = {};
    const seenRegistrants = new Set();
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
            const checkedInAt = attData === null || attData === void 0 ? void 0 : attData.checkedInAt;
            const ts = checkedInAt !== null && checkedInAt !== void 0 ? checkedInAt : admin.firestore.Timestamp.now();
            const isNew = !seenRegistrants.has(registrantId);
            if (isNew)
                seenRegistrants.add(registrantId);
            sd.attendance++;
            const registrantSnap = await db.doc(`events/${eventId}/registrants/${registrantId}`).get();
            const r = registrantSnap.data();
            const region = (_e = getString(r, "region", "regionMembership", "Region")) !== null && _e !== void 0 ? _e : "Unknown";
            const ministry = (_f = getString(r, "ministryMembership", "ministry", "Ministry")) !== null && _f !== void 0 ? _f : "Unknown";
            const rk = safe(region);
            const mk = safe(ministry);
            const hk = quarterHourBucket(ts);
            globalRegionCounts[rk] = ((_g = globalRegionCounts[rk]) !== null && _g !== void 0 ? _g : 0) + 1;
            globalMinistryCounts[mk] = ((_h = globalMinistryCounts[mk]) !== null && _h !== void 0 ? _h : 0) + 1;
            globalHourlyCheckins[hk] = ((_j = globalHourlyCheckins[hk]) !== null && _j !== void 0 ? _j : 0) + 1;
            sd.regionCounts[rk] = ((_k = sd.regionCounts[rk]) !== null && _k !== void 0 ? _k : 0) + 1;
            sd.ministryCounts[mk] = ((_l = sd.ministryCounts[mk]) !== null && _l !== void 0 ? _l : 0) + 1;
            const existingTs = (_r = (_q = (_p = (_o = (_m = earliestCheckin === null || earliestCheckin === void 0 ? void 0 : earliestCheckin.timestamp) === null || _m === void 0 ? void 0 : _m.toDate) === null || _o === void 0 ? void 0 : _o.call(_m)) === null || _p === void 0 ? void 0 : _p.getTime) === null || _q === void 0 ? void 0 : _q.call(_p)) !== null && _r !== void 0 ? _r : Infinity;
            const newTs = (_v = (_u = (_t = (_s = ts.toDate) === null || _s === void 0 ? void 0 : _s.call(ts)) === null || _t === void 0 ? void 0 : _t.getTime) === null || _u === void 0 ? void 0 : _u.call(_t)) !== null && _v !== void 0 ? _v : 0;
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
    let earliestRegistration = null;
    const registrantsSnap = await db.collection(`events/${eventId}/registrants`).get();
    for (const doc of registrantsSnap.docs) {
        const regAt = getRegisteredAt(doc.data());
        if (regAt) {
            const existingTs = (_0 = (_z = (_y = (_x = (_w = earliestRegistration === null || earliestRegistration === void 0 ? void 0 : earliestRegistration.timestamp) === null || _w === void 0 ? void 0 : _w.toDate) === null || _x === void 0 ? void 0 : _x.call(_w)) === null || _y === void 0 ? void 0 : _y.getTime) === null || _z === void 0 ? void 0 : _z.call(_y)) !== null && _0 !== void 0 ? _0 : Infinity;
            const newTs = (_4 = (_3 = (_2 = (_1 = regAt.toDate) === null || _1 === void 0 ? void 0 : _1.call(regAt)) === null || _2 === void 0 ? void 0 : _2.getTime) === null || _3 === void 0 ? void 0 : _3.call(_2)) !== null && _4 !== void 0 ? _4 : 0;
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
        earliestCheckin: earliestCheckin !== null && earliestCheckin !== void 0 ? earliestCheckin : null,
        earliestRegistration: earliestRegistration !== null && earliestRegistration !== void 0 ? earliestRegistration : null,
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
__exportStar(require("./checkinAnalytics"), exports);
//# sourceMappingURL=index.js.map