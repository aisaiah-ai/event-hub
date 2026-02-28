/**
 * Announcements service: list announcements for an event (pinned first, then newest).
 * Collection events/{eventId}/announcements may not exist yet.
 */

import * as admin from "firebase-admin";
import { eventRef, announcementsRef } from "../utils/firestore";
import { timestampToIso } from "../utils/now";
import { AnnouncementDto } from "../models/dto";
import { notFound } from "../models/errors";

function toDto(doc: admin.firestore.DocumentSnapshot): AnnouncementDto {
  const d = doc.data() ?? {};
  const createdAt = d.createdAt as admin.firestore.Timestamp | undefined;
  return {
    id: doc.id,
    title: (d.title as string) ?? "",
    body: (d.body as string) ?? "",
    pinned: (d.pinned as boolean) ?? false,
    priority: d.priority as number | undefined,
    createdAt: timestampToIso(createdAt) ?? new Date(0).toISOString(),
  };
}

export async function listAnnouncements(eventId: string): Promise<AnnouncementDto[]> {
  const eventSnap = await eventRef(eventId).get();
  if (!eventSnap.exists) {
    throw notFound("Event not found");
  }
  const snap = await announcementsRef(eventId).get();
  const list = snap.docs.map((doc) => toDto(doc));
  list.sort((a, b) => {
    if (a.pinned && !b.pinned) return -1;
    if (!a.pinned && b.pinned) return 1;
    return b.createdAt.localeCompare(a.createdAt);
  });
  return list;
}
