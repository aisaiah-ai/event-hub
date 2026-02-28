"use strict";
/**
 * POST /v1/events/:eventId/checkin/main, POST /v1/events/:eventId/checkin/sessions/:sessionId, GET /v1/events/:eventId/checkin/status
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
exports.checkInMain = checkInMain;
exports.checkInSession = checkInSession;
exports.getStatus = getStatus;
const checkinService = __importStar(require("../../services/checkin.service"));
const errors_1 = require("../../models/errors");
function checkInMain(req, res) {
    const user = req.user;
    const eventId = req.params.eventId;
    checkinService
        .checkInMain(eventId, user)
        .then((data) => res.status(201).json({ ok: true, data }))
        .catch((err) => sendError(res, err));
}
function checkInSession(req, res) {
    const user = req.user;
    const eventId = req.params.eventId;
    const sessionId = req.params.sessionId;
    checkinService
        .checkInSession(eventId, sessionId, user)
        .then((data) => res.status(201).json({ ok: true, data }))
        .catch((err) => sendError(res, err));
}
function getStatus(req, res) {
    const user = req.user;
    const eventId = req.params.eventId;
    checkinService
        .getCheckInStatus(eventId, user)
        .then((data) => res.json({ ok: true, data }))
        .catch((err) => sendError(res, err));
}
function sendError(res, err) {
    if (err instanceof errors_1.ApiError) {
        res.status(err.statusCode).json(err.toJson());
        return;
    }
    res.status(500).json({
        ok: false,
        error: { code: "internal", message: err instanceof Error ? err.message : "Internal error" },
    });
}
//# sourceMappingURL=checkin.routes.js.map