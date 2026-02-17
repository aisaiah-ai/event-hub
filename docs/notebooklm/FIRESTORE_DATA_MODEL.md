# Firestore Data Model — Pure Session Architecture

This document describes the Firestore collections and key fields used by the NLC dashboard and check-in system. All paths are under a single event; the app uses **named databases** (e.g. `event-hub-dev`, `event-hub-prod`) per environment.

---

## Collections Overview

| Path | Purpose | Written by |
|------|---------|------------|
| `events/{eventId}` | Event metadata, config | Admin / bootstrap |
| `events/{eventId}/registrants/{registrantId}` | Registrant profile, answers | App (create/update), import |
| `events/{eventId}/sessions/{sessionId}` | Session config (name, order, active) | Admin / bootstrap |
| `events/{eventId}/sessions/{sessionId}/attendance/{registrantId}` | One doc per check-in to that session | Client or staff (create only) |
| `events/{eventId}/analytics/global` | Event-level pre-aggregated analytics | Cloud Functions only |
| `events/{eventId}/sessions/{sessionId}/analytics/summary` | Per-session pre-aggregated analytics | Cloud Functions only |
| `events/{eventId}/attendeeIndex/{registrantId}` | First session & time per attendee (unique count) | Cloud Functions only |

---

## events/{eventId}

- **Purpose:** Event metadata and feature flags (e.g. self-check-in enabled).
- **Key fields:** `name`, `metadata.selfCheckinEnabled`, etc. Referenced by security rules and app config.

---

## events/{eventId}/registrants/{registrantId}

- **Purpose:** Registrant profile and form answers (region, ministry, name, etc.).
- **Key fields:** `profile`, `answers`, `createdAt` / `registeredAt`, `region`, `ministryMembership`, `lastNameSearchIndex` (for search).
- **Used by:** Check-in search, Cloud Functions (region/ministry for analytics), dashboard “first 3 registrations.”

---

## events/{eventId}/sessions/{sessionId}

- **Purpose:** Session definition (display name, order, active flag).
- **Key fields:** `name`, `order`, `isActive`, `startAt` (optional).
- **Used by:** Session picker, leaderboard labels, dashboard ordering.

---

## events/{eventId}/sessions/{sessionId}/attendance/{registrantId}

- **Purpose:** One document per registrant checked into this session. Create-only from client; no update/delete.
- **Key fields:** `checkedInAt` (timestamp), optional `checkedInBy`.
- **Trigger:** `onAttendanceCreate` Cloud Function runs on each new document and updates analytics.

---

## events/{eventId}/analytics/global

Pre-aggregated event-level analytics. **Written only by Cloud Functions.** Dashboard and wallboard read this document (and session summaries) for all metrics; no client-side aggregation.

| Field | Type | Description |
|-------|------|-------------|
| `totalCheckins` | number | Total check-in count across all sessions (incremented by Function). |
| `totalUniqueAttendees` | number | Count of distinct attendees (via attendeeIndex). |
| `totalRegistrants` | number | Total registrant count (backfill + onRegistrantCreate). |
| `lastUpdated` | timestamp | Last time any aggregate was updated. |
| `regionCounts` | map | Region label → count (e.g. "West" → 42). |
| `ministryCounts` | map | Ministry label → count. |
| `hourlyCheckins` | map | Key `YYYY-MM-DD-HH` → count for trend charts. |
| `earliestCheckin` | map | `registrantId`, `sessionId`, `timestamp` of first check-in. |
| `earliestRegistration` | map | `registrantId`, `timestamp` of first registration. |

---

## events/{eventId}/sessions/{sessionId}/analytics/summary

Pre-aggregated per-session analytics. **Written only by Cloud Functions.**

| Field | Type | Description |
|-------|------|-------------|
| `attendanceCount` | number | Number of check-ins in this session. |
| `lastUpdated` | timestamp | Last update time. |
| `regionCounts` | map | Region → count for this session. |
| `ministryCounts` | map | Ministry → count for this session. |

Session document may also have `isActive`; the dashboard uses session config plus this summary for the leaderboard.

---

## events/{eventId}/attendeeIndex/{registrantId}

- **Purpose:** One document per unique attendee (first session and first check-in time). Used to compute `totalUniqueAttendees` and avoid double-counting across sessions.
- **Written only by Cloud Functions** when a new attendance document is created and no attendeeIndex exists for that registrantId.
- **Key fields:** `firstSession`, `firstCheckinTime`.

---

## Summary

- **Attendance:** Only under `sessions/{sessionId}/attendance/{registrantId}`; no `/checkins` collection.
- **Analytics:** All dashboard metrics come from `analytics/global` and `sessions/*/analytics/summary`; clients never write to these.
- **Scalability:** Aggregation is done in Cloud Functions with atomic increments; the client does not scan attendance or registrant collections for dashboard numbers.
