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
import { sessionsRef, eventRef, speakerRef } from "../utils/firestore";
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

  const snap = await sessionsRef(eventId).orderBy("order").get();
  const raws = snap.docs.map((doc) => toRawSession(doc));

  // Collect unique speakerIds that need resolving (sessions missing plain-text speaker).
  const needsResolve = new Set<string>();
  for (const raw of raws) {
    if ((!raw.dto.speaker || raw.dto.speaker === "") && raw.speakerIds.length > 0) {
      needsResolve.add(raw.speakerIds[0]);
    }
  }

  // Batch-fetch speaker docs for all sessions that need it.
  const speakerCache = new Map<string, admin.firestore.DocumentData>();
  if (needsResolve.size > 0) {
    await Promise.all(
      [...needsResolve].map(async (speakerId) => {
        const sdoc = await speakerRef(eventId, speakerId).get();
        if (sdoc.exists) {
          speakerCache.set(speakerId, sdoc.data() ?? {});
        }
      })
    );
  }

  // Enrich DTOs with resolved speaker data where needed.
  const list: SessionDto[] = raws.map((raw) => {
    if ((!raw.dto.speaker || raw.dto.speaker === "") && raw.speakerIds.length > 0) {
      const sd = speakerCache.get(raw.speakerIds[0]);
      if (sd) {
        return {
          ...raw.dto,
          speaker:
            (sd.displayName as string) ||
            (sd.fullName as string) ||
            (sd.name as string) ||
            null,
          speakerTitle:
            (sd.title as string) || (sd.speaker_title as string) || null,
        };
      }
    }
    return raw.dto;
  });

  list.sort((a, b) => a.startAt.localeCompare(b.startAt));
  return list;
}
