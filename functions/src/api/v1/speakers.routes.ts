/**
 * GET /v1/events/:eventId/speakers, GET /v1/events/:eventId/speakers/:speakerId
 */

import { Request, Response } from "express";
import * as speakersService from "../../services/speakers.service";
import { ApiError } from "../../models/errors";

export function list(req: Request, res: Response): void {
  const eventId = req.params.eventId as string;
  speakersService
    .listSpeakers(eventId)
    .then((data) => res.json({ ok: true, data }))
    .catch((err) => sendError(res, err));
}

export function getById(req: Request, res: Response): void {
  const eventId = req.params.eventId as string;
  const speakerId = req.params.speakerId as string;
  speakersService
    .getSpeaker(eventId, speakerId)
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
