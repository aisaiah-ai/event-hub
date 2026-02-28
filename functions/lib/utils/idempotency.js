"use strict";
/**
 * Idempotency keys for check-in.
 * Deterministic checkin IDs: main_${uid}, session_${sessionId}_${uid}.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.mainCheckInId = mainCheckInId;
exports.sessionCheckInId = sessionCheckInId;
function mainCheckInId(uid) {
    return `main_${uid}`;
}
function sessionCheckInId(sessionId, uid) {
    return `session_${sessionId}_${uid}`;
}
//# sourceMappingURL=idempotency.js.map