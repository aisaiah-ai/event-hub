"use strict";
/**
 * Registrations service: register, my registrations, my registration for event.
 * Uses events/{eventId}/registrants (registrantId = uid for app registrations) and
 * users/{uid}/registrations/{eventId} mirror for fast "my registrations".
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
exports.register = register;
exports.listMyRegistrations = listMyRegistrations;
exports.getMyRegistration = getMyRegistration;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("../utils/firestore");
const now_1 = require("../utils/now");
const errors_1 = require("../models/errors");
function toRegistrationDto(eventId, registrationId, data, eventStartAt) {
    var _a, _b, _c, _d, _e;
    const createdAt = data.createdAt;
    const profile = data.profile;
    return {
        eventId,
        registrationId,
        status: (_b = (_a = data.registrationStatus) !== null && _a !== void 0 ? _a : data.status) !== null && _b !== void 0 ? _b : "registered",
        createdAt: (_c = (0, now_1.timestampToIso)(createdAt)) !== null && _c !== void 0 ? _c : new Date(0).toISOString(),
        eventStartAt,
        profile: profile
            ? {
                name: (_e = (_d = profile.name) !== null && _d !== void 0 ? _d : profile.displayName) !== null && _e !== void 0 ? _e : undefined,
                email: profile.email,
            }
            : undefined,
    };
}
/** Register current user for event. Idempotent; one registration per uid per event. */
async function register(eventId, user, rsvpData) {
    var _a, _b;
    const uid = user.uid;
    const eventSnap = await (0, firestore_1.eventRef)(eventId).get();
    if (!eventSnap.exists) {
        throw (0, errors_1.notFound)("Event not found");
    }
    const eventData = (_a = eventSnap.data()) !== null && _a !== void 0 ? _a : {};
    const capacity = (_b = eventData.registrationSettings) === null || _b === void 0 ? void 0 : _b.capacity;
    // Determine registrant doc ID: CFC memberId if available, else ZZ9999-XXXXXX
    const memberId = rsvpData === null || rsvpData === void 0 ? void 0 : rsvpData.memberId;
    return await admin.firestore().runTransaction(async (tx) => {
        var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p;
        // ── All reads first ──────────────────────────────────────────────
        const eventStartAt = (_d = (_c = (_b = (_a = eventData.startAt) === null || _a === void 0 ? void 0 : _a.toDate) === null || _b === void 0 ? void 0 : _b.call(_a)) === null || _c === void 0 ? void 0 : _c.toISOString) === null || _d === void 0 ? void 0 : _d.call(_c);
        // Check if user already registered (by uid field, works for any doc ID)
        const existing = await (0, firestore_1.findRegistrantByUid)(eventId, uid, tx);
        if (existing) {
            const status = (_f = (_e = existing.data.registrationStatus) !== null && _e !== void 0 ? _e : existing.data.status) !== null && _f !== void 0 ? _f : "registered";
            if (status === "registered") {
                return toRegistrationDto(eventId, existing.id, existing.data, eventStartAt);
            }
            // was canceled — re-register with same doc ID below
        }
        // Determine the registrant ID
        let registrantId;
        if (existing) {
            registrantId = existing.id; // keep existing doc ID for re-registration
        }
        else if (memberId && memberId.trim().length > 0) {
            registrantId = memberId.trim();
        }
        else {
            registrantId = await (0, firestore_1.generateZzRegistrantId)(eventId, tx);
        }
        if (typeof capacity === "number" && capacity > 0) {
            const countSnap = await tx.get((0, firestore_1.registrantsRef)(eventId).limit(capacity + 1));
            const activeCount = countSnap.docs.filter((doc) => {
                var _a;
                const s = (_a = doc.data().registrationStatus) !== null && _a !== void 0 ? _a : doc.data().status;
                return s !== "canceled";
            }).length;
            if (activeCount >= capacity) {
                throw (0, errors_1.capacityExceeded)("Event is at capacity");
            }
        }
        // ── All writes after ─────────────────────────────────────────────
        const now = (0, now_1.serverTimestamp)();
        const profile = {
            name: ((_g = rsvpData === null || rsvpData === void 0 ? void 0 : rsvpData.displayName) !== null && _g !== void 0 ? _g : rsvpData === null || rsvpData === void 0 ? void 0 : rsvpData.firstName)
                ? `${(_h = rsvpData.firstName) !== null && _h !== void 0 ? _h : ""} ${(_j = rsvpData.lastName) !== null && _j !== void 0 ? _j : ""}`.trim()
                : (_l = (_k = user.name) !== null && _k !== void 0 ? _k : user.email) !== null && _l !== void 0 ? _l : undefined,
            email: (_o = (_m = rsvpData === null || rsvpData === void 0 ? void 0 : rsvpData.email) !== null && _m !== void 0 ? _m : user.email) !== null && _o !== void 0 ? _o : undefined,
        };
        // Include CFC fields when available
        if (rsvpData === null || rsvpData === void 0 ? void 0 : rsvpData.firstName)
            profile.firstName = rsvpData.firstName;
        if (rsvpData === null || rsvpData === void 0 ? void 0 : rsvpData.lastName)
            profile.lastName = rsvpData.lastName;
        if (memberId)
            profile.memberId = memberId;
        if (rsvpData === null || rsvpData === void 0 ? void 0 : rsvpData.role)
            profile.role = rsvpData.role;
        if (rsvpData === null || rsvpData === void 0 ? void 0 : rsvpData.service)
            profile.service = rsvpData.service;
        if (rsvpData === null || rsvpData === void 0 ? void 0 : rsvpData.chapter)
            profile.chapter = rsvpData.chapter;
        if (rsvpData === null || rsvpData === void 0 ? void 0 : rsvpData.gender)
            profile.gender = rsvpData.gender;
        const regRef = (0, firestore_1.registrantRef)(eventId, registrantId);
        tx.set(regRef, {
            uid,
            registrantId,
            registrationStatus: "registered",
            status: "registered",
            createdAt: now,
            updatedAt: now,
            profile,
            source: "app",
        }, { merge: true });
        const mirrorRef = (0, firestore_1.userRegistrationRef)(uid, eventId);
        tx.set(mirrorRef, {
            eventId,
            registrationId: registrantId,
            registrantId,
            status: "registered",
            createdAt: now,
            eventStartAt: (_p = eventData.startAt) !== null && _p !== void 0 ? _p : null,
        }, { merge: true });
        return {
            eventId,
            registrationId: registrantId,
            status: "registered",
            createdAt: new Date().toISOString(),
            eventStartAt,
            profile,
        };
    });
}
/** List my registrations (from mirror users/{uid}/registrations). */
async function listMyRegistrations(user) {
    var _a, _b, _c, _d, _e, _f;
    const snap = await (0, firestore_1.userRegistrationsRef)(user.uid).get();
    const list = [];
    for (const doc of snap.docs) {
        const data = doc.data();
        const eventId = doc.id;
        const eventSnap = await (0, firestore_1.eventRef)(eventId).get();
        const eventStartAt = eventSnap.exists
            ? (_e = (_d = (_c = (_b = (_a = eventSnap.data()) === null || _a === void 0 ? void 0 : _a.startAt) === null || _b === void 0 ? void 0 : _b.toDate) === null || _c === void 0 ? void 0 : _c.call(_b)) === null || _d === void 0 ? void 0 : _d.toISOString) === null || _e === void 0 ? void 0 : _e.call(_d)
            : undefined;
        list.push(toRegistrationDto(eventId, (_f = data.registrationId) !== null && _f !== void 0 ? _f : eventId, data, eventStartAt));
    }
    list.sort((a, b) => { var _a, _b; return ((_a = b.eventStartAt) !== null && _a !== void 0 ? _a : "").localeCompare((_b = a.eventStartAt) !== null && _b !== void 0 ? _b : ""); });
    return list;
}
/** Get my registration for a single event. */
async function getMyRegistration(eventId, user) {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o;
    const uid = user.uid;
    // Look up registrant by uid field (works for memberId, ZZ ID, or legacy uid doc IDs)
    const found = await (0, firestore_1.findRegistrantByUid)(eventId, uid);
    if (found) {
        const eventSnap = await (0, firestore_1.eventRef)(eventId).get();
        const eventStartAt = eventSnap.exists
            ? (_e = (_d = (_c = (_b = (_a = eventSnap.data()) === null || _a === void 0 ? void 0 : _a.startAt) === null || _b === void 0 ? void 0 : _b.toDate) === null || _c === void 0 ? void 0 : _c.call(_b)) === null || _d === void 0 ? void 0 : _d.toISOString) === null || _e === void 0 ? void 0 : _e.call(_d)
            : undefined;
        return toRegistrationDto(eventId, found.id, found.data, eventStartAt);
    }
    // Fallback: check mirror doc
    const mirrorDoc = await (0, firestore_1.userRegistrationRef)(uid, eventId).get();
    if (!mirrorDoc.exists)
        return null;
    const data = (_f = mirrorDoc.data()) !== null && _f !== void 0 ? _f : {};
    const eventSnap = await (0, firestore_1.eventRef)(eventId).get();
    const eventStartAt = eventSnap.exists
        ? (_l = (_k = (_j = (_h = (_g = eventSnap.data()) === null || _g === void 0 ? void 0 : _g.startAt) === null || _h === void 0 ? void 0 : _h.toDate) === null || _j === void 0 ? void 0 : _j.call(_h)) === null || _k === void 0 ? void 0 : _k.toISOString) === null || _l === void 0 ? void 0 : _l.call(_k)
        : undefined;
    return toRegistrationDto(eventId, (_o = (_m = data.registrationId) !== null && _m !== void 0 ? _m : data.registrantId) !== null && _o !== void 0 ? _o : eventId, data, eventStartAt);
}
//# sourceMappingURL=registrations.service.js.map