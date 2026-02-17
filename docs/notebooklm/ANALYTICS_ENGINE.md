# Analytics Engine — Cloud Functions & Pre-Aggregation

The NLC dashboard and wallboard **read only pre-aggregated data**. All aggregation is performed server-side by Cloud Functions. Clients never scan attendance or registrant collections for dashboard metrics.

---

## onAttendanceCreate

**Trigger:** A new document is created at  
`events/{eventId}/sessions/{sessionId}/attendance/{registrantId}`  
(e.g. when a registrant is checked into a session).

**Behavior (single transaction):**

1. **Read registrant document** — To obtain `region` and `ministry` (or fallbacks like "Unknown") for aggregation.
2. **Read attendeeIndex** — `events/{eventId}/attendeeIndex/{registrantId}`. If it does not exist, this is the first time this registrant has been checked in to any session (new unique attendee).
3. **Update analytics/global** — In the same transaction:
   - **Increment** `totalCheckins` by 1 (using `FieldValue.increment(1)`).
   - **Increment** `totalUniqueAttendees` by 1 only if attendeeIndex did not exist.
   - **Merge** into `regionCounts` and `ministryCounts` (increment the key for this registrant’s region/ministry).
   - **Merge** into `hourlyCheckins`: key is a **hour bucket** (e.g. `YYYY-MM-DD-HH`) derived from `checkedInAt`; value incremented by 1.
   - **Update** `earliestCheckin` if this check-in’s timestamp is earlier than the stored one.
   - Set `lastUpdated` to server timestamp.
4. **Update session summary** — `events/{eventId}/sessions/{sessionId}/analytics/summary`:
   - Increment `attendanceCount` by 1.
   - Merge into `regionCounts` and `ministryCounts` for this session.
   - Set `lastUpdated`.
5. **Create attendeeIndex** — If this is a new unique attendee, create  
   `events/{eventId}/attendeeIndex/{registrantId}` with `firstSession` and `firstCheckinTime`.

**Design notes:**

- **Transaction-based** — Ensures consistency and atomic increments.
- **FieldValue.increment** — Avoids read-modify-write races and keeps writes efficient.
- **Hour bucket** — Enables trend charts (e.g. “Check-In Trend”) without storing per-doc timestamps in analytics.
- **Earliest check-in** — Single document update when the new timestamp is earlier than the stored one.

---

## backfillAnalytics

**Invocation:** Callable Cloud Function (admin-only). Used when:
- Analytics documents are missing or out of date.
- A new event or database is set up and historical attendance already exists.

**Behavior (high level):**

1. **Scan all sessions** — For each session, read the full `attendance` subcollection (or use counts where appropriate).
2. **Reconstruct session summaries** — For each session, compute `attendanceCount`, `regionCounts`, and `ministryCounts` from attendance docs and registrant lookups; write to `sessions/{sessionId}/analytics/summary`.
3. **Reconstruct global analytics** — Aggregate across all sessions:
   - `totalCheckins` = sum of session attendance counts.
   - `totalUniqueAttendees` = count of distinct registrantIds that appear in any attendance collection (or from attendeeIndex).
   - `regionCounts`, `ministryCounts`, `hourlyCheckins` rebuilt from attendance + registrant data.
   - `earliestCheckin` = earliest `checkedInAt` across all attendance docs.
   - `earliestRegistration` = scanned from registrants (e.g. `createdAt` / `registeredAt`).
   - `totalRegistrants` = count of registrants in `events/{eventId}/registrants`.
4. **Write analytics/global** — Single set/merge to `events/{eventId}/analytics/global`.
5. **AttendeeIndex** — Backfill can create or ensure attendeeIndex documents so future onAttendanceCreate behavior remains correct.

**When to run:** After bulk imports, after fixing Functions, or when adding analytics to an event that already has attendance data.

---

## Dashboard Read Pattern

- **watchGlobalAnalytics(eventId)** — Listens to `events/{eventId}/analytics/global`. All global metrics (total registrants, total check-ins, unique attendees, region/ministry top 5, earliest check-in/registration, hourly trend) come from this one document.
- **watchSessionCheckins(eventId)** — Fetches per-session stats from `sessions/*/analytics/summary` (and session metadata). Used for the Session Leaderboard and per-session breakdowns.
- **No collection scans** — The client does not query `attendance` or count documents for the dashboard. All numbers are pre-computed and read from analytics documents, which keeps the dashboard fast and cost-efficient at scale.
