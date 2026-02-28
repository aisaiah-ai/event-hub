/**
 * Registrations service: register, my registrations, my registration for event.
 * Uses events/{eventId}/registrants (registrantId = uid for app registrations) and
 * users/{uid}/registrations/{eventId} mirror for fast "my registrations".
 */

import * as admin from "firebase-admin";
import {
  eventRef,
  registrantRef,
  registrantsRef,
  userRegistrationRef,
  userRegistrationsRef,
} from "../utils/firestore";
import { serverTimestamp, timestampToIso } from "../utils/now";
import { RegistrationDto, RequestUser } from "../models/dto";
import { notFound, capacityExceeded } from "../models/errors";

function toRegistrationDto(
  eventId: string,
  registrationId: string,
  data: admin.firestore.DocumentData,
  eventStartAt?: string
): RegistrationDto {
  const createdAt = data.createdAt as admin.firestore.Timestamp | undefined;
  const profile = data.profile as Record<string, unknown> | undefined;
  return {
    eventId,
    registrationId,
    status: (data.registrationStatus as "registered" | "canceled") ?? (data.status as "registered" | "canceled") ?? "registered",
    createdAt: timestampToIso(createdAt) ?? new Date(0).toISOString(),
    eventStartAt,
    profile: profile
      ? {
          name: (profile.name as string) ?? (profile.displayName as string) ?? undefined,
          email: profile.email as string | undefined,
        }
      : undefined,
  };
}

/** Register current user for event. Idempotent; one registration per uid per event. */
export async function register(
  eventId: string,
  user: RequestUser
): Promise<RegistrationDto> {
  const uid = user.uid;
  const eventSnap = await eventRef(eventId).get();
  if (!eventSnap.exists) {
    throw notFound("Event not found");
  }
  const eventData = eventSnap.data() ?? {};
  const capacity = eventData.registrationSettings?.capacity as number | undefined;
  const registrantId = uid; // use uid as registrantId for app registrations

  return await admin.firestore().runTransaction(async (tx) => {
    const regRef = registrantRef(eventId, registrantId);
    const mirrorRef = userRegistrationRef(uid, eventId);
    const existingReg = await tx.get(regRef);
    const eventStartAt = (eventData.startAt as admin.firestore.Timestamp)?.toDate?.()?.toISOString?.();

    if (existingReg.exists) {
      const d = existingReg.data() ?? {};
      const status = d.registrationStatus ?? d.status ?? "registered";
      if (status === "registered") {
        return toRegistrationDto(eventId, registrantId, d, eventStartAt);
      }
      // was canceled — re-register below
    }

    if (typeof capacity === "number" && capacity > 0) {
      const countSnap = await tx.get(registrantsRef(eventId).limit(capacity + 1));
      const activeCount = countSnap.docs.filter((doc) => {
        const s = doc.data().registrationStatus ?? doc.data().status;
        return s !== "canceled";
      }).length;
      if (activeCount >= capacity) {
        throw capacityExceeded("Event is at capacity");
      }
    }

    const now = serverTimestamp();
    const profile = {
      name: user.name ?? user.email ?? undefined,
      email: user.email ?? undefined,
    };
    tx.set(regRef, {
      uid,
      registrationStatus: "registered",
      status: "registered",
      createdAt: now,
      updatedAt: now,
      profile,
      source: "app",
    }, { merge: true });
    tx.set(mirrorRef, {
      eventId,
      registrationId: registrantId as string,
      status: "registered",
      createdAt: now,
      eventStartAt: eventData.startAt ?? null,
    }, { merge: true });

    return {
      eventId,
      registrationId: registrantId,
      status: "registered",
      createdAt: new Date().toISOString(),
      eventStartAt,
      profile,
    };
  });
}

/** List my registrations (from mirror users/{uid}/registrations). */
export async function listMyRegistrations(user: RequestUser): Promise<RegistrationDto[]> {
  const snap = await userRegistrationsRef(user.uid).get();
  const list: RegistrationDto[] = [];
  for (const doc of snap.docs) {
    const data = doc.data();
    const eventId = doc.id;
    const eventSnap = await eventRef(eventId).get();
    const eventStartAt = eventSnap.exists
      ? (eventSnap.data()?.startAt as admin.firestore.Timestamp)?.toDate?.()?.toISOString?.()
      : undefined;
    list.push(toRegistrationDto(eventId, data.registrationId ?? eventId, data, eventStartAt));
  }
  list.sort((a, b) => (b.eventStartAt ?? "").localeCompare(a.eventStartAt ?? ""));
  return list;
}

/** Get my registration for a single event. */
export async function getMyRegistration(
  eventId: string,
  user: RequestUser
): Promise<RegistrationDto | null> {
  const registrantId = user.uid;
  const doc = await registrantRef(eventId, registrantId).get();
  if (!doc.exists) {
    const mirrorDoc = await userRegistrationRef(user.uid, eventId).get();
    if (!mirrorDoc.exists) return null;
    const data = mirrorDoc.data() ?? {};
    const eventSnap = await eventRef(eventId).get();
    const eventStartAt = eventSnap.exists
      ? (eventSnap.data()?.startAt as admin.firestore.Timestamp)?.toDate?.()?.toISOString?.()
      : undefined;
    return toRegistrationDto(eventId, data.registrationId ?? eventId, data, eventStartAt);
  }
  const eventSnap = await eventRef(eventId).get();
  const eventStartAt = eventSnap.exists
    ? (eventSnap.data()?.startAt as admin.firestore.Timestamp)?.toDate?.()?.toISOString?.()
    : undefined;
  return toRegistrationDto(eventId, registrantId, doc.data() ?? {}, eventStartAt);
}
