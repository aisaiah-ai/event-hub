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

export function requireEventId(req: Request, res: Response, next: NextFunction): void {
  requireParam("eventId")(req, res, next);
}

export function requireSessionId(req: Request, res: Response, next: NextFunction): void {
  requireParam("sessionId")(req, res, next);
}
