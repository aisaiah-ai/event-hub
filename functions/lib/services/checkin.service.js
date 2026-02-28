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
exports.checkInSession = checkInSession;
exports.getCheckInStatus = getCheckInStatus;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("../utils/firestore");
const now_1 = require("../utils/now");
const errors_1 = require("../models/errors");
const SOURCE_APP = "app";
/** Ensure registrant doc exists (for app users it may be created on first check-in or register). */
async function ensureRegistrant(tx, eventId, uid, source) {
    const ref = (0, firestore_1.registrantRef)(eventId, uid);
    const snap = await tx.get(ref);
    if (!snap.exists) {
        tx.set(ref, {
            uid,
            source,
            registrationStatus: "registered",
            eventAttendance: {},
            sessionsCheckedIn: {},
            createdAt: (0, now_1.serverTimestamp)(),
            updatedAt: (0, now_1.serverTimestamp)(),
        }, { merge: true });
    }
}
/** Main check-in: set eventAttendance.checkedInAt on registrant. Idempotent. */
async function checkInMain(eventId, user) {
    const uid = user.uid;
    const eventSnap = await (0, firestore_1.eventRef)(eventId).get();
    if (!eventSnap.exists)
        throw (0, errors_1.notFound)("Event not found");
    return await admin.firestore().runTransaction(async (tx) => {
        var _a, _b;
        await ensureRegistrant(tx, eventId, uid, SOURCE_APP);
        const regRef = (0, firestore_1.registrantRef)(eventId, uid);
        const regSnap = await tx.get(regRef);
        const data = (_a = regSnap.data()) !== null && _a !== void 0 ? _a : {};
        const eventAttendance = (_b = data.eventAttendance) !== null && _b !== void 0 ? _b : {};
        const already = !!eventAttendance.checkedInAt;
        if (!already) {
            tx.update(regRef, {
                "eventAttendance.checkedInAt": (0, now_1.serverTimestamp)(),
                "eventAttendance.checkedInBy": null,
                updatedAt: (0, now_1.serverTimestamp)(),
            });
        }
        return { already };
    });
}
/** Session check-in. Idempotent. If main not checked in, do main first in same transaction. */
async function checkInSession(eventId, sessionId, user) {
    const uid = user.uid;
    const eventSnap = await (0, firestore_1.eventRef)(eventId).get();
    if (!eventSnap.exists)
        throw (0, errors_1.notFound)("Event not found");
    const sessionSnap = await (0, firestore_1.sessionRef)(eventId, sessionId).get();
    if (!sessionSnap.exists)
        throw (0, errors_1.notFound)("Session not found");
    return await admin.firestore().runTransaction(async (tx) => {
        var _a, _b;
        await ensureRegistrant(tx, eventId, uid, SOURCE_APP);
        const regRef = (0, firestore_1.registrantRef)(eventId, uid);
        const regSnap = await tx.get(regRef);
        const data = (_a = regSnap.data()) !== null && _a !== void 0 ? _a : {};
        const eventAttendance = (_b = data.eventAttendance) !== null && _b !== void 0 ? _b : {};
        let mainCreated = false;
        if (!eventAttendance.checkedInAt) {
            tx.update(regRef, {
                "eventAttendance.checkedInAt": (0, now_1.serverTimestamp)(),
                "eventAttendance.checkedInBy": null,
                updatedAt: (0, now_1.serverTimestamp)(),
            });
            mainCreated = true;
        }
        const attRef = (0, firestore_1.attendanceDocRef)(eventId, sessionId, uid);
        const attSnap = await tx.get(attRef);
        const already = attSnap.exists;
        if (!already) {
            tx.set(attRef, {
                uid,
                type: "session",
                sessionId,
                createdAt: (0, now_1.serverTimestamp)(),
                source: SOURCE_APP,
                checkedInAt: (0, now_1.serverTimestamp)(),
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
    var _a, _b, _c;
    const uid = user.uid;
    const eventSnap = await (0, firestore_1.eventRef)(eventId).get();
    if (!eventSnap.exists)
        throw (0, errors_1.notFound)("Event not found");
    const regSnap = await (0, firestore_1.registrantRef)(eventId, uid).get();
    const data = (_a = regSnap.data()) !== null && _a !== void 0 ? _a : {};
    const eventAttendance = (_b = data.eventAttendance) !== null && _b !== void 0 ? _b : {};
    const sessionsCheckedIn = (_c = data.sessionsCheckedIn) !== null && _c !== void 0 ? _c : {};
    const mainCheckedInAt = eventAttendance.checkedInAt;
    return {
        eventId,
        mainCheckedIn: !!mainCheckedInAt,
        mainCheckedInAt: (0, now_1.timestampToIso)(mainCheckedInAt),
        sessionIds: Object.keys(sessionsCheckedIn),
    };
}
//# sourceMappingURL=checkin.service.js.map