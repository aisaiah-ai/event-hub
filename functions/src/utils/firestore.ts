/**
 * Firestore instance and path helpers.
 * Uses the default Firestore database.
 * Schema: events, events/{eventId}/sessions, events/{eventId}/registrants,
 * events/{eventId}/sessions/{sessionId}/attendance, events/{eventId}/announcements.
 */

import * as admin from "firebase-admin";

export function getDb(): admin.firestore.Firestore {
  return admin.firestore();
}

export function eventsRef(): admin.firestore.CollectionReference {
  return getDb().collection("events");
}

export function eventRef(eventId: string): admin.firestore.DocumentReference {
  return eventsRef().doc(eventId);
}

export function sessionsRef(eventId: string): admin.firestore.CollectionReference {
  return eventRef(eventId).collection("sessions");
}

export function sessionRef(eventId: string, sessionId: string): admin.firestore.DocumentReference {
  return sessionsRef(eventId).doc(sessionId);
}

export function registrantsRef(eventId: string): admin.firestore.CollectionReference {
  return eventRef(eventId).collection("registrants");
}

export function registrantRef(eventId: string, registrantId: string): admin.firestore.DocumentReference {
  return registrantsRef(eventId).doc(registrantId);
}

export function attendanceRef(
  eventId: string,
  sessionId: string
): admin.firestore.CollectionReference {
  return sessionRef(eventId, sessionId).collection("attendance");
}

export function attendanceDocRef(
  eventId: string,
  sessionId: string,
  registrantId: string
): admin.firestore.DocumentReference {
  return attendanceRef(eventId, sessionId).doc(registrantId);
}

export function announcementsRef(eventId: string): admin.firestore.CollectionReference {
  return eventRef(eventId).collection("announcements");
}

export function speakersRef(eventId: string): admin.firestore.CollectionReference {
  return eventRef(eventId).collection("speakers");
}

export function speakerRef(eventId: string, speakerId: string): admin.firestore.DocumentReference {
  return speakersRef(eventId).doc(speakerId);
}

/**
 * Find the registrant document for a user by uid field.
 * Returns { ref, data, id } or null if not found.
 * Works regardless of whether the doc ID is uid, memberId, or ZZ ID.
 */
export async function findRegistrantByUid(
  eventId: string,
  uid: string,
  tx?: admin.firestore.Transaction
): Promise<{ ref: admin.firestore.DocumentReference; data: admin.firestore.DocumentData; id: string } | null> {
  const query = registrantsRef(eventId).where("uid", "==", uid).limit(1);
  const snap = tx ? await tx.get(query) : await query.get();
  if (snap.empty) return null;
  const doc = snap.docs[0];
  return { ref: doc.ref, data: doc.data(), id: doc.id };
}

/**
 * Generate a registrant ID for non-CFC users.
 * Format: ZZ9999-XXXXXX where XXXXXX is zero-padded incremental.
 * Must be called inside a transaction for safety.
 */
export async function generateZzRegistrantId(
  eventId: string,
  tx: admin.firestore.Transaction
): Promise<string> {
  const query = registrantsRef(eventId)
    .where(admin.firestore.FieldPath.documentId(), ">=", "ZZ9999-")
    .where(admin.firestore.FieldPath.documentId(), "<", "ZZ9999.\uf8ff")
    .orderBy(admin.firestore.FieldPath.documentId(), "desc")
    .limit(1);
  const snap = await tx.get(query);
  let nextNum = 1;
  if (!snap.empty) {
    const lastId = snap.docs[0].id; // e.g. "ZZ9999-000042"
    const numPart = lastId.split("-")[1];
    if (numPart) {
      nextNum = parseInt(numPart, 10) + 1;
    }
  }
  return `ZZ9999-${String(nextNum).padStart(6, "0")}`;
}

/** Mirror for fast "my registrations": users/{uid}/registrations/{eventId} */
export function userRegistrationsRef(uid: string): admin.firestore.CollectionReference {
  return getDb().collection("users").doc(uid).collection("registrations");
}

export function userRegistrationRef(uid: string, eventId: string): admin.firestore.DocumentReference {
  return userRegistrationsRef(uid).doc(eventId);
}
