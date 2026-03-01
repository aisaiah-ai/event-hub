/**
 * Speakers service: list and get speaker by id for an event.
 * Reads from events/{eventId}/speakers/{speakerId}.
 */

import * as admin from "firebase-admin";
import { eventRef, speakersRef, speakerRef } from "../utils/firestore";
import { SpeakerDto } from "../models/dto";
import { notFound } from "../models/errors";

function toSpeakerDto(doc: admin.firestore.DocumentSnapshot): SpeakerDto {
  const d = doc.data() ?? {};
  const topicsRaw = d.topics;
  const topics: string[] = Array.isArray(topicsRaw)
    ? topicsRaw.filter((t): t is string => typeof t === "string")
    : [];
  return {
    id: doc.id,
    fullName: (d.fullName as string) ?? (d.name as string) ?? "",
    displayName: (d.displayName as string) ?? (d.name as string) ?? null,
    title: (d.title as string) ?? null,
    cluster: (d.cluster as string) ?? null,
    photoUrl: (d.photoUrl as string) ?? null,
    bio: (d.bio as string) ?? null,
    yearsInCfc: (d.yearsInCfc as number) ?? null,
    familiesMentored: (d.familiesMentored as number) ?? null,
    talksGiven: (d.talksGiven as number) ?? null,
    location: (d.location as string) ?? null,
    topics,
    quote: (d.quote as string) ?? null,
    email: (d.email as string) ?? null,
    phone: (d.phone as string) ?? null,
    facebookUrl: (d.facebookUrl as string) ?? null,
    order: (d.order as number) ?? null,
    sessionId: (d.sessionId as string) ?? null,
  };
}

export async function listSpeakers(eventId: string): Promise<SpeakerDto[]> {
  const eventSnap = await eventRef(eventId).get();
  if (!eventSnap.exists) {
    throw notFound("Event not found");
  }
  const snap = await speakersRef(eventId).get();
  const list = snap.docs.map((doc) => toSpeakerDto(doc));
  list.sort((a, b) => (a.order ?? 999) - (b.order ?? 999));
  return list;
}

export async function getSpeaker(eventId: string, speakerId: string): Promise<SpeakerDto> {
  const eventSnap = await eventRef(eventId).get();
  if (!eventSnap.exists) {
    throw notFound("Event not found");
  }
  const doc = await speakerRef(eventId, speakerId).get();
  if (!doc.exists) {
    throw notFound("Speaker not found");
  }
  return toSpeakerDto(doc);
}
