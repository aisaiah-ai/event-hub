"use strict";
/**
 * Simple validation helpers for route params/query.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.requireParam = requireParam;
exports.requireEventId = requireEventId;
exports.requireSessionId = requireSessionId;
exports.requireSpeakerId = requireSpeakerId;
function requireParam(name) {
    return (req, res, next) => {
        const value = req.params[name];
        if (value === undefined || value === "") {
            res.status(400).json({
                ok: false,
                error: { code: "invalid_argument", message: `Missing required parameter: ${name}` },
            });
            return;
        }
        next();
    };
}
/**
 * Event ID aliases — maps alternative IDs to canonical Firestore doc IDs.
 * This lets the mobile app use either ID to refer to the same event.
 */
const EVENT_ID_ALIASES = {
    "march-cluster-2026": "march-assembly",
};
function requireEventId(req, res, next) {
    const raw = req.params.eventId;
    if (raw && EVENT_ID_ALIASES[raw]) {
        req.params.eventId = EVENT_ID_ALIASES[raw];
    }
    requireParam("eventId")(req, res, next);
}
function requireSessionId(req, res, next) {
    requireParam("sessionId")(req, res, next);
}
function requireSpeakerId(req, res, next) {
    requireParam("speakerId")(req, res, next);
}
//# sourceMappingURL=validate.js.map