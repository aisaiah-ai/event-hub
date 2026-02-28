/**
 * GET /v1/events/:eventId/schedule, GET /v1/events/:eventId/sessions
 */

import { Request, Response } from "express";
import * as scheduleService from "../../services/schedule.service";
import { ApiError } from "../../models/errors";

export function listSessions(req: Request, res: Response): void {
  const eventId = req.params.eventId as string;
  scheduleService
    .listSessions(eventId)
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
