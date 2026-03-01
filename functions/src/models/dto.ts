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
  description?: string | null;
  address?: string | null;
  registrationSettings?: Record<string, unknown>;
}

/** Speaker (event-level: events/{eventId}/speakers/{speakerId}) */
export interface SpeakerDto {
  id: string;
  fullName: string;
  displayName?: string | null;
  title?: string | null;
  cluster?: string | null;
  photoUrl?: string | null;
  bio?: string | null;
  yearsInCfc?: number | null;
  familiesMentored?: number | null;
  talksGiven?: number | null;
  location?: string | null;
  topics?: string[];
  quote?: string | null;
  email?: string | null;
  phone?: string | null;
  facebookUrl?: string | null;
  order?: number | null;
  /** ID of the session this speaker is presenting at. */
  sessionId?: string | null;
}

/** Session (schedule item) */
export interface SessionDto {
  id: string;
  title: string;
  description?: string | null;
  startAt: string;
  endAt: string;
  room?: string;
  capacity?: number;
  tags?: string[];
  /** Denormalized speaker display name (kept for backward compatibility). */
  speaker?: string | null;
  /** Denormalized speaker title/role (kept for backward compatibility). */
  speakerTitle?: string | null;
  /**
   * Optional document ID reference to the full speaker profile.
   * When present, clients may fetch full speaker details from:
   * GET /v1/events/:eventId/speakers/:speakerId
   * Null when the session has no linked speaker document (e.g. plain-text
   * speaker string with no speakerIds array in the Firestore document).
   */
  speakerId?: string | null;
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
