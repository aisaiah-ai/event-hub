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

/** Mirror for fast "my registrations": users/{uid}/registrations/{eventId} */
export function userRegistrationsRef(uid: string): admin.firestore.CollectionReference {
  return getDb().collection("users").doc(uid).collection("registrations");
}

export function userRegistrationRef(uid: string, eventId: string): admin.firestore.DocumentReference {
  return userRegistrationsRef(uid).doc(eventId);
}
