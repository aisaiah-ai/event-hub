"use strict";
/**
 * In-memory rate limit: per uid per event per minute for check-in.
 * For production consider Redis or Firestore-based limit.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkInRateLimit = checkInRateLimit;
const WINDOW_MS = 60 * 1000; // 1 minute
const MAX_PER_WINDOW = 20; // allow burst but cap
const store = new Map();
function key(uid, eventId) {
    return `${uid}:${eventId}`;
}
function cleanup() {
    const now = Date.now();
    for (const [k, v] of store.entries()) {
        if (v.resetAt < now)
            store.delete(k);
    }
}
/** Rate limit check-in requests: per user per event per minute. */
function checkInRateLimit(req, res, next) {
    const user = req.user;
    const eventId = typeof req.params.eventId === "string" ? req.params.eventId : undefined;
    if (!(user === null || user === void 0 ? void 0 : user.uid) || !eventId) {
        next();
        return;
    }
    cleanup();
    const k = key(user.uid, eventId);
    const now = Date.now();
    let entry = store.get(k);
    if (!entry || entry.resetAt < now) {
        entry = { count: 0, resetAt: now + WINDOW_MS };
        store.set(k, entry);
    }
    entry.count++;
    if (entry.count > MAX_PER_WINDOW) {
        res.status(429).json({
            ok: false,
            error: { code: "rate_limited", message: "Too many check-in requests. Try again in a minute." },
        });
        return;
    }
    next();
}
//# sourceMappingURL=rateLimit.js.map