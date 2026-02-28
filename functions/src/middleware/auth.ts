/**
 * Firebase Auth middleware: validate Authorization: Bearer <idToken>, attach req.user.
 */

import { Request, Response, NextFunction } from "express";
import * as admin from "firebase-admin";
import { RequestUser } from "../models/dto";

const BEARER_PREFIX = "Bearer ";

export function requireAuth(req: Request, res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith(BEARER_PREFIX)) {
    res.status(401).json({ ok: false, error: { code: "unauthenticated", message: "Missing or invalid Authorization header" } });
    return;
  }
  const idToken = authHeader.slice(BEARER_PREFIX.length).trim();
  if (!idToken) {
    res.status(401).json({ ok: false, error: { code: "unauthenticated", message: "Missing token" } });
    return;
  }
  admin
    .auth()
    .verifyIdToken(idToken)
    .then((decoded) => {
      (req as Request & { user: RequestUser }).user = {
        uid: decoded.uid,
        email: decoded.email ?? null,
        name: (decoded.name as string) ?? (decoded.email as string) ?? null,
      };
      next();
    })
    .catch(() => {
      res.status(401).json({ ok: false, error: { code: "unauthenticated", message: "Invalid or expired token" } });
    });
}

/** Optional auth: attach user if token present, do not block. */
export function optionalAuth(req: Request, res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith(BEARER_PREFIX)) {
    next();
    return;
  }
  const idToken = authHeader.slice(BEARER_PREFIX.length).trim();
  if (!idToken) {
    next();
    return;
  }
  admin
    .auth()
    .verifyIdToken(idToken)
    .then((decoded) => {
      (req as Request & { user: RequestUser }).user = {
        uid: decoded.uid,
        email: decoded.email ?? null,
        name: (decoded.name as string) ?? (decoded.email as string) ?? null,
      };
      next();
    })
    .catch(() => next());
}
