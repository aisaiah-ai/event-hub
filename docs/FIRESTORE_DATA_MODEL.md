# Firestore Data Model (event-hub-dev / event-hub-prod / (default))

**Architecture:** Registrants = identity. Session registrations = intent (pre-reg). Attendance = physical check-in. Sessions = capacity + metadata. Analytics = computed server-side.

**When you get an error:** check that the document/collection in the error message has its PARENT created first. Use this doc and the checklist below.

---

## events/{eventId}

- **Parent must exist:** None (root)
- **Created by:** Bootstrap / admin. Must exist before any subcollection write.
- **Notes:** e.g. events/nlc-2026

## events/{eventId}/registrants/{registrantId}

- **Parent must exist:** events/{eventId}
- **Created by:** App (staff import) or seed script
- **Notes:** **Identity.** Registrant profile + answers. Read by check-in search. No change to this path.

## events/{eventId}/sessions/{sessionId}

- **Parent must exist:** events/{eventId}
- **Created by:** Bootstrap. Must exist before writing to attendance.
- **Schema (ensure present):**
  - `title` (string)
  - `startAt`, `endAt` (Timestamp)
  - `location` (string)
  - `capacity` (number) — hard capacity; 0 = no limit
  - `attendanceCount` (number) — current checked-in count; authoritative for capacity
  - `colorHex` (string)
  - `isMain` (boolean) — true for Main Check-In only
  - `status` ("open" | "closed")
  - `updatedAt` (Timestamp)
  - Optional: `name`, `code`, `order`, `isActive`
- **Computed (client):** `remainingSeats = capacity - attendanceCount`; `isAvailable = status == open && remainingSeats > 0`.
- **Notes:** One session must have `isMain=true`. Client may update **only** `attendanceCount` (increment by 1) and `updatedAt` in a transaction. Create/delete = false in rules. NLC bootstrap sets `location`, `capacity`, `colorHex` per venue (Main Ballroom 450, Valencia 192, Saugus/Castaic 72); these can be updated later in Firestore.

## events/{eventId}/sessions/{sessionId}/attendance/{registrantId}

- **Parent must exist:** events/{eventId}/sessions/{sessionId}
- **Created by:** App (session check-in). **Physical presence.** Do not change this path.
- **Schema:**
  - `registrantId` (string)
  - `createdAt` (Timestamp) — or `checkedInAt` for backward compatibility
  - `source` ("qr" | "search" | "manual")
  - `deviceId` (string, optional)
  - `checkedInBy` (string, optional)
- **Notes:** Create only; no update/delete from client. Main Check-In uses the session where `isMain=true`.

## events/{eventId}/sessionRegistrations/{registrantId}

- **Parent must exist:** events/{eventId}
- **Created by:** Admin / import / seed / backend. **Client reads only; no client writes.**
- **Schema:**
  - `registrantId` (string)
  - `sessionIds` (array of string) — sessions the registrant is pre-registered to (intent)
  - `updatedAt` (Timestamp)
- **Notes:** **Intent.** One doc per registrant; supports multi-session. Check-in flow reads this: if one session → lock UI and check in to that session; if none → show available sessions; if multiple → session selection. Writes are server/admin/seed only (rules: write false).

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

1. **Database:** App may use `(default)` or named DB (`event-hub-dev`, `event-hub-prod`). Check `lib/src/config/firestore_config.dart`. Scripts must target the same DB.
2. **Event doc:** Before any check-in or registrant read, `events/{eventId}` must exist (e.g. `events/nlc-2026`).
3. **Session doc:** Before writing to `.../sessions/{sessionId}/attendance/...`, the document `events/{eventId}/sessions/{sessionId}` must exist.
4. **Session check-in (only):** All writes to `events/{eventId}/sessions/{sessionId}/attendance/{registrantId}`. Parent session doc must exist. No /checkins.
5. **Bootstrap:** Use Firebase Console or `ensure-nlc-event-doc.js` to create event + session documents (including main-checkin) first.
6. **Rules:** Deploy rules to the database the app uses: `firebase deploy --only firestore:rules`.

