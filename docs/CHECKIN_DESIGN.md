# Check-In Design (Authoritative) — Session-Only

**Use this doc as the single source of truth.** All check-in is session-scoped. No event-level check-in. No `events/{eventId}/checkins` collection.

---

## 1. Single flow: session attendance only

| What | Where it writes |
|------|------------------|
| **Every check-in** (including “main” / arrival) | `events/{eventId}/sessions/{sessionId}/attendance/{registrantId}` only |

- **Main Check-In** is implemented as a **session** with ID `main-checkin`. Create document at `events/{eventId}/sessions/main-checkin` (e.g. name: "Main Check-In", order: 1). Treat it like any other session.
- **Badge and status** come only from whether the attendance doc exists for the **current** session; no global “checked in” flag.
- **No** `events/{eventId}/checkins` collection. No client writes to it. Rules deny read/write if the path exists.

---

## 2. Firestore structure (allowed)

```
events/{eventId}
  registrants/{registrantId}
  sessions/{sessionId}
    attendance/{registrantId}
      checkedInAt   (server timestamp)
      checkedInBy   (string)
```

- `sessionId` must be a real session document ID (e.g. `main-checkin`, `opening-plenary`, `immigration-dialogue`).
- **Implementation:** `CheckInService.checkIn()` in `lib/services/checkin_service.dart`. All UI check-in paths use this (search, QR, manual). `CheckinRepository.checkInSessionOnly()` delegates to `SessionService.checkInSessionOnly()`.

---

## 3. UI rules

- **Session context banner:** At top of check-in search: “Now Checking In For: {SESSION NAME}” (gold, with divider). Session name from `sessionDisplayName(sessionId)` or route.
- **Badge:** Only from `getSessionAttendanceInfo(eventId, sessionId, registrantId)` — show CHECKED IN + `checkedInAt` time when doc exists; NOT CHECKED IN when it does not.
- **Session switch:** When the selected session changes, clear results and re-fetch; do not reuse attendance state from another session.

---

## 4. Paths and schema

- **Path helpers:** `lib/src/config/nlc_2026_schema.dart` (e.g. `Nlc2026Schema.attendancePath(sessionId, registrantId)`).
- **Database:** `FirestoreConfig.databaseId` in `lib/src/config/firestore_config.dart`. See `docs/DATABASE_NAMES.md`.

---

## 5. Do not invent

- **Do not** add event-level check-in or a global “checked in” flag.
- **Do not** use or create `events/{eventId}/checkins`.
- **Do not** assume a session exists without creating it in Firestore (e.g. create `sessions/main-checkin` via bootstrap).

---

## 6. References

- Data model: `docs/NLC_2026_DATA_MODEL.md`
- High-level: `docs/architecture/event-hub-design.md` §8
- Schema: `lib/src/config/nlc_2026_schema.dart`
