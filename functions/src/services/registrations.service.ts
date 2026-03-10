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
import { AdditionalRegistrantDto, RegistrationDto, RequestUser } from "../models/dto";
import { notFound, capacityExceeded } from "../models/errors";

function toRegistrationDto(
  eventId: string,
  registrationId: string,
  data: admin.firestore.DocumentData,
  eventStartAt?: string
): RegistrationDto {
  const createdAt = data.createdAt as admin.firestore.Timestamp | undefined;
  const profile = data.profile as Record<string, unknown> | undefined;
  const additionalRegistrants = data.additionalRegistrants as AdditionalRegistrantDto[] | undefined;
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
    ...(additionalRegistrants && additionalRegistrants.length > 0 ? { additionalRegistrants } : {}),
  };
}

/**
 * Validate and filter additional registrants against event registration settings.
 * - Filters out guest entries if allowGuests is false.
 * - Filters out spouse entries if allowSpouse is explicitly false.
 * - Caps guest entries at registrationSettings.maxGuests (default 5).
 * - Allows at most 1 spouse entry.
 */
function validateAdditionalRegistrants(
  raw: Array<Record<string, unknown>>,
  eventData: admin.firestore.DocumentData
): AdditionalRegistrantDto[] {
  const settings = (eventData.registrationSettings ?? {}) as Record<string, unknown>;
  const allowGuests = settings.allowGuests !== false; // default true
  const allowSpouse = settings.allowSpouse !== false; // default true
  const maxGuests = typeof settings.maxGuests === "number" ? settings.maxGuests : 5;

  const result: AdditionalRegistrantDto[] = [];
  let spouseCount = 0;
  let guestCount = 0;

  for (const entry of raw) {
    const type = entry.type as string | undefined;
    const firstName = entry.firstName as string | undefined;
    if (!firstName || typeof firstName !== "string" || firstName.trim().length === 0) continue;
    if (type !== "spouse" && type !== "guest" && type !== "family") continue;

    if (type === "spouse") {
      if (!allowSpouse) continue;
      if (spouseCount >= 1) continue; // max 1 spouse
      spouseCount++;
    } else if (type === "family") {
      // Family members (CFC members with memberId) — always allowed
    } else {
      if (!allowGuests) continue;
      if (guestCount >= maxGuests) continue;
      guestCount++;
    }

    const dto: AdditionalRegistrantDto = {
      type,
      firstName: firstName.trim(),
    };
    const lastName = entry.lastName as string | undefined;
    if (lastName && typeof lastName === "string" && lastName.trim().length > 0) {
      dto.lastName = lastName.trim();
    }
    const memberId = entry.memberId as string | undefined;
    if (memberId && typeof memberId === "string" && memberId.trim().length > 0) {
      dto.memberId = memberId.trim();
    }
    const count = entry.count as number | undefined;
    if (typeof count === "number" && count > 0) {
      dto.count = count;
    }
    result.push(dto);
  }

  return result;
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
        // Allow updating additional registrants on an existing registration
        const incomingAdditional = rsvpData?.additionalRegistrants as Array<Record<string, unknown>> | undefined;
        if (incomingAdditional && Array.isArray(incomingAdditional)) {
          const validated = validateAdditionalRegistrants(incomingAdditional, eventData);
          if (validated.length > 0 || (existing.data.additionalRegistrants ?? []).length > 0) {
            const now = serverTimestamp();
            tx.update(registrantRef(eventId, existing.id), { additionalRegistrants: validated, updatedAt: now });
            tx.update(userRegistrationRef(uid, eventId), { additionalRegistrants: validated });
          }
          return toRegistrationDto(eventId, existing.id, { ...existing.data, additionalRegistrants: validated }, eventStartAt);
        }
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

    // Validate additional registrants (spouse / guest) — needed for reads below
    const incomingAdditional = rsvpData?.additionalRegistrants as Array<Record<string, unknown>> | undefined;
    const additionalRegistrants = incomingAdditional && Array.isArray(incomingAdditional)
      ? validateAdditionalRegistrants(incomingAdditional, eventData)
      : [];

    // ── Read existing registrant docs for spouse/family BEFORE any writes ──
    const arExistingDocs = new Map<string, boolean>();
    for (const ar of additionalRegistrants) {
      if (!ar.memberId || ar.type === "guest") continue;
      const arDoc = await tx.get(registrantRef(eventId, ar.memberId));
      arExistingDocs.set(ar.memberId, arDoc.exists);
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

    const additionalGuestsCount = typeof rsvpData?.additionalGuests === "number" ? rsvpData.additionalGuests as number : 0;

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
      ...(additionalRegistrants.length > 0 ? { additionalRegistrants } : {}),
      ...(additionalGuestsCount > 0 ? { additionalGuests: additionalGuestsCount } : {}),
    }, { merge: true });

    const mirrorRef = userRegistrationRef(uid, eventId);
    tx.set(mirrorRef, {
      eventId,
      registrationId: registrantId,
      registrantId,
      status: "registered",
      createdAt: now,
      eventStartAt: eventData.startAt ?? null,
      ...(additionalRegistrants.length > 0 ? { additionalRegistrants } : {}),
      ...(additionalGuestsCount > 0 ? { additionalGuests: additionalGuestsCount } : {}),
    }, { merge: true });

    // ── Create individual registrant docs for spouse/family with memberIds ──
    // This allows them to see "Registered" when they open the app.
    for (const ar of additionalRegistrants) {
      if (!ar.memberId || ar.type === "guest") continue;
      const arMemberId = ar.memberId;
      // Skip if already registered (read was done above, before writes)
      if (arExistingDocs.get(arMemberId)) continue;

      const arProfile: Record<string, unknown> = {
        name: `${ar.firstName} ${ar.lastName ?? ""}`.trim(),
        firstName: ar.firstName,
        memberId: arMemberId,
      };
      if (ar.lastName) arProfile.lastName = ar.lastName;

      tx.set(registrantRef(eventId, arMemberId), {
        registrantId: arMemberId,
        registrationStatus: "registered",
        status: "registered",
        registeredBy: registrantId, // link back to the primary registrant
        registeredByUid: uid,
        registrationType: ar.type, // "spouse" or "family"
        createdAt: now,
        updatedAt: now,
        profile: arProfile,
        source: "app",
      }, { merge: true });
    }

    return {
      eventId,
      registrationId: registrantId,
      status: "registered" as const,
      createdAt: new Date().toISOString(),
      eventStartAt,
      profile,
      ...(additionalRegistrants.length > 0 ? { additionalRegistrants } : {}),
    };
  });
}

/**
 * Check which memberIds already have a registrant doc for this event.
 * Used by the registration form to show "already registered" badges.
 */
export async function checkRegisteredMembers(
  eventId: string,
  memberIds: string[]
): Promise<string[]> {
  const registered: string[] = [];
  // Batch check: each memberId is a potential doc ID in registrants
  for (const mid of memberIds) {
    const doc = await registrantRef(eventId, mid).get();
    if (doc.exists) {
      const status = doc.data()?.registrationStatus ?? doc.data()?.status;
      if (status === "registered") {
        registered.push(mid);
      }
    }
  }
  // Also check additionalRegistrants arrays for memberIds
  // (for registrations that happened before this fix was deployed)
  if (registered.length < memberIds.length) {
    const remaining = memberIds.filter((id) => !registered.includes(id));
    if (remaining.length > 0) {
      const allRegs = await registrantsRef(eventId).get();
      for (const doc of allRegs.docs) {
        const data = doc.data();
        const additional = data.additionalRegistrants as Array<Record<string, unknown>> | undefined;
        if (!additional) continue;
        for (const ar of additional) {
          const arMemberId = ar.memberId as string | undefined;
          if (arMemberId && remaining.includes(arMemberId) && !registered.includes(arMemberId)) {
            registered.push(arMemberId);
          }
        }
      }
    }
  }
  return registered;
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
  user: RequestUser,
  memberId?: string
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

  // Fallback: check by memberId (for spouse/family registered by someone else)
  if (memberId) {
    const memberDoc = await registrantRef(eventId, memberId).get();
    if (memberDoc.exists) {
      const data = memberDoc.data() ?? {};
      const status = data.registrationStatus ?? data.status;
      if (status === "registered") {
        const eventSnap = await eventRef(eventId).get();
        const eventStartAt = eventSnap.exists
          ? (eventSnap.data()?.startAt as admin.firestore.Timestamp)?.toDate?.()?.toISOString?.()
          : undefined;
        // Link this registrant doc to the user's UID for future lookups
        if (!data.uid) {
          await memberDoc.ref.update({ uid });
          // Also create mirror doc
          await userRegistrationRef(uid, eventId).set({
            eventId,
            registrationId: memberId,
            registrantId: memberId,
            status: "registered",
            createdAt: data.createdAt ?? serverTimestamp(),
            eventStartAt: eventSnap.data()?.startAt ?? null,
          }, { merge: true });
        }
        return toRegistrationDto(eventId, memberId, data, eventStartAt);
      }
    }
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
