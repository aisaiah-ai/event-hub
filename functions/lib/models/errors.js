"use strict";
/**
 * Standard API error codes and response shape.
 * All endpoints return { ok: false, error: { code, message } } on failure.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.ApiError = exports.ErrorCodes = void 0;
exports.unauthorized = unauthorized;
exports.forbidden = forbidden;
exports.notFound = notFound;
exports.invalidArgument = invalidArgument;
exports.conflict = conflict;
exports.capacityExceeded = capacityExceeded;
exports.rateLimited = rateLimited;
exports.internal = internal;
exports.ErrorCodes = {
    UNAUTHENTICATED: "unauthenticated",
    FORBIDDEN: "forbidden",
    NOT_FOUND: "not_found",
    INVALID_ARGUMENT: "invalid_argument",
    CONFLICT: "conflict",
    CAPACITY_EXCEEDED: "capacity_exceeded",
    RATE_LIMITED: "rate_limited",
    INTERNAL: "internal",
};
class ApiError extends Error {
    constructor(statusCode, code, message) {
        super(message);
        this.statusCode = statusCode;
        this.code = code;
        this.name = "ApiError";
    }
    toJson() {
        return {
            ok: false,
            error: { code: this.code, message: this.message },
        };
    }
}
exports.ApiError = ApiError;
function unauthorized(message = "Authentication required") {
    return new ApiError(401, exports.ErrorCodes.UNAUTHENTICATED, message);
}
function forbidden(message = "Forbidden") {
    return new ApiError(403, exports.ErrorCodes.FORBIDDEN, message);
}
function notFound(message = "Resource not found") {
    return new ApiError(404, exports.ErrorCodes.NOT_FOUND, message);
}
function invalidArgument(message) {
    return new ApiError(400, exports.ErrorCodes.INVALID_ARGUMENT, message);
}
function conflict(message) {
    return new ApiError(409, exports.ErrorCodes.CONFLICT, message);
}
function capacityExceeded(message) {
    return new ApiError(409, exports.ErrorCodes.CAPACITY_EXCEEDED, message);
}
function rateLimited(message = "Too many requests") {
    return new ApiError(429, exports.ErrorCodes.RATE_LIMITED, message);
}
function internal(message = "Internal server error") {
    return new ApiError(500, exports.ErrorCodes.INTERNAL, message);
}
//# sourceMappingURL=errors.js.map