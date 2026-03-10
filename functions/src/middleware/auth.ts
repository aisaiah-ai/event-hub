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
 * Secondary Firebase Admin apps for verifying tokens from the mobile app projects.
 * Dev tokens are issued by aisaiah-app-dev; prod tokens by aisaiah-sfa-dev-app.
 * This API runs on aisaiah-event-hub.
 */
const APP_PROJECTS = [
  { id: "aisaiah-app-dev", name: "mainAppDev" },
  { id: "aisaiah-sfa-dev-app", name: "mainAppProd" },
];

const _authInstances: admin.auth.Auth[] = [];

function getAppAuthInstances(): admin.auth.Auth[] {
  if (_authInstances.length > 0) return _authInstances;
  for (const project of APP_PROJECTS) {
    try {
      const existing = admin.app(project.name);
      _authInstances.push(existing.auth());
    } catch {
      const app = admin.initializeApp({ projectId: project.id }, project.name);
      _authInstances.push(app.auth());
    }
  }
  return _authInstances;
}

/**
 * Try verifying a token against multiple projects.
 * Tries dev and prod app projects (where users authenticate),
 * then falls back to the default (event-hub) project.
 */
async function verifyTokenMultiProject(idToken: string): Promise<admin.auth.DecodedIdToken> {
  const authInstances = getAppAuthInstances();
  for (const auth of authInstances) {
    try {
      return await auth.verifyIdToken(idToken);
    } catch {
      // Try next project
    }
  }
  // Final fallback: the default (event-hub) project
  return await admin.auth().verifyIdToken(idToken);
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
