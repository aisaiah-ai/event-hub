/**
 * Simple validation helpers for route params/query.
 */

import { Request, Response, NextFunction } from "express";
export function requireParam(name: string) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const value = req.params[name];
    if (value === undefined || value === "") {
      res.status(400).json({
        ok: false,
        error: { code: "invalid_argument", message: `Missing required parameter: ${name}` },
      });
      return;
    }
    next();
  };
}

/**
 * Event ID aliases — maps alternative IDs to canonical Firestore doc IDs.
 * This lets the mobile app use either ID to refer to the same event.
 */
const EVENT_ID_ALIASES: Record<string, string> = {
  "march-cluster-2026": "march-assembly",
};

export function requireEventId(req: Request, res: Response, next: NextFunction): void {
  const raw = req.params.eventId as string | undefined;
  if (raw && EVENT_ID_ALIASES[raw]) {
    (req.params as Record<string, string>).eventId = EVENT_ID_ALIASES[raw];
  }
  requireParam("eventId")(req, res, next);
}

export function requireSessionId(req: Request, res: Response, next: NextFunction): void {
  requireParam("sessionId")(req, res, next);
}

export function requireSpeakerId(req: Request, res: Response, next: NextFunction): void {
  requireParam("speakerId")(req, res, next);
}
