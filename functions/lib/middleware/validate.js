"use strict";
/**
 * Simple validation helpers for route params/query.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.requireParam = requireParam;
exports.requireEventId = requireEventId;
exports.requireSessionId = requireSessionId;
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
function requireEventId(req, res, next) {
    requireParam("eventId")(req, res, next);
}
function requireSessionId(req, res, next) {
    requireParam("sessionId")(req, res, next);
}
//# sourceMappingURL=validate.js.map