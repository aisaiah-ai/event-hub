/**
 * DTOs and request/response shapes for the /v1 API.
 */

/** Success response: { ok: true, data: T } */
export interface SuccessResponse<T> {
  ok: true;
  data: T;
}

/** Public event summary (list item) */
export interface EventSummaryDto {
  id: string;
  title: string;
  chapter?: string;
  region?: string;
  startAt: string; // ISO
  endAt: string;
  venue?: string;
  visibility?: string;
}

/** Single event detail */
export interface EventDetailDto extends EventSummaryDto {
  registrationSettings?: Record<string, unknown>;
}

/** Session (schedule item) */
export interface SessionDto {
  id: string;
  title: string;
  startAt: string;
  endAt: string;
  room?: string;
  capacity?: number;
  tags?: string[];
}

/** Announcement */
export interface AnnouncementDto {
  id: string;
  title: string;
  body: string;
  pinned: boolean;
  priority?: number;
  createdAt: string;
}

/** Registration (my registration or register response) */
export interface RegistrationDto {
  eventId: string;
  registrationId: string;
  status: "registered" | "canceled";
  createdAt: string;
  eventStartAt?: string;
  profile?: { name?: string; email?: string };
}

/** Check-in status for a user at an event */
export interface CheckInStatusDto {
  eventId: string;
  mainCheckedIn: boolean;
  mainCheckedInAt?: string;
  sessionIds: string[];
}

/** User attached by auth middleware */
export interface RequestUser {
  uid: string;
  email?: string | null;
  name?: string | null;
}
