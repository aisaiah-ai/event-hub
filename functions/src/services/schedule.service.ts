/**
 * Schedule / sessions service: list sessions for an event, ordered by start time.
 */

import * as admin from "firebase-admin";
import { sessionsRef, eventRef } from "../utils/firestore";
import { timestampToIso } from "../utils/now";
import { SessionDto } from "../models/dto";
import { notFound } from "../models/errors";

function toSessionDto(doc: admin.firestore.DocumentSnapshot): SessionDto {
  const d = doc.data() ?? {};
  const startAt = d.startAt as admin.firestore.Timestamp | undefined;
  const endAt = d.endAt as admin.firestore.Timestamp | undefined;
  return {
    id: doc.id,
    title: (d.title as string) ?? (d.name as string) ?? "",
    startAt: timestampToIso(startAt) ?? new Date(0).toISOString(),
    endAt: timestampToIso(endAt) ?? new Date(0).toISOString(),
    room: (d.room as string) ?? (d.location as string) ?? undefined,
    capacity: (d.capacity as number) ?? undefined,
    tags: d.tags as string[] | undefined,
  };
}

export async function listSessions(eventId: string): Promise<SessionDto[]> {
  const eventSnap = await eventRef(eventId).get();
  if (!eventSnap.exists) {
    throw notFound("Event not found");
  }
  const snap = await sessionsRef(eventId).orderBy("order").get();
  const list = snap.docs.map((doc) => toSessionDto(doc));
  list.sort((a, b) => a.startAt.localeCompare(b.startAt));
  return list;
}
