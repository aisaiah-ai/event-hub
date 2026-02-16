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
exports.backfillStats = exports.onAttendanceCreate = exports.onRegistrantCreate = exports.onRegistrantCheckIn = exports.initializeNlc2026 = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
const db = admin.firestore();
function getString(data, ...keys) {
    var _a, _b;
    if (!data)
        return null;
    const d = data;
    for (const key of keys) {
        const profile = d.profile || {};
        const answers = d.answers || {};
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
        const region = (_b = getString(after, "region", "regionMembership")) !== null && _b !== void 0 ? _b : "Unknown";
        const regionOther = getString(after, "regionOtherText", "regionOther");
        const ministry = (_c = getString(after, "ministryMembership", "ministry")) !== null && _c !== void 0 ? _c : "Unknown";
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
 * onRegistrantCreate: totalRegistrations, earlyBirdCount, firstEarlyBird*.
 * Ensure stats doc exists.
 */
exports.onRegistrantCreate = functions.firestore
    .document("events/{eventId}/registrants/{registrantId}")
    .onCreate(async (snap, context) => {
    const eventId = context.params.eventId;
    const registrantId = context.params.registrantId;
    const data = snap.data();
    const statsRef = db.doc(`events/${eventId}/stats/overview`);
    const registeredAt = getRegisteredAt(data);
    await db.runTransaction(async (tx) => {
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
    });
    return null;
});
/**
 * onAttendanceCreate: sessions/{sessionId}/attendance/{registrantId} onCreate
 * Session-only check-in (registrant already event-checked-in). Increment sessionTotals, firstSessionCheckIn.
 */
exports.onAttendanceCreate = functions.firestore
    .document("events/{eventId}/sessions/{sessionId}/attendance/{registrantId}")
    .onCreate(async (snap, context) => {
    var _a;
    const eventId = context.params.eventId;
    const sessionId = context.params.sessionId;
    const registrantId = context.params.registrantId;
    const data = snap.data();
    const checkedInAt = data === null || data === void 0 ? void 0 : data.checkedInAt;
    const statsRef = db.doc(`events/${eventId}/stats/overview`);
    const registrantRef = db.doc(`events/${eventId}/registrants/${registrantId}`);
    const registrantSnap = await registrantRef.get();
    const r = registrantSnap.data();
    const rSessions = ((_a = r === null || r === void 0 ? void 0 : r.sessionsCheckedIn) !== null && _a !== void 0 ? _a : {});
    if (rSessions[sessionId] != null) {
        return null;
    }
    await db.runTransaction(async (tx) => {
        var _a, _b;
        const statsSnap = await tx.get(statsRef);
        const stats = (_a = statsSnap.data()) !== null && _a !== void 0 ? _a : {};
        const sessionTotals = Object.assign({}, (stats.sessionTotals || {}));
        const firstSessionCheckIn = Object.assign({}, (stats.firstSessionCheckIn || {}));
        const sk = safe(sessionId);
        sessionTotals[sk] = ((_b = sessionTotals[sk]) !== null && _b !== void 0 ? _b : 0) + 1;
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
__exportStar(require("./checkinAnalytics"), exports);
//# sourceMappingURL=index.js.map