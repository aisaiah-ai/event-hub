/**
 * Server timestamp and ISO string helpers.
 */

import * as admin from "firebase-admin";

export function serverTimestamp(): admin.firestore.FieldValue {
  return admin.firestore.FieldValue.serverTimestamp();
}

export function isoNow(): string {
  return new Date().toISOString();
}

export function timestampToIso(ts: admin.firestore.Timestamp | undefined): string | undefined {
  if (!ts || typeof ts.toDate !== "function") return undefined;
  return (ts as admin.firestore.Timestamp).toDate().toISOString();
}
