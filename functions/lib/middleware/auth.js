"use strict";
/**
 * Firebase Auth middleware: validate Authorization: Bearer <idToken>, attach req.user.
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.requireAuth = requireAuth;
exports.optionalAuth = optionalAuth;
const admin = __importStar(require("firebase-admin"));
const BEARER_PREFIX = "Bearer ";
function requireAuth(req, res, next) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith(BEARER_PREFIX)) {
        res.status(401).json({ ok: false, error: { code: "unauthenticated", message: "Missing or invalid Authorization header" } });
        return;
    }
    const idToken = authHeader.slice(BEARER_PREFIX.length).trim();
    if (!idToken) {
        res.status(401).json({ ok: false, error: { code: "unauthenticated", message: "Missing token" } });
        return;
    }
    admin
        .auth()
        .verifyIdToken(idToken)
        .then((decoded) => {
        var _a, _b, _c;
        req.user = {
            uid: decoded.uid,
            email: (_a = decoded.email) !== null && _a !== void 0 ? _a : null,
            name: (_c = (_b = decoded.name) !== null && _b !== void 0 ? _b : decoded.email) !== null && _c !== void 0 ? _c : null,
        };
        next();
    })
        .catch(() => {
        res.status(401).json({ ok: false, error: { code: "unauthenticated", message: "Invalid or expired token" } });
    });
}
/** Optional auth: attach user if token present, do not block. */
function optionalAuth(req, res, next) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith(BEARER_PREFIX)) {
        next();
        return;
    }
    const idToken = authHeader.slice(BEARER_PREFIX.length).trim();
    if (!idToken) {
        next();
        return;
    }
    admin
        .auth()
        .verifyIdToken(idToken)
        .then((decoded) => {
        var _a, _b, _c;
        req.user = {
            uid: decoded.uid,
            email: (_a = decoded.email) !== null && _a !== void 0 ? _a : null,
            name: (_c = (_b = decoded.name) !== null && _b !== void 0 ? _b : decoded.email) !== null && _c !== void 0 ? _c : null,
        };
        next();
    })
        .catch(() => next());
}
//# sourceMappingURL=auth.js.map