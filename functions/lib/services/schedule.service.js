"use strict";
/**
 * Schedule / sessions service: list sessions for an event, ordered by start time.
 *
 * Speaker resolution order per session:
 *  1. d.speakerIds[0]  (array of speaker document IDs → look up speakers subcollection)
 *                       speakerId is ALWAYS set from speakerIds[0] when present.
 *  2. d.speaker / d.speakerName  (plain-text fallback when no speakerIds array exists)
 *                                 speakerId is null in this case.
 *
 * speakerId enables deterministic client-side profile resolution via:
 *   GET /v1/events/:eventId/speakers/:speakerId
 * // NOTE: speakerId enables deterministic client-side profile resolution.
 * // Do not remove without coordinating mobile clients.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.listSessions = listSessions;
const firestore_1 = require("../utils/firestore");
const now_1 = require("../utils/now");
const errors_1 = require("../models/errors");
function toRawSession(doc) {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j;
    const d = (_a = doc.data()) !== null && _a !== void 0 ? _a : {};
    const startAt = d.startAt;
    const endAt = d.endAt;
    // Plain-text speaker fields (denormalized, may already be in the doc).
    const speakerName = d.speaker || d.speakerName || null;
    const speakerTitle = d.speakerTitle || d.speaker_title || null;
    // Speaker document IDs — the first element is the canonical reference.
    const rawIds = d.speakerIds;
    const speakerIds = Array.isArray(rawIds)
        ? rawIds.filter((id) => typeof id === "string")
        : [];
    // speakerId is set deterministically from the Firestore array.
    // No name-based lookup — if the ID is present, we trust it.
    // If only plain-text speaker strings exist (no array), speakerId stays null.
    const speakerId = speakerIds.length > 0 ? speakerIds[0] : null;
    return {
        doc,
        speakerIds,
        dto: {
            id: doc.id,
            title: (_c = (_b = d.title) !== null && _b !== void 0 ? _b : d.name) !== null && _c !== void 0 ? _c : "",
            description: d.description || null,
            startAt: (_d = (0, now_1.timestampToIso)(startAt)) !== null && _d !== void 0 ? _d : new Date(0).toISOString(),
            endAt: (_e = (0, now_1.timestampToIso)(endAt)) !== null && _e !== void 0 ? _e : new Date(0).toISOString(),
            room: (_g = (_f = d.room) !== null && _f !== void 0 ? _f : d.location) !== null && _g !== void 0 ? _g : undefined,
            capacity: (_h = d.capacity) !== null && _h !== void 0 ? _h : undefined,
            tags: d.tags,
            registrationRequired: (_j = d.registrationRequired) !== null && _j !== void 0 ? _j : false,
            speaker: speakerName,
            speakerTitle,
            speakerId,
        },
    };
}
async function listSessions(eventId) {
    var _a;
    const eventSnap = await (0, firestore_1.eventRef)(eventId).get();
    if (!eventSnap.exists) {
        throw (0, errors_1.notFound)("Event not found");
    }
    const [sessSnap, speakersSnap] = await Promise.all([
        (0, firestore_1.sessionsRef)(eventId).orderBy("order").get(),
        (0, firestore_1.speakersRef)(eventId).orderBy("order").get(),
    ]);
    const raws = sessSnap.docs.map((doc) => toRawSession(doc));
    // Build speaker lookup maps: by ID, by sessionId, and by displayName.
    const speakerById = new Map();
    const speakerBySessionId = new Map();
    const speakerByName = new Map();
    for (const sdoc of speakersSnap.docs) {
        const sd = (_a = sdoc.data()) !== null && _a !== void 0 ? _a : {};
        const entry = { id: sdoc.id, data: sd };
        speakerById.set(sdoc.id, entry);
        const sessionId = sd.sessionId;
        if (sessionId) {
            speakerBySessionId.set(sessionId, entry);
        }
        const dName = (sd.displayName || sd.name || "").toLowerCase();
        if (dName)
            speakerByName.set(dName, entry);
    }
    // Enrich DTOs: resolve speakerId via speakerIds array, sessionId, or name match.
    const list = raws.map((raw) => {
        // 1. Match by speakerIds array.
        if (raw.speakerIds.length > 0) {
            const entry = speakerById.get(raw.speakerIds[0]);
            if (entry) {
                return Object.assign(Object.assign({}, raw.dto), { speakerId: entry.id, speaker: raw.dto.speaker ||
                        entry.data.displayName ||
                        entry.data.fullName ||
                        entry.data.name ||
                        null, speakerTitle: raw.dto.speakerTitle ||
                        entry.data.title || null });
            }
        }
        // 2. Match by speaker subcollection sessionId field.
        const bySession = speakerBySessionId.get(raw.dto.id);
        if (bySession) {
            return Object.assign(Object.assign({}, raw.dto), { speakerId: bySession.id, speaker: raw.dto.speaker ||
                    bySession.data.displayName ||
                    bySession.data.fullName ||
                    bySession.data.name ||
                    null, speakerTitle: raw.dto.speakerTitle ||
                    bySession.data.title || null });
        }
        // 3. Match by plain-text speaker name.
        if (raw.dto.speaker) {
            const nameKey = raw.dto.speaker.toLowerCase();
            const byName = speakerByName.get(nameKey);
            if (byName) {
                return Object.assign(Object.assign({}, raw.dto), { speakerId: byName.id, speakerTitle: raw.dto.speakerTitle ||
                        byName.data.title || null });
            }
        }
        return raw.dto;
    });
    list.sort((a, b) => a.startAt.localeCompare(b.startAt));
    return list;
}
//# sourceMappingURL=schedule.service.js.map