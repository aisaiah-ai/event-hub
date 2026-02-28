/**
 * Check-in service: main and session check-in, idempotent.
 * Uses existing: events/{eventId}/registrants/{registrantId} (eventAttendance.checkedInAt,
 * sessionsCheckedIn) and events/{eventId}/sessions/{sessionId}/attendance/{registrantId}.
 * Deterministic ids: main_${uid}, session_${sessionId}_${uid}.
 * Auto main check-in: if session check-in and main missing, create main first.
 */

import * as admin from "firebase-admin";
import {
  eventRef,
  sessionRef,
  registrantRef,
  attendanceDocRef,
} from "../utils/firestore";
import { serverTimestamp, timestampToIso } from "../utils/now";
import { CheckInStatusDto, RequestUser } from "../models/dto";
import { notFound } from "../models/errors";

const SOURCE_APP = "app";

/** Ensure registrant doc exists (for app users it may be created on first check-in or register). */
async function ensureRegistrant(
  tx: admin.firestore.Transaction,
  eventId: string,
  uid: string,
  source: string
): Promise<void> {
  const ref = registrantRef(eventId, uid);
  const snap = await tx.get(ref);
  if (!snap.exists) {
    tx.set(ref, {
      uid,
      source,
      registrationStatus: "registered",
      eventAttendance: {},
      sessionsCheckedIn: {},
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }, { merge: true });
  }
}

/** Main check-in: set eventAttendance.checkedInAt on registrant. Idempotent. */
export async function checkInMain(eventId: string, user: RequestUser): Promise<{ already: boolean }> {
  const uid = user.uid;
  const eventSnap = await eventRef(eventId).get();
  if (!eventSnap.exists) throw notFound("Event not found");

  return await admin.firestore().runTransaction(async (tx) => {
    await ensureRegistrant(tx, eventId, uid, SOURCE_APP);
    const regRef = registrantRef(eventId, uid);
    const regSnap = await tx.get(regRef);
    const data = regSnap.data() ?? {};
    const eventAttendance = (data.eventAttendance as Record<string, unknown>) ?? {};
    const already = !!eventAttendance.checkedInAt;

    if (!already) {
      tx.update(regRef, {
        "eventAttendance.checkedInAt": serverTimestamp(),
        "eventAttendance.checkedInBy": null,
        updatedAt: serverTimestamp(),
      });
    }
    return { already };
  });
}

/** Session check-in. Idempotent. If main not checked in, do main first in same transaction. */
export async function checkInSession(
  eventId: string,
  sessionId: string,
  user: RequestUser
): Promise<{ mainCreated: boolean; already: boolean }> {
  const uid = user.uid;
  const eventSnap = await eventRef(eventId).get();
  if (!eventSnap.exists) throw notFound("Event not found");
  const sessionSnap = await sessionRef(eventId, sessionId).get();
  if (!sessionSnap.exists) throw notFound("Session not found");

  return await admin.firestore().runTransaction(async (tx) => {
    await ensureRegistrant(tx, eventId, uid, SOURCE_APP);
    const regRef = registrantRef(eventId, uid);
    const regSnap = await tx.get(regRef);
    const data = regSnap.data() ?? {};
    const eventAttendance = (data.eventAttendance as Record<string, unknown>) ?? {};
    let mainCreated = false;
    if (!eventAttendance.checkedInAt) {
      tx.update(regRef, {
        "eventAttendance.checkedInAt": serverTimestamp(),
        "eventAttendance.checkedInBy": null,
        updatedAt: serverTimestamp(),
      });
      mainCreated = true;
    }

    const attRef = attendanceDocRef(eventId, sessionId, uid);
    const attSnap = await tx.get(attRef);
    const already = attSnap.exists;
    if (!already) {
      tx.set(attRef, {
        uid,
        type: "session",
        sessionId,
        createdAt: serverTimestamp(),
        source: SOURCE_APP,
        checkedInAt: serverTimestamp(),
      });
      tx.update(regRef, {
        [`sessionsCheckedIn.${sessionId}`]: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    }
    return { mainCreated, already };
  });
}

/** Get check-in status for user at event. */
export async function getCheckInStatus(
  eventId: string,
  user: RequestUser
): Promise<CheckInStatusDto> {
  const uid = user.uid;
  const eventSnap = await eventRef(eventId).get();
  if (!eventSnap.exists) throw notFound("Event not found");

  const regSnap = await registrantRef(eventId, uid).get();
  const data = regSnap.data() ?? {};
  const eventAttendance = (data.eventAttendance as Record<string, unknown>) ?? {};
  const sessionsCheckedIn = (data.sessionsCheckedIn as Record<string, admin.firestore.Timestamp>) ?? {};
  const mainCheckedInAt = eventAttendance.checkedInAt as admin.firestore.Timestamp | undefined;

  return {
    eventId,
    mainCheckedIn: !!mainCheckedInAt,
    mainCheckedInAt: timestampToIso(mainCheckedInAt),
    sessionIds: Object.keys(sessionsCheckedIn),
  };
}
