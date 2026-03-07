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
  findRegistrantByUid,
  generateZzRegistrantId,
} from "../utils/firestore";
import { serverTimestamp, timestampToIso } from "../utils/now";
import { CheckInStatusDto, RequestUser } from "../models/dto";
import { notFound } from "../models/errors";

const SOURCE_APP = "app";

/** Build full profile from auth user + request body (CFC fields). */
function buildProfile(
  user: RequestUser,
  body?: Record<string, unknown>
): Record<string, unknown> {
  const profile: Record<string, unknown> = {
    name: body?.displayName ?? body?.firstName
      ? `${body?.firstName ?? ""} ${body?.lastName ?? ""}`.trim()
      : user.name ?? user.email ?? undefined,
    email: (body?.email as string) ?? user.email ?? undefined,
  };
  if (body?.firstName) profile.firstName = body.firstName;
  if (body?.lastName) profile.lastName = body.lastName;
  if (body?.memberId) profile.memberId = body.memberId;
  if (body?.role) profile.role = body.role;
  if (body?.service) profile.service = body.service;
  if (body?.chapter) profile.chapter = body.chapter;
  if (body?.gender) profile.gender = body.gender;
  if (body?.coupleCoordinator) profile.coupleCoordinator = body.coupleCoordinator;
  return profile;
}

/** Main check-in: set eventAttendance.checkedInAt on registrant. Idempotent. */
export async function checkInMain(
  eventId: string,
  user: RequestUser,
  profileData?: Record<string, unknown>
): Promise<{ already: boolean }> {
  const uid = user.uid;
  const eventSnap = await eventRef(eventId).get();
  if (!eventSnap.exists) throw notFound("Event not found");
  const profile = buildProfile(user, profileData);
  const memberId = profileData?.memberId as string | undefined;

  return await admin.firestore().runTransaction(async (tx) => {
    // ── All reads first ──────────────────────────────────────────────
    // Find existing registrant by uid (works for any doc ID scheme)
    const existing = await findRegistrantByUid(eventId, uid, tx);

    // ── All writes after ─────────────────────────────────────────────
    if (!existing) {
      // Create new registrant — use memberId or generate ZZ ID
      let registrantId: string;
      if (memberId && memberId.trim().length > 0) {
        registrantId = memberId.trim();
      } else {
        registrantId = await generateZzRegistrantId(eventId, tx);
      }
      const regRef = registrantRef(eventId, registrantId);
      tx.set(regRef, {
        uid,
        registrantId,
        source: SOURCE_APP,
        registrationStatus: "registered",
        profile,
        eventAttendance: { checkedInAt: serverTimestamp(), checkedInBy: null },
        sessionsCheckedIn: {},
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }, { merge: true });
      return { already: false };
    }

    const data = existing.data;
    const eventAttendance = (data.eventAttendance as Record<string, unknown>) ?? {};
    const already = !!eventAttendance.checkedInAt;

    // Always update profile with latest data
    const updates: Record<string, unknown> = {
      profile,
      updatedAt: serverTimestamp(),
    };
    if (!already) {
      updates["eventAttendance.checkedInAt"] = serverTimestamp();
      updates["eventAttendance.checkedInBy"] = null;
    }
    tx.update(existing.ref, updates);
    return { already };
  });
}

/** Register for a session. Idempotent. Creates attendance doc with registeredAt but no checkedInAt.
 *  Also ensures event-level registrant doc exists. Doc ID = CFC memberId or ZZ9999-XXXXXX. */
export async function registerForSession(
  eventId: string,
  sessionId: string,
  user: RequestUser,
  profileData?: Record<string, unknown>
): Promise<{ already: boolean }> {
  const uid = user.uid;
  const eventSnap = await eventRef(eventId).get();
  if (!eventSnap.exists) throw notFound("Event not found");
  const sessionSnap = await sessionRef(eventId, sessionId).get();
  if (!sessionSnap.exists) throw notFound("Session not found");
  const profile = buildProfile(user, profileData);
  const memberId = profileData?.memberId as string | undefined;

  return await admin.firestore().runTransaction(async (tx) => {
    // ── All reads first ──────────────────────────────────────────────
    const existing = await findRegistrantByUid(eventId, uid, tx);

    let registrantId: string;
    let regRef: admin.firestore.DocumentReference;

    if (existing) {
      registrantId = existing.id;
      regRef = existing.ref;
    } else {
      if (memberId && memberId.trim().length > 0) {
        registrantId = memberId.trim();
      } else {
        registrantId = await generateZzRegistrantId(eventId, tx);
      }
      regRef = registrantRef(eventId, registrantId);
    }

    const attRef = attendanceDocRef(eventId, sessionId, registrantId);
    const attSnap = await tx.get(attRef);

    // ── All writes after ─────────────────────────────────────────────
    // Ensure event-level registrant doc exists
    if (!existing) {
      tx.set(regRef, {
        uid,
        registrantId,
        source: SOURCE_APP,
        registrationStatus: "registered",
        profile,
        sessionsRegistered: {},
        sessionsCheckedIn: {},
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }, { merge: true });
    } else {
      tx.update(regRef, { profile, updatedAt: serverTimestamp() });
    }

    const already = attSnap.exists;
    if (!already) {
      tx.set(attRef, {
        uid,
        registrantId,
        type: "session",
        sessionId,
        profile,
        registeredAt: serverTimestamp(),
        checkedInAt: null,
        createdAt: serverTimestamp(),
        source: SOURCE_APP,
      });
      tx.update(regRef, {
        [`sessionsRegistered.${sessionId}`]: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    }
    return { already };
  });
}

/** Session check-in. Idempotent. Requires session registration (attendance doc must exist).
 *  If main not checked in, do main first in same transaction. */
export async function checkInSession(
  eventId: string,
  sessionId: string,
  user: RequestUser,
  profileData?: Record<string, unknown>
): Promise<{ mainCreated: boolean; already: boolean }> {
  const uid = user.uid;
  const eventSnap = await eventRef(eventId).get();
  if (!eventSnap.exists) throw notFound("Event not found");
  const sessionSnap = await sessionRef(eventId, sessionId).get();
  if (!sessionSnap.exists) throw notFound("Session not found");
  const profile = buildProfile(user, profileData);

  return await admin.firestore().runTransaction(async (tx) => {
    // ── All reads first ──────────────────────────────────────────────
    const existing = await findRegistrantByUid(eventId, uid, tx);
    if (!existing) throw notFound("Not registered for this event");

    const registrantId = existing.id;
    const regRef = existing.ref;

    // Attendance doc uses registrant ID as key
    const attRef = attendanceDocRef(eventId, sessionId, registrantId);
    const attSnap = await tx.get(attRef);

    // Session must have registration (attendance doc with registeredAt)
    if (!attSnap.exists) {
      throw notFound("Not registered for this session. Please register first.");
    }

    // ── All writes after ─────────────────────────────────────────────
    const attData = attSnap.data() ?? {};
    const already = !!attData.checkedInAt;

    // Ensure main event check-in
    let mainCreated = false;
    const data = existing.data;
    const eventAttendance = (data.eventAttendance as Record<string, unknown>) ?? {};
    if (!eventAttendance.checkedInAt) {
      tx.update(regRef, {
        "eventAttendance.checkedInAt": serverTimestamp(),
        "eventAttendance.checkedInBy": null,
        profile,
        updatedAt: serverTimestamp(),
      });
      mainCreated = true;
    } else {
      tx.update(regRef, { profile, updatedAt: serverTimestamp() });
    }

    if (!already) {
      tx.update(attRef, {
        checkedInAt: serverTimestamp(),
        profile,
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

  // Find registrant by uid (works for memberId, ZZ ID, or legacy uid doc IDs)
  const found = await findRegistrantByUid(eventId, uid);
  const data = found?.data ?? {};
  const eventAttendance = (data.eventAttendance as Record<string, unknown>) ?? {};
  const sessionsCheckedIn = (data.sessionsCheckedIn as Record<string, admin.firestore.Timestamp>) ?? {};
  const sessionsRegistered = (data.sessionsRegistered as Record<string, admin.firestore.Timestamp>) ?? {};
  const mainCheckedInAt = eventAttendance.checkedInAt as admin.firestore.Timestamp | undefined;

  return {
    eventId,
    mainCheckedIn: !!mainCheckedInAt,
    mainCheckedInAt: timestampToIso(mainCheckedInAt),
    sessionIds: Object.keys(sessionsCheckedIn),
    sessionRegisteredIds: Object.keys(sessionsRegistered),
  };
}
