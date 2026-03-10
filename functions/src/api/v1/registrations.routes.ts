/**
 * POST /v1/events/:eventId/register, GET /v1/me/registrations, GET /v1/events/:eventId/my-registration
 */

import { Request, Response } from "express";
import { RequestUser } from "../../models/dto";
import * as registrationsService from "../../services/registrations.service";
import { ApiError } from "../../models/errors";

export function register(req: Request, res: Response): void {
  const user = (req as Request & { user: RequestUser }).user;
  const eventId = req.params.eventId as string;
  const rsvpData = req.body as Record<string, unknown> | undefined;
  registrationsService
    .register(eventId, user, rsvpData)
    .then((data) => res.status(201).json({ ok: true, data }))
    .catch((err) => sendError(res, err));
}

export function listMyRegistrations(req: Request, res: Response): void {
  const user = (req as Request & { user: RequestUser }).user;
  registrationsService
    .listMyRegistrations(user)
    .then((data) => res.json({ ok: true, data }))
    .catch((err) => sendError(res, err));
}

export function getMyRegistration(req: Request, res: Response): void {
  const user = (req as Request & { user: RequestUser }).user;
  const eventId = req.params.eventId as string;
  const memberId = req.query.memberId as string | undefined;
  registrationsService
    .getMyRegistration(eventId, user, memberId)
    .then((data) => {
      if (data === null) {
        res.status(404).json({ ok: false, error: { code: "not_found", message: "Registration not found" } });
        return;
      }
      res.json({ ok: true, data });
    })
    .catch((err) => sendError(res, err));
}

/** Check which memberIds are already registered for an event. */
export function checkRegisteredMembers(req: Request, res: Response): void {
  const eventId = req.params.eventId as string;
  const memberIds = req.query.memberIds as string | undefined;
  if (!memberIds) {
    res.json({ ok: true, data: { registeredMemberIds: [] } });
    return;
  }
  const ids = memberIds.split(",").map((id) => id.trim()).filter(Boolean);
  registrationsService
    .checkRegisteredMembers(eventId, ids)
    .then((registeredIds) => res.json({ ok: true, data: { registeredMemberIds: registeredIds } }))
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
