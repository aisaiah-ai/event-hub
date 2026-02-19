# Firestore Data Model (event-hub-dev / event-hub-prod)

**When you get an error:** check that the document/collection in the error message has its PARENT created first. Use this doc and the checklist below.

---

## events/{eventId}

- **Parent must exist:** None (root)
- **Created by:** Bootstrap / admin. Must exist before any subcollection write.
- **Notes:** e.g. events/nlc-2026

## events/{eventId}/registrants/{registrantId}

- **Parent must exist:** events/{eventId}
- **Created by:** App (staff import) or seed script
- **Notes:** Registrant profile + answers. Read by check-in search.

## events/{eventId}/sessions/{sessionId}

- **Parent must exist:** events/{eventId}
- **Created by:** Bootstrap. Must exist before writing to attendance.
- **Schema:**
  - `title` (string)
  - `startAt`, `endAt` (Timestamp)
  - `location` (string, e.g. "Grand Ballroom A")
  - `capacity` (number) — hard capacity for gating
  - `attendanceCount` (number) — current checked-in count; authoritative for capacity
  - `colorHex` (string, e.g. "#D4A017")
  - `isMain` (boolean) — true for Main Check-In session only
  - `status` ("open" | "closed") — explicit override
  - `updatedAt` (Timestamp)
  - Optional: `name`, `code`, `order`, `isActive` (legacy)
- **Notes:** One session must have `isMain=true`. A session is available when `status == "open"` and `attendanceCount < capacity`. Client may update only `attendanceCount` and `updatedAt` (increment by 1 in transaction).

## events/{eventId}/sessions/{sessionId}/attendance/{registrantId}

- **Parent must exist:** events/{eventId}/sessions/{sessionId} (session doc must exist)
- **Created by:** App (session check-in). Pure session architecture: all check-in writes here.
- **Schema:**
  - `registrantId` (string)
  - `createdAt` (Timestamp) — or `checkedInAt` for backward compatibility
  - `source` ("qr" | "search" | "manual")
  - `deviceId` (string, optional)
  - `operatorUid` (string, optional)
- **Notes:** Create only; no update/delete from client. Main Check-In uses the session where `isMain=true`.

## events/{eventId}/sessionRegistrations/{registrantId}

- **Parent must exist:** events/{eventId}
- **Created by:** Admin / import / backend. Client reads only.
- **Schema:**
  - `registrantId` (string)
  - `sessionIds` (array of string) — sessions the registrant is pre-registered to
  - `updatedAt` (Timestamp)
- **Notes:** Used to show "You are registered for these sessions" or to bypass selection when a single session. If business rule is one breakout only, still store as array; enforce in UI.

## events/{eventId}/rsvps/{rsvpId}

- **Parent must exist:** events/{eventId}
- **Created by:** App (public RSVP)

## events/{eventId}/admins/{email}

- **Parent must exist:** events/{eventId}
- **Created by:** Admin / bootstrap

## events/{eventId}/schemas/{docId}

- **Parent must exist:** events/{eventId}
- **Created by:** Admin

## events/{eventId}/stats/overview

- **Parent must exist:** events/{eventId}
- **Created by:** Bootstrap; Cloud Functions update

## events/{eventId}/formationSignals/{registrantId}

- **Parent must exist:** events/{eventId}
- **Created by:** App (after check-in) or Cloud Functions

## events/{eventId}/importMappings/{mappingId}

- **Parent must exist:** events/{eventId}
- **Created by:** App (staff import)

---

## Error troubleshooting checklist

1. **Database:** App uses named DB only (`event-hub-dev` or `event-hub-prod`). Never `(default)`.
2. **Event doc:** Before any check-in or registrant read, `events/{eventId}` must exist (e.g. `events/nlc-2026`).
3. **Session doc:** Before writing to `.../sessions/{sessionId}/attendance/...`, the document `events/{eventId}/sessions/{sessionId}` must exist.
4. **Session check-in (only):** All writes to `events/{eventId}/sessions/{sessionId}/attendance/{registrantId}`. Parent session doc must exist. No /checkins.
5. **Bootstrap:** Use Firebase Console or `ensure-nlc-event-doc.js` to create event + session documents (including main-checkin) first.
6. **Rules:** Deploy rules to the database the app uses: `firebase deploy --only firestore:rules`.

