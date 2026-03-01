/**
 * Mount all /v1 routes. Public routes vs requireAuth.
 */

import { Router } from "express";
import { requireAuth } from "../../middleware/auth";
import { requireEventId, requireSessionId, requireSpeakerId } from "../../middleware/validate";
import { checkInRateLimit } from "../../middleware/rateLimit";
import * as eventsRoutes from "./events.routes";
import * as scheduleRoutes from "./schedule.routes";
import * as announcementsRoutes from "./announcements.routes";
import * as speakersRoutes from "./speakers.routes";
import * as registrationsRoutes from "./registrations.routes";
import * as checkinRoutes from "./checkin.routes";

const router = Router();

// —— Public ———
router.get("/events", eventsRoutes.list);
router.get("/events/:eventId", requireEventId, eventsRoutes.getById);
router.get("/events/:eventId/sessions", requireEventId, scheduleRoutes.listSessions);
router.get("/events/:eventId/schedule", requireEventId, scheduleRoutes.listSessions);
router.get("/events/:eventId/announcements", requireEventId, announcementsRoutes.list);
router.get("/events/:eventId/speakers", requireEventId, speakersRoutes.list);
router.get("/events/:eventId/speakers/:speakerId", requireEventId, requireSpeakerId, speakersRoutes.getById);

// —— Member (auth required) ———
router.post("/events/:eventId/register", requireAuth, requireEventId, registrationsRoutes.register);
router.get("/me/registrations", requireAuth, registrationsRoutes.listMyRegistrations);
router.get("/events/:eventId/my-registration", requireAuth, requireEventId, registrationsRoutes.getMyRegistration);

router.post(
  "/events/:eventId/checkin/main",
  requireAuth,
  requireEventId,
  checkInRateLimit,
  checkinRoutes.checkInMain
);
router.post(
  "/events/:eventId/checkin/sessions/:sessionId",
  requireAuth,
  requireEventId,
  requireSessionId,
  checkInRateLimit,
  checkinRoutes.checkInSession
);
router.get(
  "/events/:eventId/checkin/status",
  requireAuth,
  requireEventId,
  checkinRoutes.getStatus
);

export default router;
