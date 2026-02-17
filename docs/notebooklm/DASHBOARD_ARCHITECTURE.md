# Dashboard Architecture — NLC Dashboard & Wallboard

The NLC dashboard and wallboard are **Flutter Web** screens that display real-time check-in and registration metrics. They read only from pre-aggregated Firestore analytics; no client-side collection scans.

---

## Main Dashboard Structure

**Route:** `/admin/dashboard` (also set as default landing for the app).

**Layout (typical order, configurable):**

| Row / section | Content |
|----------------|---------|
| **Row 1 — Metric tiles** | Three equal-width tiles: **Total Registrants**, **Main Check-In Total**, **Session Check-Ins** (breakout sessions only). Values from `analytics/global` and session summaries; rolling animated counters. |
| **Row 2 — Session leaderboard** | List of sessions with attendance count and progress bar; “Main Check-In” vs breakout sessions. Data from `sessions/*/analytics/summary` plus session metadata. |
| **Row 3 — Top 5** | **Top 5 Regions** and **Top 5 Ministries** (side-by-side cards). Derived from `analytics/global` `regionCounts` and `ministryCounts`. |
| **Row 4 — First 3** | **First 3 Registrations** and **First 3 Check-Ins** (earliest by time). From `analytics/global` (earliestRegistration, earliestCheckin) and supporting queries. |

- **Total Registrants** — From `analytics/global.totalRegistrants` (pre-computed; backfill + onRegistrantCreate).
- **Main Check-In Total** — Count for the main-checkin session from session summaries.
- **Session Check-Ins** — Sum of attendance for all other sessions (breakouts only).

Layout order can be saved per event (e.g. reorder sections); stored in Firestore under event settings.

---

## Wallboard Mode

**Route:** `/admin/wallboard`

**Purpose:** Full-screen, TV or lobby display: large typography, rolling counters, minimal chrome.

**Layout:**

- **Top — Metric tiles** — Same three metrics (Total Registrants, Main Check-In Total, Session Check-Ins) with larger numbers (e.g. 72px), optional glow on value increase, and optional “+X in last update” delta.
- **Center — Session leaderboard** — Same data as main dashboard, centered and prominent.
- **Bottom — Check-In Trend** — Chart from `analytics/global.hourlyCheckins` (hour bucket → count).

Wallboard uses the same real-time streams as the main dashboard; layout order is configurable separately (wallboard layout preference).

---

## Real-Time Streams

The dashboard and wallboard stay up to date via:

| Stream | Source | Purpose |
|--------|--------|---------|
| **watchGlobalAnalytics(eventId)** | `events/{eventId}/analytics/global` | All global metrics (totals, region/ministry, earliest, hourly). |
| **watchSessionCheckins(eventId)** | Session list + `sessions/*/analytics/summary` | Session leaderboard and per-session counts. |

- **No collection scans** — No client-side queries over `attendance` or `registrants` for dashboard numbers.
- **Pre-aggregated only** — All displayed counts and aggregates come from analytics documents written by Cloud Functions.
- **totalCheckins** — Dashboard may overlay live sum of session attendance counts when needed (e.g. consistency with Functions); the primary source remains the global analytics document.

---

## Rolling Counters & UI

- **Metric tiles** use a shared **RollingCounter** widget: animates from 0 on first load and when value increases; snaps when unchanged or decreased.
- **Main dashboard** — 600–1800 ms animation, no glow.
- **Wallboard** — Longer animation, optional glow and “+X in last update” when value increases.

---

## Data Flow Summary

1. User or staff checks in → write to `sessions/{sessionId}/attendance/{registrantId}`.
2. **onAttendanceCreate** runs → updates `analytics/global` and `sessions/*/analytics/summary`.
3. Dashboard/wallboard listeners receive updated analytics docs → UI re-renders with new numbers and optional rolling animation.

All dashboard and wallboard metrics are therefore **read-only views** of server-side aggregates.
