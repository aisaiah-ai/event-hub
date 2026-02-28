"use strict";
/**
 * Announcements service: list announcements for an event (pinned first, then newest).
 * Collection events/{eventId}/announcements may not exist yet.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.listAnnouncements = listAnnouncements;
const firestore_1 = require("../utils/firestore");
const now_1 = require("../utils/now");
const errors_1 = require("../models/errors");
function toDto(doc) {
    var _a, _b, _c, _d, _e;
    const d = (_a = doc.data()) !== null && _a !== void 0 ? _a : {};
    const createdAt = d.createdAt;
    return {
        id: doc.id,
        title: (_b = d.title) !== null && _b !== void 0 ? _b : "",
        body: (_c = d.body) !== null && _c !== void 0 ? _c : "",
        pinned: (_d = d.pinned) !== null && _d !== void 0 ? _d : false,
        priority: d.priority,
        createdAt: (_e = (0, now_1.timestampToIso)(createdAt)) !== null && _e !== void 0 ? _e : new Date(0).toISOString(),
    };
}
async function listAnnouncements(eventId) {
    const eventSnap = await (0, firestore_1.eventRef)(eventId).get();
    if (!eventSnap.exists) {
        throw (0, errors_1.notFound)("Event not found");
    }
    const snap = await (0, firestore_1.announcementsRef)(eventId).get();
    const list = snap.docs.map((doc) => toDto(doc));
    list.sort((a, b) => {
        if (a.pinned && !b.pinned)
            return -1;
        if (!a.pinned && b.pinned)
            return 1;
        return b.createdAt.localeCompare(a.createdAt);
    });
    return list;
}
//# sourceMappingURL=announcements.service.js.map