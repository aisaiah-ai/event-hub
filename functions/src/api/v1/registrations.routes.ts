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
  registrationsService
    .register(eventId, user)
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
  registrationsService
    .getMyRegistration(eventId, user)
    .then((data) => {
      if (data === null) {
        res.status(404).json({ ok: false, error: { code: "not_found", message: "Registration not found" } });
        return;
      }
      res.json({ ok: true, data });
    })
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
