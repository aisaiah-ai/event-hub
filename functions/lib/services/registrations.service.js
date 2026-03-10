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
exports.checkRegisteredMembers = checkRegisteredMembers;
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
    const additionalRegistrants = data.additionalRegistrants;
    return Object.assign({ eventId,
        registrationId, status: (_b = (_a = data.registrationStatus) !== null && _a !== void 0 ? _a : data.status) !== null && _b !== void 0 ? _b : "registered", createdAt: (_c = (0, now_1.timestampToIso)(createdAt)) !== null && _c !== void 0 ? _c : new Date(0).toISOString(), eventStartAt, profile: profile
            ? {
                name: (_e = (_d = profile.name) !== null && _d !== void 0 ? _d : profile.displayName) !== null && _e !== void 0 ? _e : undefined,
                email: profile.email,
            }
            : undefined }, (additionalRegistrants && additionalRegistrants.length > 0 ? { additionalRegistrants } : {}));
}
/**
 * Validate and filter additional registrants against event registration settings.
 * - Filters out guest entries if allowGuests is false.
 * - Filters out spouse entries if allowSpouse is explicitly false.
 * - Caps guest entries at registrationSettings.maxGuests (default 5).
 * - Allows at most 1 spouse entry.
 */
function validateAdditionalRegistrants(raw, eventData) {
    var _a;
    const settings = ((_a = eventData.registrationSettings) !== null && _a !== void 0 ? _a : {});
    const allowGuests = settings.allowGuests !== false; // default true
    const allowSpouse = settings.allowSpouse !== false; // default true
    const maxGuests = typeof settings.maxGuests === "number" ? settings.maxGuests : 5;
    const result = [];
    let spouseCount = 0;
    let guestCount = 0;
    for (const entry of raw) {
        const type = entry.type;
        const firstName = entry.firstName;
        if (!firstName || typeof firstName !== "string" || firstName.trim().length === 0)
            continue;
        if (type !== "spouse" && type !== "guest" && type !== "family")
            continue;
        if (type === "spouse") {
            if (!allowSpouse)
                continue;
            if (spouseCount >= 1)
                continue; // max 1 spouse
            spouseCount++;
        }
        else if (type === "family") {
            // Family members (CFC members with memberId) — always allowed
        }
        else {
            if (!allowGuests)
                continue;
            if (guestCount >= maxGuests)
                continue;
            guestCount++;
        }
        const dto = {
            type,
            firstName: firstName.trim(),
        };
        const lastName = entry.lastName;
        if (lastName && typeof lastName === "string" && lastName.trim().length > 0) {
            dto.lastName = lastName.trim();
        }
        const memberId = entry.memberId;
        if (memberId && typeof memberId === "string" && memberId.trim().length > 0) {
            dto.memberId = memberId.trim();
        }
        const count = entry.count;
        if (typeof count === "number" && count > 0) {
            dto.count = count;
        }
        result.push(dto);
    }
    return result;
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
        var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p, _q, _r;
        // ── All reads first ──────────────────────────────────────────────
        const eventStartAt = (_d = (_c = (_b = (_a = eventData.startAt) === null || _a === void 0 ? void 0 : _a.toDate) === null || _b === void 0 ? void 0 : _b.call(_a)) === null || _c === void 0 ? void 0 : _c.toISOString) === null || _d === void 0 ? void 0 : _d.call(_c);
        // Check if user already registered (by uid field, works for any doc ID)
        const existing = await (0, firestore_1.findRegistrantByUid)(eventId, uid, tx);
        if (existing) {
            const status = (_f = (_e = existing.data.registrationStatus) !== null && _e !== void 0 ? _e : existing.data.status) !== null && _f !== void 0 ? _f : "registered";
            if (status === "registered") {
                // Allow updating additional registrants on an existing registration
                const incomingAdditional = rsvpData === null || rsvpData === void 0 ? void 0 : rsvpData.additionalRegistrants;
                if (incomingAdditional && Array.isArray(incomingAdditional)) {
                    const validated = validateAdditionalRegistrants(incomingAdditional, eventData);
                    if (validated.length > 0 || ((_g = existing.data.additionalRegistrants) !== null && _g !== void 0 ? _g : []).length > 0) {
                        const now = (0, now_1.serverTimestamp)();
                        tx.update((0, firestore_1.registrantRef)(eventId, existing.id), { additionalRegistrants: validated, updatedAt: now });
                        tx.update((0, firestore_1.userRegistrationRef)(uid, eventId), { additionalRegistrants: validated });
                    }
                    return toRegistrationDto(eventId, existing.id, Object.assign(Object.assign({}, existing.data), { additionalRegistrants: validated }), eventStartAt);
                }
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
        // Validate additional registrants (spouse / guest) — needed for reads below
        const incomingAdditional = rsvpData === null || rsvpData === void 0 ? void 0 : rsvpData.additionalRegistrants;
        const additionalRegistrants = incomingAdditional && Array.isArray(incomingAdditional)
            ? validateAdditionalRegistrants(incomingAdditional, eventData)
            : [];
        // ── Read existing registrant docs for spouse/family BEFORE any writes ──
        const arExistingDocs = new Map();
        for (const ar of additionalRegistrants) {
            if (!ar.memberId || ar.type === "guest")
                continue;
            const arDoc = await tx.get((0, firestore_1.registrantRef)(eventId, ar.memberId));
            arExistingDocs.set(ar.memberId, arDoc.exists);
        }
        // ── All writes after ─────────────────────────────────────────────
        const now = (0, now_1.serverTimestamp)();
        const profile = {
            name: ((_h = rsvpData === null || rsvpData === void 0 ? void 0 : rsvpData.displayName) !== null && _h !== void 0 ? _h : rsvpData === null || rsvpData === void 0 ? void 0 : rsvpData.firstName)
                ? `${(_j = rsvpData.firstName) !== null && _j !== void 0 ? _j : ""} ${(_k = rsvpData.lastName) !== null && _k !== void 0 ? _k : ""}`.trim()
                : (_m = (_l = user.name) !== null && _l !== void 0 ? _l : user.email) !== null && _m !== void 0 ? _m : undefined,
            email: (_p = (_o = rsvpData === null || rsvpData === void 0 ? void 0 : rsvpData.email) !== null && _o !== void 0 ? _o : user.email) !== null && _p !== void 0 ? _p : undefined,
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
        const additionalGuestsCount = typeof (rsvpData === null || rsvpData === void 0 ? void 0 : rsvpData.additionalGuests) === "number" ? rsvpData.additionalGuests : 0;
        const regRef = (0, firestore_1.registrantRef)(eventId, registrantId);
        tx.set(regRef, Object.assign(Object.assign({ uid,
            registrantId, registrationStatus: "registered", status: "registered", createdAt: now, updatedAt: now, profile, source: "app" }, (additionalRegistrants.length > 0 ? { additionalRegistrants } : {})), (additionalGuestsCount > 0 ? { additionalGuests: additionalGuestsCount } : {})), { merge: true });
        const mirrorRef = (0, firestore_1.userRegistrationRef)(uid, eventId);
        tx.set(mirrorRef, Object.assign(Object.assign({ eventId, registrationId: registrantId, registrantId, status: "registered", createdAt: now, eventStartAt: (_q = eventData.startAt) !== null && _q !== void 0 ? _q : null }, (additionalRegistrants.length > 0 ? { additionalRegistrants } : {})), (additionalGuestsCount > 0 ? { additionalGuests: additionalGuestsCount } : {})), { merge: true });
        // ── Create individual registrant docs for spouse/family with memberIds ──
        // This allows them to see "Registered" when they open the app.
        for (const ar of additionalRegistrants) {
            if (!ar.memberId || ar.type === "guest")
                continue;
            const arMemberId = ar.memberId;
            // Skip if already registered (read was done above, before writes)
            if (arExistingDocs.get(arMemberId))
                continue;
            const arProfile = {
                name: `${ar.firstName} ${(_r = ar.lastName) !== null && _r !== void 0 ? _r : ""}`.trim(),
                firstName: ar.firstName,
                memberId: arMemberId,
            };
            if (ar.lastName)
                arProfile.lastName = ar.lastName;
            tx.set((0, firestore_1.registrantRef)(eventId, arMemberId), {
                registrantId: arMemberId,
                registrationStatus: "registered",
                status: "registered",
                registeredBy: registrantId, // link back to the primary registrant
                registeredByUid: uid,
                registrationType: ar.type, // "spouse" or "family"
                createdAt: now,
                updatedAt: now,
                profile: arProfile,
                source: "app",
            }, { merge: true });
        }
        return Object.assign({ eventId, registrationId: registrantId, status: "registered", createdAt: new Date().toISOString(), eventStartAt,
            profile }, (additionalRegistrants.length > 0 ? { additionalRegistrants } : {}));
    });
}
/**
 * Check which memberIds already have a registrant doc for this event.
 * Used by the registration form to show "already registered" badges.
 */
async function checkRegisteredMembers(eventId, memberIds) {
    var _a, _b, _c;
    const registered = [];
    // Batch check: each memberId is a potential doc ID in registrants
    for (const mid of memberIds) {
        const doc = await (0, firestore_1.registrantRef)(eventId, mid).get();
        if (doc.exists) {
            const status = (_b = (_a = doc.data()) === null || _a === void 0 ? void 0 : _a.registrationStatus) !== null && _b !== void 0 ? _b : (_c = doc.data()) === null || _c === void 0 ? void 0 : _c.status;
            if (status === "registered") {
                registered.push(mid);
            }
        }
    }
    // Also check additionalRegistrants arrays for memberIds
    // (for registrations that happened before this fix was deployed)
    if (registered.length < memberIds.length) {
        const remaining = memberIds.filter((id) => !registered.includes(id));
        if (remaining.length > 0) {
            const allRegs = await (0, firestore_1.registrantsRef)(eventId).get();
            for (const doc of allRegs.docs) {
                const data = doc.data();
                const additional = data.additionalRegistrants;
                if (!additional)
                    continue;
                for (const ar of additional) {
                    const arMemberId = ar.memberId;
                    if (arMemberId && remaining.includes(arMemberId) && !registered.includes(arMemberId)) {
                        registered.push(arMemberId);
                    }
                }
            }
        }
    }
    return registered;
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
async function getMyRegistration(eventId, user, memberId) {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p, _q, _r, _s, _t, _u, _v, _w, _x, _y;
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
    // Fallback: check by memberId (for spouse/family registered by someone else)
    if (memberId) {
        const memberDoc = await (0, firestore_1.registrantRef)(eventId, memberId).get();
        if (memberDoc.exists) {
            const data = (_f = memberDoc.data()) !== null && _f !== void 0 ? _f : {};
            const status = (_g = data.registrationStatus) !== null && _g !== void 0 ? _g : data.status;
            if (status === "registered") {
                const eventSnap = await (0, firestore_1.eventRef)(eventId).get();
                const eventStartAt = eventSnap.exists
                    ? (_m = (_l = (_k = (_j = (_h = eventSnap.data()) === null || _h === void 0 ? void 0 : _h.startAt) === null || _j === void 0 ? void 0 : _j.toDate) === null || _k === void 0 ? void 0 : _k.call(_j)) === null || _l === void 0 ? void 0 : _l.toISOString) === null || _m === void 0 ? void 0 : _m.call(_l)
                    : undefined;
                // Link this registrant doc to the user's UID for future lookups
                if (!data.uid) {
                    await memberDoc.ref.update({ uid });
                    // Also create mirror doc
                    await (0, firestore_1.userRegistrationRef)(uid, eventId).set({
                        eventId,
                        registrationId: memberId,
                        registrantId: memberId,
                        status: "registered",
                        createdAt: (_o = data.createdAt) !== null && _o !== void 0 ? _o : (0, now_1.serverTimestamp)(),
                        eventStartAt: (_q = (_p = eventSnap.data()) === null || _p === void 0 ? void 0 : _p.startAt) !== null && _q !== void 0 ? _q : null,
                    }, { merge: true });
                }
                return toRegistrationDto(eventId, memberId, data, eventStartAt);
            }
        }
    }
    // Fallback: check mirror doc
    const mirrorDoc = await (0, firestore_1.userRegistrationRef)(uid, eventId).get();
    if (!mirrorDoc.exists)
        return null;
    const data = (_r = mirrorDoc.data()) !== null && _r !== void 0 ? _r : {};
    const eventSnap = await (0, firestore_1.eventRef)(eventId).get();
    const eventStartAt = eventSnap.exists
        ? (_w = (_v = (_u = (_t = (_s = eventSnap.data()) === null || _s === void 0 ? void 0 : _s.startAt) === null || _t === void 0 ? void 0 : _t.toDate) === null || _u === void 0 ? void 0 : _u.call(_t)) === null || _v === void 0 ? void 0 : _v.toISOString) === null || _w === void 0 ? void 0 : _w.call(_v)
        : undefined;
    return toRegistrationDto(eventId, (_y = (_x = data.registrationId) !== null && _x !== void 0 ? _x : data.registrantId) !== null && _y !== void 0 ? _y : eventId, data, eventStartAt);
}
//# sourceMappingURL=registrations.service.js.map