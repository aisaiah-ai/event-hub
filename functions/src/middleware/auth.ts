/**
 * Firebase Auth middleware: validate Authorization: Bearer <idToken>, attach req.user.
 *
 * Cross-project auth: the mobile app authenticates users via aisaiah-app-dev,
 * but this API runs on aisaiah-event-hub. We initialize a secondary Admin app
 * for aisaiah-app-dev so we can verify tokens issued by that project.
 */

import { Request, Response, NextFunction } from "express";
import * as admin from "firebase-admin";
import { RequestUser } from "../models/dto";

const BEARER_PREFIX = "Bearer ";

/**
 * Secondary Firebase Admin app for verifying tokens from the main app project.
 * Tokens are issued by aisaiah-app-dev; this API runs on aisaiah-event-hub.
 */
const MAIN_APP_PROJECT_ID = "aisaiah-app-dev";
let _mainAppAuth: admin.auth.Auth | null = null;

function getMainAppAuth(): admin.auth.Auth {
  if (_mainAppAuth) return _mainAppAuth;
  try {
    const existing = admin.app("mainApp");
    _mainAppAuth = existing.auth();
  } catch {
    const mainApp = admin.initializeApp({ projectId: MAIN_APP_PROJECT_ID }, "mainApp");
    _mainAppAuth = mainApp.auth();
  }
  return _mainAppAuth;
}

/**
 * Try verifying a token against multiple projects.
 * First tries the main app project (where users authenticate),
 * then falls back to the default (event-hub) project.
 */
async function verifyTokenMultiProject(idToken: string): Promise<admin.auth.DecodedIdToken> {
  try {
    return await getMainAppAuth().verifyIdToken(idToken);
  } catch {
    // Fallback: try the default project (event-hub) in case tokens are issued here too
    return await admin.auth().verifyIdToken(idToken);
  }
}

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
  verifyTokenMultiProject(idToken)
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
  verifyTokenMultiProject(idToken)
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
