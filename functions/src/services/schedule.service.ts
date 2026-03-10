/**
 * Schedule / sessions service: list sessions for an event, ordered by start time.
 *
 * Speaker resolution order per session:
 *  1. d.speakerIds[0]  (array of speaker document IDs → look up speakers subcollection)
 *                       speakerId is ALWAYS set from speakerIds[0] when present.
 *  2. d.speaker / d.speakerName  (plain-text fallback when no speakerIds array exists)
 *                                 speakerId is null in this case.
 *
 * speakerId enables deterministic client-side profile resolution via:
 *   GET /v1/events/:eventId/speakers/:speakerId
 * // NOTE: speakerId enables deterministic client-side profile resolution.
 * // Do not remove without coordinating mobile clients.
 */

import * as admin from "firebase-admin";
import { sessionsRef, eventRef, speakersRef } from "../utils/firestore";
import { timestampToIso } from "../utils/now";
import { SessionDto } from "../models/dto";
import { notFound } from "../models/errors";

interface RawSession {
  doc: admin.firestore.DocumentSnapshot;
  speakerIds: string[];
  dto: SessionDto;
}

function toRawSession(doc: admin.firestore.DocumentSnapshot): RawSession {
  const d = doc.data() ?? {};
  const startAt = d.startAt as admin.firestore.Timestamp | undefined;
  const endAt = d.endAt as admin.firestore.Timestamp | undefined;

  // Plain-text speaker fields (denormalized, may already be in the doc).
  const speakerName =
    (d.speaker as string) || (d.speakerName as string) || null;
  const speakerTitle =
    (d.speakerTitle as string) || (d.speaker_title as string) || null;

  // Speaker document IDs — the first element is the canonical reference.
  const rawIds = d.speakerIds;
  const speakerIds: string[] = Array.isArray(rawIds)
    ? rawIds.filter((id): id is string => typeof id === "string")
    : [];

  // speakerId is set deterministically from the Firestore array.
  // No name-based lookup — if the ID is present, we trust it.
  // If only plain-text speaker strings exist (no array), speakerId stays null.
  const speakerId: string | null = speakerIds.length > 0 ? speakerIds[0] : null;

  return {
    doc,
    speakerIds,
    dto: {
      id: doc.id,
      title: (d.title as string) ?? (d.name as string) ?? "",
      description: (d.description as string) || null,
      startAt: timestampToIso(startAt) ?? new Date(0).toISOString(),
      endAt: timestampToIso(endAt) ?? new Date(0).toISOString(),
      room: (d.room as string) ?? (d.location as string) ?? undefined,
      capacity: (d.capacity as number) ?? undefined,
      tags: d.tags as string[] | undefined,
      registrationRequired: (d.registrationRequired as boolean) ?? false,
      speaker: speakerName,
      speakerTitle,
      speakerId,
    },
  };
}

export async function listSessions(eventId: string): Promise<SessionDto[]> {
  const eventSnap = await eventRef(eventId).get();
  if (!eventSnap.exists) {
    throw notFound("Event not found");
  }

  const [sessSnap, speakersSnap] = await Promise.all([
    sessionsRef(eventId).orderBy("order").get(),
    speakersRef(eventId).orderBy("order").get(),
  ]);

  const raws = sessSnap.docs.map((doc) => toRawSession(doc));

  // Build speaker lookup maps: by ID, by sessionId, and by displayName.
  const speakerById = new Map<string, { id: string; data: admin.firestore.DocumentData }>();
  const speakerBySessionId = new Map<string, { id: string; data: admin.firestore.DocumentData }>();
  const speakerByName = new Map<string, { id: string; data: admin.firestore.DocumentData }>();

  for (const sdoc of speakersSnap.docs) {
    const sd = sdoc.data() ?? {};
    const entry = { id: sdoc.id, data: sd };
    speakerById.set(sdoc.id, entry);
    const sessionId = sd.sessionId as string | undefined;
    if (sessionId) {
      speakerBySessionId.set(sessionId, entry);
    }
    const dName = ((sd.displayName as string) || (sd.name as string) || "").toLowerCase();
    if (dName) speakerByName.set(dName, entry);
  }

  // Enrich DTOs: resolve speakerId via speakerIds array, sessionId, or name match.
  const list: SessionDto[] = raws.map((raw) => {
    // 1. Match by speakerIds array.
    if (raw.speakerIds.length > 0) {
      const entry = speakerById.get(raw.speakerIds[0]);
      if (entry) {
        return {
          ...raw.dto,
          speakerId: entry.id,
          speaker: raw.dto.speaker ||
            (entry.data.displayName as string) ||
            (entry.data.fullName as string) ||
            (entry.data.name as string) ||
            null,
          speakerTitle: raw.dto.speakerTitle ||
            (entry.data.title as string) || null,
        };
      }
    }

    // 2. Match by speaker subcollection sessionId field.
    const bySession = speakerBySessionId.get(raw.dto.id);
    if (bySession) {
      return {
        ...raw.dto,
        speakerId: bySession.id,
        speaker: raw.dto.speaker ||
          (bySession.data.displayName as string) ||
          (bySession.data.fullName as string) ||
          (bySession.data.name as string) ||
          null,
        speakerTitle: raw.dto.speakerTitle ||
          (bySession.data.title as string) || null,
      };
    }

    // 3. Match by plain-text speaker name.
    if (raw.dto.speaker) {
      const nameKey = raw.dto.speaker.toLowerCase();
      const byName = speakerByName.get(nameKey);
      if (byName) {
        return {
          ...raw.dto,
          speakerId: byName.id,
          speakerTitle: raw.dto.speakerTitle ||
            (byName.data.title as string) || null,
        };
      }
    }

    return raw.dto;
  });

  list.sort((a, b) => a.startAt.localeCompare(b.startAt));
  return list;
}
