# NLC 2026 – Firestore Data Model (Mandatory)

**Single event:** `eventId = "nlc-2026"`. Do not assume any document exists. All paths and fields are defined here.

**Implemented in code:**
- **Paths and field keys:** `lib/src/config/nlc_2026_schema.dart` (single source of truth).
- **Bootstrap creates:** event doc, 4 sessions, `stats/overview` — **only these**. Registrants/attendance/checkins are created by the app or import, not by bootstrap.
- **Bootstrap scripts:** `functions/scripts/ensure-nlc-event-doc.js` and Cloud Function `initializeNlc2026` create the full event + sessions + stats structure. **Run one of them before the app works.**
- **Flutter models:** `Registrant` (eventAttendance, checkInSource, sessionsCheckedIn), `Session` (name, location, order), `CheckinRecord`; all read/write the shapes below.

**Where each document is created (Firestore Console location):**

| Document | Firestore path | Created by |
|----------|----------------|------------|
| Event | **Collection** `events` → **document** `nlc-2026` (fields: name, venue, createdAt, isActive, metadata) | `functions/scripts/ensure-nlc-event-doc.js` or callable `initializeNlc2026` |
| Sessions | `events` → `nlc-2026` → **subcollection** `sessions` → docs `opening-plenary`, `leadership-session-1`, `mass`, `closing` | Same |
| Stats overview | `events` → `nlc-2026` → **subcollection** `stats` → **document** `overview` | Same |

All three are written in one batch. **Database:** app uses **event-hub-dev** (dev) and **event-hub-prod** (prod) per `docs/DATABASE_NAMES.md`. Bootstrap script defaults to **event-hub-dev**; use `--database=event-hub-prod` to seed prod. Cloud Functions use (default) unless configured otherwise. If you only see sessions, run the script again so event and stats/overview exist in the database the app is using.

---

## 1. Event Document

**Path:** `events/nlc-2026`

**Fields:**

| Field      | Type    | Required |
|-----------|--------|----------|
| name      | string | yes      |
| venue     | string | yes      |
| createdAt | timestamp (server) | yes |
| isActive  | boolean | yes     |
| metadata.selfCheckinEnabled | boolean | for self-check-in |
| metadata.sessionsEnabled    | boolean | for session selector |

**Example:**

```json
{
  "name": "National Leaders Conference 2026",
  "venue": "Hyatt Regency Valencia",
  "createdAt": "<serverTimestamp>",
  "isActive": true,
  "metadata": {
    "selfCheckinEnabled": true,
    "sessionsEnabled": true
  }
}
```

---

## 2. Sessions Collection

**Path:** `events/nlc-2026/sessions/{sessionId}`

**Document IDs:** Must exist in Firestore (e.g. `main-checkin`, `opening-plenary`, `leadership-session-1`, `mass`, `closing`). For session-only check-in, **main/arrival** uses session `main-checkin` — create it in bootstrap (name: "Main Check-In", order: 1). **No hardcoded session lists in Flutter** — query with `orderBy('order')`.

**Fields per document:**

| Field    | Type    | Required |
|----------|---------|----------|
| name     | string  | yes      |
| location | string  | yes      |
| order    | number  | yes (for ordering) |
| isActive | boolean | yes      |

**Example:**

```json
{
  "name": "Opening Plenary",
  "location": "Grand Ballroom",
  "order": 1,
  "isActive": true
}
```

---

## 3. Registrants Collection

**Path:** `events/nlc-2026/registrants/{registrantId}`

**Fields (registrant document must support):**

| Field              | Type     | Notes |
|--------------------|----------|--------|
| firstName          | string   |       |
| lastName           | string   |       |
| email              | string   |       |
| region             | string   |       |
| regionOtherText    | string/null |   |
| ministryMembership | string   |       |
| service            | string   |       |
| isEarlyBird        | boolean  |       |
| registeredAt       | Timestamp |     |
| checkedInAt        | Timestamp/null | Event-level check-in time |
| checkedInBy        | string/null |     |
| checkInSource      | string/null | 'QR' \| 'SEARCH' \| 'MANUAL' |
| sessionsCheckedIn  | map      | sessionId → Timestamp |
| eventAttendance    | map      | { checkedIn, checkedInAt, checkedInBy } (alternate shape) |
| updatedAt          | Timestamp |     |

---

## 4. Session Attendance Subcollection

**Path:** `events/nlc-2026/sessions/{sessionId}/attendance/{registrantId}`

**Fields:**

| Field       | Type     |
|-------------|----------|
| checkedInAt | serverTimestamp() |
| checkedInBy | string (e.g. staff email) |

---

## 5. Stats Overview Document (Must Exist Before Analytics)

**Path:** `events/nlc-2026/stats/overview`

**Structure (create via bootstrap; Cloud Functions increment/update):**

| Field                  | Type   | Notes |
|------------------------|--------|--------|
| totalRegistrations     | number |        |
| totalCheckedIn        | number |        |
| earlyBirdCount        | number |        |
| regionCounts          | map    | region → count |
| regionOtherTextCounts  | map    | text → count |
| ministryCounts        | map    | ministry → count |
| serviceCounts         | map    | service → count |
| sessionTotals         | map    | sessionId → count |
| firstCheckInAt        | Timestamp/null |   |
| firstCheckInRegistrantId | string/null | |
| updatedAt             | Timestamp |     |

**No client writes to this document** — Cloud Functions only.

---

## 6. Check-in (session-only)

**No** `events/nlc-2026/checkins` collection. All check-in writes go to **session attendance** only. See `docs/CHECKIN_DESIGN.md`.

---

## Required Writes (Check-in Flow)

**Session-only** — see `docs/CHECKIN_DESIGN.md`.

- **Every check-in** (including main/arrival): Create or ensure **attendance document** at `sessions/{sessionId}/attendance/{registrantId}` with `checkedInAt`, `checkedInBy`. `sessionId` must be a real session doc ID (e.g. `main-checkin`, `opening-plenary`). Use transaction or get-then-set for idempotency.
- No event-level check-in fields required for the flow. No writes to `checkins`.

---

## Bootstrap (required before use)

- **Do not assume** the event document, sessions, or stats/overview exist.
- Run the **initializeNlc2026** Cloud Function callable (admin only) to create event doc, default sessions, and `stats/overview`. See `docs/NLC_2026_DEPLOYMENT.md`.

## Forbidden

- **Do not hardcode session lists** in Flutter. Load from `events/nlc-2026/sessions` with `orderBy('order')`.
- **Do not** use `events/nlc-2026/checkins`. Session-only check-in only (see `docs/CHECKIN_DESIGN.md`).
- **Do not** add event-level-only check-in logic; main check-in is the session `main-checkin`.
