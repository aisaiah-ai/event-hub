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
    var _a, _b, _c, _d, _e, _f, _g, _h;
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
            speaker: speakerName,
            speakerTitle,
            speakerId,
        },
    };
}
async function listSessions(eventId) {
    const eventSnap = await (0, firestore_1.eventRef)(eventId).get();
    if (!eventSnap.exists) {
        throw (0, errors_1.notFound)("Event not found");
    }
    const snap = await (0, firestore_1.sessionsRef)(eventId).orderBy("order").get();
    const raws = snap.docs.map((doc) => toRawSession(doc));
    // Collect unique speakerIds that need resolving (sessions missing plain-text speaker).
    const needsResolve = new Set();
    for (const raw of raws) {
        if ((!raw.dto.speaker || raw.dto.speaker === "") && raw.speakerIds.length > 0) {
            needsResolve.add(raw.speakerIds[0]);
        }
    }
    // Batch-fetch speaker docs for all sessions that need it.
    const speakerCache = new Map();
    if (needsResolve.size > 0) {
        await Promise.all([...needsResolve].map(async (speakerId) => {
            var _a;
            const sdoc = await (0, firestore_1.speakerRef)(eventId, speakerId).get();
            if (sdoc.exists) {
                speakerCache.set(speakerId, (_a = sdoc.data()) !== null && _a !== void 0 ? _a : {});
            }
        }));
    }
    // Enrich DTOs with resolved speaker data where needed.
    const list = raws.map((raw) => {
        if ((!raw.dto.speaker || raw.dto.speaker === "") && raw.speakerIds.length > 0) {
            const sd = speakerCache.get(raw.speakerIds[0]);
            if (sd) {
                return Object.assign(Object.assign({}, raw.dto), { speaker: sd.displayName ||
                        sd.fullName ||
                        sd.name ||
                        null, speakerTitle: sd.title || sd.speaker_title || null });
            }
        }
        return raw.dto;
    });
    list.sort((a, b) => a.startAt.localeCompare(b.startAt));
    return list;
}
//# sourceMappingURL=schedule.service.js.map