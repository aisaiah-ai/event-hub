"use strict";
/**
 * Check-in service: main and session check-in, idempotent.
 * Uses existing: events/{eventId}/registrants/{registrantId} (eventAttendance.checkedInAt,
 * sessionsCheckedIn) and events/{eventId}/sessions/{sessionId}/attendance/{registrantId}.
 * Deterministic ids: main_${uid}, session_${sessionId}_${uid}.
 * Auto main check-in: if session check-in and main missing, create main first.
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
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkInMain = checkInMain;
exports.registerForSession = registerForSession;
exports.checkInSession = checkInSession;
exports.getCheckInStatus = getCheckInStatus;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("../utils/firestore");
const now_1 = require("../utils/now");
const errors_1 = require("../models/errors");
const SOURCE_APP = "app";
/** Build full profile from auth user + request body (CFC fields). */
function buildProfile(user, body) {
    var _a, _b, _c, _d, _e, _f, _g;
    const profile = {
        name: ((_a = body === null || body === void 0 ? void 0 : body.displayName) !== null && _a !== void 0 ? _a : body === null || body === void 0 ? void 0 : body.firstName)
            ? `${(_b = body === null || body === void 0 ? void 0 : body.firstName) !== null && _b !== void 0 ? _b : ""} ${(_c = body === null || body === void 0 ? void 0 : body.lastName) !== null && _c !== void 0 ? _c : ""}`.trim()
            : (_e = (_d = user.name) !== null && _d !== void 0 ? _d : user.email) !== null && _e !== void 0 ? _e : undefined,
        email: (_g = (_f = body === null || body === void 0 ? void 0 : body.email) !== null && _f !== void 0 ? _f : user.email) !== null && _g !== void 0 ? _g : undefined,
    };
    if (body === null || body === void 0 ? void 0 : body.firstName)
        profile.firstName = body.firstName;
    if (body === null || body === void 0 ? void 0 : body.lastName)
        profile.lastName = body.lastName;
    if (body === null || body === void 0 ? void 0 : body.memberId)
        profile.memberId = body.memberId;
    if (body === null || body === void 0 ? void 0 : body.role)
        profile.role = body.role;
    if (body === null || body === void 0 ? void 0 : body.service)
        profile.service = body.service;
    if (body === null || body === void 0 ? void 0 : body.chapter)
        profile.chapter = body.chapter;
    if (body === null || body === void 0 ? void 0 : body.gender)
        profile.gender = body.gender;
    if (body === null || body === void 0 ? void 0 : body.coupleCoordinator)
        profile.coupleCoordinator = body.coupleCoordinator;
    return profile;
}
/** Main check-in: set eventAttendance.checkedInAt on registrant. Idempotent. */
async function checkInMain(eventId, user, profileData) {
    const uid = user.uid;
    const eventSnap = await (0, firestore_1.eventRef)(eventId).get();
    if (!eventSnap.exists)
        throw (0, errors_1.notFound)("Event not found");
    const profile = buildProfile(user, profileData);
    const memberId = profileData === null || profileData === void 0 ? void 0 : profileData.memberId;
    return await admin.firestore().runTransaction(async (tx) => {
        var _a;
        // ── All reads first ──────────────────────────────────────────────
        // Find existing registrant by uid (works for any doc ID scheme)
        const existing = await (0, firestore_1.findRegistrantByUid)(eventId, uid, tx);
        // ── All writes after ─────────────────────────────────────────────
        if (!existing) {
            // Create new registrant — use memberId or generate ZZ ID
            let registrantId;
            if (memberId && memberId.trim().length > 0) {
                registrantId = memberId.trim();
            }
            else {
                registrantId = await (0, firestore_1.generateZzRegistrantId)(eventId, tx);
            }
            const regRef = (0, firestore_1.registrantRef)(eventId, registrantId);
            tx.set(regRef, {
                uid,
                registrantId,
                source: SOURCE_APP,
                registrationStatus: "registered",
                profile,
                eventAttendance: { checkedInAt: (0, now_1.serverTimestamp)(), checkedInBy: null },
                sessionsCheckedIn: {},
                createdAt: (0, now_1.serverTimestamp)(),
                updatedAt: (0, now_1.serverTimestamp)(),
            }, { merge: true });
            return { already: false };
        }
        const data = existing.data;
        const eventAttendance = (_a = data.eventAttendance) !== null && _a !== void 0 ? _a : {};
        const already = !!eventAttendance.checkedInAt;
        // Always update profile with latest data
        const updates = {
            profile,
            updatedAt: (0, now_1.serverTimestamp)(),
        };
        if (!already) {
            updates["eventAttendance.checkedInAt"] = (0, now_1.serverTimestamp)();
            updates["eventAttendance.checkedInBy"] = null;
        }
        tx.update(existing.ref, updates);
        return { already };
    });
}
/** Register for a session. Idempotent. Creates attendance doc with registeredAt but no checkedInAt.
 *  Also ensures event-level registrant doc exists. Doc ID = CFC memberId or ZZ9999-XXXXXX. */
async function registerForSession(eventId, sessionId, user, profileData) {
    const uid = user.uid;
    const eventSnap = await (0, firestore_1.eventRef)(eventId).get();
    if (!eventSnap.exists)
        throw (0, errors_1.notFound)("Event not found");
    const sessionSnap = await (0, firestore_1.sessionRef)(eventId, sessionId).get();
    if (!sessionSnap.exists)
        throw (0, errors_1.notFound)("Session not found");
    const profile = buildProfile(user, profileData);
    const memberId = profileData === null || profileData === void 0 ? void 0 : profileData.memberId;
    return await admin.firestore().runTransaction(async (tx) => {
        // ── All reads first ──────────────────────────────────────────────
        const existing = await (0, firestore_1.findRegistrantByUid)(eventId, uid, tx);
        let registrantId;
        let regRef;
        if (existing) {
            registrantId = existing.id;
            regRef = existing.ref;
        }
        else {
            if (memberId && memberId.trim().length > 0) {
                registrantId = memberId.trim();
            }
            else {
                registrantId = await (0, firestore_1.generateZzRegistrantId)(eventId, tx);
            }
            regRef = (0, firestore_1.registrantRef)(eventId, registrantId);
        }
        const attRef = (0, firestore_1.attendanceDocRef)(eventId, sessionId, registrantId);
        const attSnap = await tx.get(attRef);
        // ── All writes after ─────────────────────────────────────────────
        // Ensure event-level registrant doc exists
        if (!existing) {
            tx.set(regRef, {
                uid,
                registrantId,
                source: SOURCE_APP,
                registrationStatus: "registered",
                profile,
                sessionsRegistered: {},
                sessionsCheckedIn: {},
                createdAt: (0, now_1.serverTimestamp)(),
                updatedAt: (0, now_1.serverTimestamp)(),
            }, { merge: true });
        }
        else {
            tx.update(regRef, { profile, updatedAt: (0, now_1.serverTimestamp)() });
        }
        const already = attSnap.exists;
        if (!already) {
            tx.set(attRef, {
                uid,
                registrantId,
                type: "session",
                sessionId,
                profile,
                registeredAt: (0, now_1.serverTimestamp)(),
                checkedInAt: null,
                createdAt: (0, now_1.serverTimestamp)(),
                source: SOURCE_APP,
            });
            tx.update(regRef, {
                [`sessionsRegistered.${sessionId}`]: (0, now_1.serverTimestamp)(),
                updatedAt: (0, now_1.serverTimestamp)(),
            });
        }
        return { already };
    });
}
/** Session check-in. Idempotent. Requires session registration (attendance doc must exist).
 *  If main not checked in, do main first in same transaction. */
async function checkInSession(eventId, sessionId, user, profileData) {
    const uid = user.uid;
    const eventSnap = await (0, firestore_1.eventRef)(eventId).get();
    if (!eventSnap.exists)
        throw (0, errors_1.notFound)("Event not found");
    const sessionSnap = await (0, firestore_1.sessionRef)(eventId, sessionId).get();
    if (!sessionSnap.exists)
        throw (0, errors_1.notFound)("Session not found");
    const profile = buildProfile(user, profileData);
    return await admin.firestore().runTransaction(async (tx) => {
        var _a, _b;
        // ── All reads first ──────────────────────────────────────────────
        const existing = await (0, firestore_1.findRegistrantByUid)(eventId, uid, tx);
        if (!existing)
            throw (0, errors_1.notFound)("Not registered for this event");
        const registrantId = existing.id;
        const regRef = existing.ref;
        // Attendance doc uses registrant ID as key
        const attRef = (0, firestore_1.attendanceDocRef)(eventId, sessionId, registrantId);
        const attSnap = await tx.get(attRef);
        // Session must have registration (attendance doc with registeredAt)
        if (!attSnap.exists) {
            throw (0, errors_1.notFound)("Not registered for this session. Please register first.");
        }
        // ── All writes after ─────────────────────────────────────────────
        const attData = (_a = attSnap.data()) !== null && _a !== void 0 ? _a : {};
        const already = !!attData.checkedInAt;
        // Ensure main event check-in
        let mainCreated = false;
        const data = existing.data;
        const eventAttendance = (_b = data.eventAttendance) !== null && _b !== void 0 ? _b : {};
        if (!eventAttendance.checkedInAt) {
            tx.update(regRef, {
                "eventAttendance.checkedInAt": (0, now_1.serverTimestamp)(),
                "eventAttendance.checkedInBy": null,
                profile,
                updatedAt: (0, now_1.serverTimestamp)(),
            });
            mainCreated = true;
        }
        else {
            tx.update(regRef, { profile, updatedAt: (0, now_1.serverTimestamp)() });
        }
        if (!already) {
            tx.update(attRef, {
                checkedInAt: (0, now_1.serverTimestamp)(),
                profile,
            });
            tx.update(regRef, {
                [`sessionsCheckedIn.${sessionId}`]: (0, now_1.serverTimestamp)(),
                updatedAt: (0, now_1.serverTimestamp)(),
            });
        }
        return { mainCreated, already };
    });
}
/** Get check-in status for user at event. */
async function getCheckInStatus(eventId, user) {
    var _a, _b, _c, _d;
    const uid = user.uid;
    const eventSnap = await (0, firestore_1.eventRef)(eventId).get();
    if (!eventSnap.exists)
        throw (0, errors_1.notFound)("Event not found");
    // Find registrant by uid (works for memberId, ZZ ID, or legacy uid doc IDs)
    const found = await (0, firestore_1.findRegistrantByUid)(eventId, uid);
    const data = (_a = found === null || found === void 0 ? void 0 : found.data) !== null && _a !== void 0 ? _a : {};
    const eventAttendance = (_b = data.eventAttendance) !== null && _b !== void 0 ? _b : {};
    const sessionsCheckedIn = (_c = data.sessionsCheckedIn) !== null && _c !== void 0 ? _c : {};
    const sessionsRegistered = (_d = data.sessionsRegistered) !== null && _d !== void 0 ? _d : {};
    const mainCheckedInAt = eventAttendance.checkedInAt;
    return {
        eventId,
        mainCheckedIn: !!mainCheckedInAt,
        mainCheckedInAt: (0, now_1.timestampToIso)(mainCheckedInAt),
        sessionIds: Object.keys(sessionsCheckedIn),
        sessionRegisteredIds: Object.keys(sessionsRegistered),
    };
}
//# sourceMappingURL=checkin.service.js.map