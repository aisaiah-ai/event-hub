/**
 * GET /v1/events/:eventId/announcements
 */

import { Request, Response } from "express";
import * as announcementsService from "../../services/announcements.service";
import { ApiError } from "../../models/errors";

export function list(req: Request, res: Response): void {
  const eventId = req.params.eventId as string;
  announcementsService
    .listAnnouncements(eventId)
    .then((data) => res.json({ ok: true, data }))
    .catch((err) => sendError(res, err));
}

function sendError(res: Response, err: unknown): void {
  if (err instanceof ApiError) {
    res.status(err.statusCode).json(err.toJson());
    return;
  }
  res.status(500).json({
    ok: false,
    error: { code: "internal", message: err instanceof Error ? err.message : "Internal error" },
  });
}
