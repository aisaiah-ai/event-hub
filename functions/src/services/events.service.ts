/**
 * Events service: list and get event by id.
 * Uses existing events collection; enforces visibility when present.
 */

import * as admin from "firebase-admin";
import {
  eventsRef,
  eventRef,
} from "../utils/firestore";
import { timestampToIso } from "../utils/now";
import { EventSummaryDto, EventDetailDto } from "../models/dto";
import { notFound } from "../models/errors";

function toSummary(doc: admin.firestore.DocumentSnapshot): EventSummaryDto {
  const d = doc.data() ?? {};
  const startAt = d.startAt as admin.firestore.Timestamp | undefined;
  const endAt = d.endAt as admin.firestore.Timestamp | undefined;
  return {
    id: doc.id,
    title: (d.title as string) ?? (d.name as string) ?? "",
    chapter: d.chapter as string | undefined,
    region: d.region as string | undefined,
    startAt: timestampToIso(startAt) ?? new Date(0).toISOString(),
    endAt: timestampToIso(endAt) ?? new Date(0).toISOString(),
    venue: d.venue as string | undefined,
    visibility: d.visibility as string | undefined,
  };
}

function toDetail(doc: admin.firestore.DocumentSnapshot): EventDetailDto {
  const summary = toSummary(doc);
  const d = doc.data() ?? {};
  return {
    ...summary,
    description: (d.description as string) || null,
    address: (d.address as string) || null,
    registrationSettings: d.registrationSettings as Record<string, unknown> | undefined,
  };
}

export async function listEvents(query: {
  from?: string;
  to?: string;
  chapter?: string;
  region?: string;
}): Promise<EventSummaryDto[]> {
  let ref = eventsRef() as admin.firestore.Query;
  // Optional filters (require composite index if combining)
  if (query.chapter) {
    ref = ref.where("chapter", "==", query.chapter) as admin.firestore.Query;
  }
  if (query.region) {
    ref = ref.where("region", "==", query.region) as admin.firestore.Query;
  }
  const snap = await ref.get();
  let list = snap.docs.map((doc) => toSummary(doc));
  if (query.from) {
    const fromDate = new Date(query.from).getTime();
    list = list.filter((e) => new Date(e.startAt).getTime() >= fromDate);
  }
  if (query.to) {
    const toDate = new Date(query.to).getTime();
    list = list.filter((e) => new Date(e.endAt).getTime() <= toDate);
  }
  // Respect visibility: if field exists and is 'private', exclude unless we add auth later
  list = list.filter((e) => {
    const doc = snap.docs.find((d) => d.id === e.id);
    const vis = doc?.data()?.visibility;
    return vis !== "private";
  });
  list.sort((a, b) => a.startAt.localeCompare(b.startAt));
  return list;
}

export async function getEvent(eventId: string): Promise<EventDetailDto> {
  const doc = await eventRef(eventId).get();
  if (!doc.exists) {
    throw notFound("Event not found");
  }
  const vis = doc.data()?.visibility;
  if (vis === "private") {
    throw notFound("Event not found");
  }
  return toDetail(doc);
}
