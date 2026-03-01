"use strict";
/**
 * Speakers service: list and get speaker by id for an event.
 * Reads from events/{eventId}/speakers/{speakerId}.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.listSpeakers = listSpeakers;
exports.getSpeaker = getSpeaker;
const firestore_1 = require("../utils/firestore");
const errors_1 = require("../models/errors");
function toSpeakerDto(doc) {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p, _q, _r, _s, _t, _u;
    const d = (_a = doc.data()) !== null && _a !== void 0 ? _a : {};
    const topicsRaw = d.topics;
    const topics = Array.isArray(topicsRaw)
        ? topicsRaw.filter((t) => typeof t === "string")
        : [];
    return {
        id: doc.id,
        fullName: (_c = (_b = d.fullName) !== null && _b !== void 0 ? _b : d.name) !== null && _c !== void 0 ? _c : "",
        displayName: (_e = (_d = d.displayName) !== null && _d !== void 0 ? _d : d.name) !== null && _e !== void 0 ? _e : null,
        title: (_f = d.title) !== null && _f !== void 0 ? _f : null,
        cluster: (_g = d.cluster) !== null && _g !== void 0 ? _g : null,
        photoUrl: (_h = d.photoUrl) !== null && _h !== void 0 ? _h : null,
        bio: (_j = d.bio) !== null && _j !== void 0 ? _j : null,
        yearsInCfc: (_k = d.yearsInCfc) !== null && _k !== void 0 ? _k : null,
        familiesMentored: (_l = d.familiesMentored) !== null && _l !== void 0 ? _l : null,
        talksGiven: (_m = d.talksGiven) !== null && _m !== void 0 ? _m : null,
        location: (_o = d.location) !== null && _o !== void 0 ? _o : null,
        topics,
        quote: (_p = d.quote) !== null && _p !== void 0 ? _p : null,
        email: (_q = d.email) !== null && _q !== void 0 ? _q : null,
        phone: (_r = d.phone) !== null && _r !== void 0 ? _r : null,
        facebookUrl: (_s = d.facebookUrl) !== null && _s !== void 0 ? _s : null,
        order: (_t = d.order) !== null && _t !== void 0 ? _t : null,
        sessionId: (_u = d.sessionId) !== null && _u !== void 0 ? _u : null,
    };
}
async function listSpeakers(eventId) {
    const eventSnap = await (0, firestore_1.eventRef)(eventId).get();
    if (!eventSnap.exists) {
        throw (0, errors_1.notFound)("Event not found");
    }
    const snap = await (0, firestore_1.speakersRef)(eventId).get();
    const list = snap.docs.map((doc) => toSpeakerDto(doc));
    list.sort((a, b) => { var _a, _b; return ((_a = a.order) !== null && _a !== void 0 ? _a : 999) - ((_b = b.order) !== null && _b !== void 0 ? _b : 999); });
    return list;
}
async function getSpeaker(eventId, speakerId) {
    const eventSnap = await (0, firestore_1.eventRef)(eventId).get();
    if (!eventSnap.exists) {
        throw (0, errors_1.notFound)("Event not found");
    }
    const doc = await (0, firestore_1.speakerRef)(eventId, speakerId).get();
    if (!doc.exists) {
        throw (0, errors_1.notFound)("Speaker not found");
    }
    return toSpeakerDto(doc);
}
//# sourceMappingURL=speakers.service.js.map