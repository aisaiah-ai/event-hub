"use strict";
/**
 * Mount all /v1 routes. Public routes vs requireAuth.
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
const express_1 = require("express");
const auth_1 = require("../../middleware/auth");
const validate_1 = require("../../middleware/validate");
const rateLimit_1 = require("../../middleware/rateLimit");
const eventsRoutes = __importStar(require("./events.routes"));
const scheduleRoutes = __importStar(require("./schedule.routes"));
const announcementsRoutes = __importStar(require("./announcements.routes"));
const speakersRoutes = __importStar(require("./speakers.routes"));
const registrationsRoutes = __importStar(require("./registrations.routes"));
const checkinRoutes = __importStar(require("./checkin.routes"));
const router = (0, express_1.Router)();
// —— Public ———
router.get("/events", eventsRoutes.list);
router.get("/events/:eventId", validate_1.requireEventId, eventsRoutes.getById);
router.get("/events/:eventId/sessions", validate_1.requireEventId, scheduleRoutes.listSessions);
router.get("/events/:eventId/schedule", validate_1.requireEventId, scheduleRoutes.listSessions);
router.get("/events/:eventId/announcements", validate_1.requireEventId, announcementsRoutes.list);
router.get("/events/:eventId/speakers", validate_1.requireEventId, speakersRoutes.list);
router.get("/events/:eventId/speakers/:speakerId", validate_1.requireEventId, validate_1.requireSpeakerId, speakersRoutes.getById);
// —— Member (auth required) ———
router.post("/events/:eventId/register", auth_1.requireAuth, validate_1.requireEventId, registrationsRoutes.register);
router.get("/me/registrations", auth_1.requireAuth, registrationsRoutes.listMyRegistrations);
router.get("/events/:eventId/my-registration", auth_1.requireAuth, validate_1.requireEventId, registrationsRoutes.getMyRegistration);
router.post("/events/:eventId/checkin/main", auth_1.requireAuth, validate_1.requireEventId, rateLimit_1.checkInRateLimit, checkinRoutes.checkInMain);
router.post("/events/:eventId/sessions/:sessionId/register", auth_1.requireAuth, validate_1.requireEventId, validate_1.requireSessionId, checkinRoutes.registerForSession);
router.post("/events/:eventId/checkin/sessions/:sessionId", auth_1.requireAuth, validate_1.requireEventId, validate_1.requireSessionId, rateLimit_1.checkInRateLimit, checkinRoutes.checkInSession);
router.get("/events/:eventId/checkin/status", auth_1.requireAuth, validate_1.requireEventId, checkinRoutes.getStatus);
exports.default = router;
//# sourceMappingURL=routes.js.map