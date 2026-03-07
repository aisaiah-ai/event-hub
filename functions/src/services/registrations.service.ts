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
  findRegistrantByUid,
  generateZzRegistrantId,
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
  user: RequestUser,
  rsvpData?: Record<string, unknown>
): Promise<RegistrationDto> {
  const uid = user.uid;
  const eventSnap = await eventRef(eventId).get();
  if (!eventSnap.exists) {
    throw notFound("Event not found");
  }
  const eventData = eventSnap.data() ?? {};
  const capacity = eventData.registrationSettings?.capacity as number | undefined;

  // Determine registrant doc ID: CFC memberId if available, else ZZ9999-XXXXXX
  const memberId = rsvpData?.memberId as string | undefined;

  return await admin.firestore().runTransaction(async (tx) => {
    // ── All reads first ──────────────────────────────────────────────
    const eventStartAt = (eventData.startAt as admin.firestore.Timestamp)?.toDate?.()?.toISOString?.();

    // Check if user already registered (by uid field, works for any doc ID)
    const existing = await findRegistrantByUid(eventId, uid, tx);
    if (existing) {
      const status = existing.data.registrationStatus ?? existing.data.status ?? "registered";
      if (status === "registered") {
        return toRegistrationDto(eventId, existing.id, existing.data, eventStartAt);
      }
      // was canceled — re-register with same doc ID below
    }

    // Determine the registrant ID
    let registrantId: string;
    if (existing) {
      registrantId = existing.id; // keep existing doc ID for re-registration
    } else if (memberId && memberId.trim().length > 0) {
      registrantId = memberId.trim();
    } else {
      registrantId = await generateZzRegistrantId(eventId, tx);
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

    // ── All writes after ─────────────────────────────────────────────
    const now = serverTimestamp();
    const profile: Record<string, unknown> = {
      name: rsvpData?.displayName ?? rsvpData?.firstName
        ? `${rsvpData.firstName ?? ""} ${rsvpData.lastName ?? ""}`.trim()
        : user.name ?? user.email ?? undefined,
      email: (rsvpData?.email as string) ?? user.email ?? undefined,
    };
    // Include CFC fields when available
    if (rsvpData?.firstName) profile.firstName = rsvpData.firstName;
    if (rsvpData?.lastName) profile.lastName = rsvpData.lastName;
    if (memberId) profile.memberId = memberId;
    if (rsvpData?.role) profile.role = rsvpData.role;
    if (rsvpData?.service) profile.service = rsvpData.service;
    if (rsvpData?.chapter) profile.chapter = rsvpData.chapter;
    if (rsvpData?.gender) profile.gender = rsvpData.gender;

    const regRef = registrantRef(eventId, registrantId);
    tx.set(regRef, {
      uid,
      registrantId,
      registrationStatus: "registered",
      status: "registered",
      createdAt: now,
      updatedAt: now,
      profile,
      source: "app",
    }, { merge: true });

    const mirrorRef = userRegistrationRef(uid, eventId);
    tx.set(mirrorRef, {
      eventId,
      registrationId: registrantId,
      registrantId,
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
  const uid = user.uid;

  // Look up registrant by uid field (works for memberId, ZZ ID, or legacy uid doc IDs)
  const found = await findRegistrantByUid(eventId, uid);
  if (found) {
    const eventSnap = await eventRef(eventId).get();
    const eventStartAt = eventSnap.exists
      ? (eventSnap.data()?.startAt as admin.firestore.Timestamp)?.toDate?.()?.toISOString?.()
      : undefined;
    return toRegistrationDto(eventId, found.id, found.data, eventStartAt);
  }

  // Fallback: check mirror doc
  const mirrorDoc = await userRegistrationRef(uid, eventId).get();
  if (!mirrorDoc.exists) return null;
  const data = mirrorDoc.data() ?? {};
  const eventSnap = await eventRef(eventId).get();
  const eventStartAt = eventSnap.exists
    ? (eventSnap.data()?.startAt as admin.firestore.Timestamp)?.toDate?.()?.toISOString?.()
    : undefined;
  return toRegistrationDto(eventId, data.registrationId ?? data.registrantId ?? eventId, data, eventStartAt);
}
