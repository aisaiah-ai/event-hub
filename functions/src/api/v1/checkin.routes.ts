/**
 * POST /v1/events/:eventId/checkin/main, POST /v1/events/:eventId/checkin/sessions/:sessionId, GET /v1/events/:eventId/checkin/status
 */

import { Request, Response } from "express";
import { RequestUser } from "../../models/dto";
import * as checkinService from "../../services/checkin.service";
import { ApiError } from "../../models/errors";

export function checkInMain(req: Request, res: Response): void {
  const user = (req as Request & { user: RequestUser }).user;
  const eventId = req.params.eventId as string;
  const profileData = req.body as Record<string, unknown> | undefined;
  checkinService
    .checkInMain(eventId, user, profileData)
    .then((data) => res.status(201).json({ ok: true, data }))
    .catch((err) => sendError(res, err));
}

export function registerForSession(req: Request, res: Response): void {
  const user = (req as Request & { user: RequestUser }).user;
  const eventId = req.params.eventId as string;
  const sessionId = req.params.sessionId as string;
  const profileData = req.body as Record<string, unknown> | undefined;
  checkinService
    .registerForSession(eventId, sessionId, user, profileData)
    .then((data) => res.status(201).json({ ok: true, data }))
    .catch((err) => sendError(res, err));
}

export function checkInSession(req: Request, res: Response): void {
  const user = (req as Request & { user: RequestUser }).user;
  const eventId = req.params.eventId as string;
  const sessionId = req.params.sessionId as string;
  const profileData = req.body as Record<string, unknown> | undefined;
  checkinService
    .checkInSession(eventId, sessionId, user, profileData)
    .then((data) => res.status(201).json({ ok: true, data }))
    .catch((err) => sendError(res, err));
}

export function getStatus(req: Request, res: Response): void {
  const user = (req as Request & { user: RequestUser }).user;
  const eventId = req.params.eventId as string;
  checkinService
    .getCheckInStatus(eventId, user)
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
