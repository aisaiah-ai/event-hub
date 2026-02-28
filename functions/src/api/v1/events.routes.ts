/**
 * GET /v1/events, GET /v1/events/:eventId
 */

import { Request, Response } from "express";
import * as eventsService from "../../services/events.service";
import { ApiError } from "../../models/errors";

export function list(req: Request, res: Response): void {
  const from = (req.query.from as string) ?? undefined;
  const to = (req.query.to as string) ?? undefined;
  const chapter = (req.query.chapter as string) ?? undefined;
  const region = (req.query.region as string) ?? undefined;
  eventsService
    .listEvents({ from, to, chapter, region })
    .then((data) => res.json({ ok: true, data }))
    .catch((err) => sendError(res, err));
}

export function getById(req: Request, res: Response): void {
  const eventId = req.params.eventId as string;
  eventsService
    .getEvent(eventId)
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
