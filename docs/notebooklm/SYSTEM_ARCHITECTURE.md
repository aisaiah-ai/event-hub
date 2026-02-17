# NLC Dashboard & Check-In — System Architecture

## Overview

The NLC (National Leaders Conference) check-in and dashboard system is built as a **Flutter Web** frontend backed by **Firebase**. It uses:

- **Firebase Auth** — Anonymous and authenticated sessions for staff and self-check-in.
- **Firestore** — Single source of truth under a **Pure Session** model (no legacy `/checkins` collection).
- **Cloud Functions** — Server-side analytics aggregation; clients never write to analytics documents.
- **Real-time dashboard streams** — The dashboard and wallboard subscribe only to pre-aggregated analytics documents and session summaries.
- **Wallboard mode** — Full-screen, TV-ready view with rolling counters and large typography for lobbies and projectors.

All attendance is stored under **sessions**. Main Check-In is implemented as a session (e.g. `main-checkin`); there is no separate “conference check-in” collection.

---

## Architecture Diagram (ASCII)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         FLUTTER WEB CLIENT                               │
│  • Dashboard (/admin/dashboard)   • Wallboard (/admin/wallboard)        │
│  • Check-in entry (session picker) • Search (registrant lookup)         │
│  • Reads: analytics/global, sessions/*/analytics/summary                  │
│  • Writes: sessions/{sessionId}/attendance/{registrantId} only           │
└─────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           FIREBASE AUTH                                  │
│  Anonymous (self-check-in)  │  Authenticated (staff/admin)               │
└─────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                            FIRESTORE                                     │
│                                                                          │
│  events/{eventId}                                                        │
│  ├── registrants/{registrantId}         ← Registrant profile & answers   │
│  ├── sessions/{sessionId}              ← Session config (name, order)  │
│  │   └── attendance/{registrantId}     ← ONE DOC PER CHECK-IN (create) │
│  │       └── [onCreate] ──────────────────────────────────────────────►│
│  ├── analytics/global                   ← Pre-aggregated (Functions)    │
│  ├── sessions/{sessionId}/analytics/summary  ← Per-session aggregates   │
│  └── attendeeIndex/{registrantId}       ← Unique-attendee dedup (Funcs) │
└─────────────────────────────────────────────────────────────────────────┘
                                      │
                    attendance doc created (client or staff)
                                      ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    CLOUD FUNCTION: onAttendanceCreate                     │
│  • Transaction: read registrant (region/ministry), attendeeIndex         │
│  • Increment: analytics/global (totalCheckins, regionCounts, etc.)        │
│  • Increment: sessions/{id}/analytics/summary (attendanceCount, etc.)     │
│  • Create attendeeIndex/{registrantId} if new → increment totalUnique     │
│  • Update earliestCheckin / earliestRegistration when earlier            │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Pure Session Model

- **There is NO `/checkins` collection.** Legacy designs used a top-level check-ins collection; this system does not.
- **All attendance** is stored under:
  - **`events/{eventId}/sessions/{sessionId}/attendance/{registrantId}`**
- **Main Check-In** is a session (e.g. `main-checkin`). Checking someone into the main conference is a write to that session’s `attendance` subcollection.
- **Breakout sessions** (e.g. dialogues, workshops) are other sessions with their own `attendance` subcollections.
- One document per registrant per session: idempotent create; no update/delete from the client.

This keeps the data model simple, scalable, and consistent for both main gate and breakout check-ins.
