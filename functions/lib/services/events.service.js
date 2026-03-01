"use strict";
/**
 * Events service: list and get event by id.
 * Uses existing events collection; enforces visibility when present.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.listEvents = listEvents;
exports.getEvent = getEvent;
const firestore_1 = require("../utils/firestore");
const now_1 = require("../utils/now");
const errors_1 = require("../models/errors");
function toSummary(doc) {
    var _a, _b, _c, _d, _e;
    const d = (_a = doc.data()) !== null && _a !== void 0 ? _a : {};
    const startAt = d.startAt;
    const endAt = d.endAt;
    return {
        id: doc.id,
        title: (_c = (_b = d.title) !== null && _b !== void 0 ? _b : d.name) !== null && _c !== void 0 ? _c : "",
        chapter: d.chapter,
        region: d.region,
        startAt: (_d = (0, now_1.timestampToIso)(startAt)) !== null && _d !== void 0 ? _d : new Date(0).toISOString(),
        endAt: (_e = (0, now_1.timestampToIso)(endAt)) !== null && _e !== void 0 ? _e : new Date(0).toISOString(),
        venue: d.venue,
        visibility: d.visibility,
    };
}
function toDetail(doc) {
    var _a;
    const summary = toSummary(doc);
    const d = (_a = doc.data()) !== null && _a !== void 0 ? _a : {};
    return Object.assign(Object.assign({}, summary), { description: d.description || null, address: d.address || null, registrationSettings: d.registrationSettings });
}
async function listEvents(query) {
    let ref = (0, firestore_1.eventsRef)();
    // Optional filters (require composite index if combining)
    if (query.chapter) {
        ref = ref.where("chapter", "==", query.chapter);
    }
    if (query.region) {
        ref = ref.where("region", "==", query.region);
    }
    const snap = await ref.get();
    let list = snap.docs.map((doc) => toSummary(doc));
    if (query.from) {
        const fromDate = new Date(query.from).getTime();
        list = list.filter((e) => new Date(e.startAt).getTime() >= fromDate);
    }
    if (query.to) {
        const toDate = new Date(query.to).getTime();
        list = list.filter((e) => new Date(e.endAt).getTime() <= toDate);
    }
    // Respect visibility: if field exists and is 'private', exclude unless we add auth later
    list = list.filter((e) => {
        var _a;
        const doc = snap.docs.find((d) => d.id === e.id);
        const vis = (_a = doc === null || doc === void 0 ? void 0 : doc.data()) === null || _a === void 0 ? void 0 : _a.visibility;
        return vis !== "private";
    });
    list.sort((a, b) => a.startAt.localeCompare(b.startAt));
    return list;
}
async function getEvent(eventId) {
    var _a;
    const doc = await (0, firestore_1.eventRef)(eventId).get();
    if (!doc.exists) {
        throw (0, errors_1.notFound)("Event not found");
    }
    const vis = (_a = doc.data()) === null || _a === void 0 ? void 0 : _a.visibility;
    if (vis === "private") {
        throw (0, errors_1.notFound)("Event not found");
    }
    return toDetail(doc);
}
//# sourceMappingURL=events.service.js.map