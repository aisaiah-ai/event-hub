"use strict";
/**
 * Schedule / sessions service: list sessions for an event, ordered by start time.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.listSessions = listSessions;
const firestore_1 = require("../utils/firestore");
const now_1 = require("../utils/now");
const errors_1 = require("../models/errors");
function toSessionDto(doc) {
    var _a, _b, _c, _d, _e, _f, _g, _h;
    const d = (_a = doc.data()) !== null && _a !== void 0 ? _a : {};
    const startAt = d.startAt;
    const endAt = d.endAt;
    return {
        id: doc.id,
        title: (_c = (_b = d.title) !== null && _b !== void 0 ? _b : d.name) !== null && _c !== void 0 ? _c : "",
        startAt: (_d = (0, now_1.timestampToIso)(startAt)) !== null && _d !== void 0 ? _d : new Date(0).toISOString(),
        endAt: (_e = (0, now_1.timestampToIso)(endAt)) !== null && _e !== void 0 ? _e : new Date(0).toISOString(),
        room: (_g = (_f = d.room) !== null && _f !== void 0 ? _f : d.location) !== null && _g !== void 0 ? _g : undefined,
        capacity: (_h = d.capacity) !== null && _h !== void 0 ? _h : undefined,
        tags: d.tags,
    };
}
async function listSessions(eventId) {
    const eventSnap = await (0, firestore_1.eventRef)(eventId).get();
    if (!eventSnap.exists) {
        throw (0, errors_1.notFound)("Event not found");
    }
    const snap = await (0, firestore_1.sessionsRef)(eventId).orderBy("order").get();
    const list = snap.docs.map((doc) => toSessionDto(doc));
    list.sort((a, b) => a.startAt.localeCompare(b.startAt));
    return list;
}
//# sourceMappingURL=schedule.service.js.map