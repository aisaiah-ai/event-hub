"use strict";
/**
 * GET /v1/events, GET /v1/events/:eventId
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
exports.list = list;
exports.getById = getById;
const eventsService = __importStar(require("../../services/events.service"));
const errors_1 = require("../../models/errors");
function list(req, res) {
    var _a, _b, _c, _d;
    const from = (_a = req.query.from) !== null && _a !== void 0 ? _a : undefined;
    const to = (_b = req.query.to) !== null && _b !== void 0 ? _b : undefined;
    const chapter = (_c = req.query.chapter) !== null && _c !== void 0 ? _c : undefined;
    const region = (_d = req.query.region) !== null && _d !== void 0 ? _d : undefined;
    eventsService
        .listEvents({ from, to, chapter, region })
        .then((data) => res.json({ ok: true, data }))
        .catch((err) => sendError(res, err));
}
function getById(req, res) {
    const eventId = req.params.eventId;
    eventsService
        .getEvent(eventId)
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
//# sourceMappingURL=events.routes.js.map