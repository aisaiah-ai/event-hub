# Dev Journal — Firestore, Check-In, Permissions

**Purpose:** Log every significant change and outcome so we don’t repeat the same fixes. **Before** changing Firestore/check-in/permission logic, **read this file**. **After** any change that touches DB, rules, or check-in, **append a new entry** with date, what was done, and result.

---

## READ THIS FIRST — Don't get confused when building or troubleshooting

**The app uses only the (default) Firestore database.**

- **Code:** `lib/src/config/firestore_config.dart` — `databaseId` returns `'(default)'` with no dev/prod switch. The app always reads and writes to **(default)**.
- **Demo and scripts:** All scripts (bootstrap, seed registrants, gradual check-in, backfill, inspect) must use `"--database=(default)"` so they read/write the same database the app uses.
- **Cloud Functions:** They use `admin.firestore()` (default DB), i.e. **(default)**. Triggers run when docs are created in (default).
- **When troubleshooting:** If the dashboard doesn't update, Top 5 is empty, or the check-in trend is empty, do **not** assume the app might be on event-hub-dev or another DB. The app is fixed to **(default)**. Fix the event-driven path (deploy functions, same DB for scripts) — don't rely on backfill as the normal flow.

---

## How to use

- **Recall:** Read the latest entries below before debugging. If the same error appears, check “What was tried” and “Outcome” so you don’t redo something that already failed.
- **Append:** Add a new `## YYYY-MM-DD` section at the **bottom** with: What changed | What was tried | Outcome / still broken?
- **Firestore rules deploy:** Never say rules are deployed without running `firebase deploy --only firestore:(default)` and verifying in Firebase Console → Firestore → (default) → Rules that the text matches `firestore.rules`. See 2026-02-15 entry.

---

## 2025-02-16 — Firestore config, permissions, journal

**What was done**
- `FirestoreConfig`: switched from `(default)` to **named DB only** — `databaseId` returns `event-hub-dev` (dev) or `event-hub-prod` (prod). `instanceOrNull` uses `FirebaseFirestore.instanceFor(app, databaseId: databaseId)`.
- **CheckInService:** Before writing check-ins, we **read parent first**: for conference check-in we require `events/{eventId}` to exist; for session attendance we require `events/{eventId}/sessions/{sessionId}` to exist. If missing, throw with message pointing to `docs/FIRESTORE_DATA_MODEL.md`.
- **Permission-denied handling:** In `CheckinRepository`, `hasConferenceCheckIn` and `getCheckInStatus` catch `FirebaseException` with `permission-denied` and return false / default status so the UI doesn’t crash; errors still appear in console.
- **Boxed error on web:** In check-in search page, we unwrap “Dart exception thrown from converted Future” (AsyncError + dynamic `.error`) and show a clearer snackbar; fallback message when unwrap fails: “Check-in failed (likely permission-denied). Deploy Firestore rules…”
- **Data model:** Added `scripts/firestore_data_model.dart` (export paths + parent requirements) and `scripts/export_firestore_data_model.sh`; generates `docs/FIRESTORE_DATA_MODEL.md`. Added `docs/FIRESTORE_ERROR_FIRST_STEPS.md` and “Step 0” in `docs/TROUBLESHOOTING_FIRESTORE.md` (check data model before rules).

**What was tried (repeated issues)**
- Writing to `events/{eventId}/checkins/{registrantId}` and `events/.../sessions/.../attendance/...` without ensuring parent docs existed → not-found or confusing errors.
- Using `(default)` database while data/rules live in **event-hub-dev** → permission-denied or “collection doesn’t exist” because the app was talking to the wrong DB.

**Outcome / still broken**
- **event-hub-dev permission issue not fully resolved.** Possible causes (to verify next time):
  1. **Rules not deployed to the named database** — `firebase deploy --only firestore:rules` may deploy to default DB only; need to confirm firebase.json / Firebase Console targets **event-hub-dev** for rules.
  2. **Event or session documents missing in event-hub-dev** — If `events/nlc-2026` or `events/nlc-2026/sessions/main-checkin` (etc.) don’t exist in event-hub-dev, reads can fail or rules that use `get(/databases/.../events/$(eventId))` may behave badly.
  3. **Anonymous auth + rules** — Rules allow read/create for `eventId == 'nlc-2026'` or `selfCheckinEnabled(eventId)`. If `selfCheckinEnabled` relies on `get(events/$(eventId))` and that doc doesn’t exist in event-hub-dev, the rule may deny.

**Next time (recall)**
- Read this journal first.
- Confirm in Firebase Console: **event-hub-dev** database exists; **Firestore Rules** are set for **event-hub-dev** (not only default).
- Run `scripts/export_firestore_data_model.sh` and ensure event + session docs exist in event-hub-dev per `docs/FIRESTORE_DATA_MODEL.md`.
- If still permission-denied: note exact path and database in a new journal entry before changing code again.

**Checked:** `firebase.json` already has `event-hub-dev` in the firestore array with the same `firestore.rules`, so `firebase deploy --only firestore:rules` deploys to both (default) and event-hub-dev. So the likely remaining cause of permission-denied on **event-hub-dev** is **missing data there**: event doc `events/nlc-2026` and session docs (e.g. `events/nlc-2026/sessions/main-checkin`) may exist only in `(default)`. Bootstrap or copy event + sessions into **event-hub-dev** and retry.

---

## 2025-02-16 — Switch to (default) because dev has permission errors

**What was done**
- User said: **event-hub-dev is not working** because of permission errors (and had said so before; we kept making changes without recalling).
- User then asked to **use default**.
- `FirestoreConfig` was changed back to use **(default)** only: `databaseId` returns `'(default)'`; `instanceOrNull` uses `FirebaseFirestore.instanceFor(app: app)` (no databaseId → default database).

**What was tried**
- Using default database so the app works while event-hub-dev permission issues are unresolved.

**Outcome**
- App now targets **(default)** Firestore database. Check-in and reads use (default) where the user’s data/rules currently work.

**Next time (recall)**
- **We are on (default) on purpose.** User said dev (event-hub-dev) is not working due to permission errors. Do **not** switch the app back to event-hub-dev unless those permission errors are fixed (or user asks to use dev again). If someone suggests “use named DB event-hub-dev”, recall: user explicitly said dev is not working and asked to use default; that is logged here.

---

## 2026-02-15 — Plan for check-in write-path / permission-denied errors

**Context**
- Errors show write paths like `events/nlc-2026/checkins/...` and `events/nlc-2026/sessions/gender-ideology-dialogue/attendance`. User asked to confirm the data model for these paths and to write in the journal what we plan to do about these errors.

**Data model (confirmed)**
- **checkins:** Parent that must exist = `events/nlc-2026`. Collections/documents under `checkins/` are created by the app on first write.
- **attendance:** Parent that must exist = `events/nlc-2026/sessions/gender-ideology-dialogue`. Subcollection/docs under `attendance/` are created by the app. Code already does read-before-write (event doc, session doc) and aborts with a clear message if parent is missing.

**Plan when these errors appear again**
1. **Verify parents in (default):** In Firebase Console → Firestore → (default), confirm that **events/nlc-2026** and **events/nlc-2026/sessions/gender-ideology-dialogue** (and any other session IDs in use) exist. If missing → create them or run bootstrap; then retry check-in.
2. **If parents exist and error persists:** Treat as permission/rule issue. Check that Firestore rules are deployed for **(default)** and that they allow create on `checkins/{registrantId}` and `sessions/{sessionId}/attendance/{registrantId}` for the event (e.g. nlc-2026 or selfCheckinEnabled). Do not re-try switching to event-hub-dev unless that DB’s permission issue is fixed (see 2025-02-16 entries).
3. **Use docs:** When debugging, open `docs/FIRESTORE_DATA_MODEL.md` (and its "Verify parents exist" section) and `docs/FIRESTORE_ERROR_FIRST_STEPS.md`; run `scripts/export_firestore_data_model.sh` if paths changed. Add a short journal note after any fix attempt (what was tried, outcome).

**Next time (recall)**
- On check-in path/permission errors: (1) confirm data model and parent docs in (default), (2) then rules, (3) log outcome here. Don’t assume the collection "doesn’t exist" — the model says collections are created by the app; only parent **documents** must pre-exist.

---

## 2026-02-15 — User: "events/nlc-2026/checkins does not exist in the database"

**What was clarified**
- User reported that `events/nlc-2026/checkins` does not exist in the database.
- **The checkins collection is not supposed to exist until the first conference check-in.** Firestore creates a collection when you write the first document to it. No need to create the collection manually.
- **What must exist** is the **event document** `events/nlc-2026`. If that document is missing, run bootstrap; it does not create the checkins collection (that appears on first write).

**What was done**
- Updated `docs/FIRESTORE_DATA_MODEL.md`: (1) noted that the checkins collection does not exist until first write and that only the event doc must exist; (2) added one-time bootstrap command for (default): `cd functions && node scripts/ensure-nlc-event-doc.js "--database=(default)"`.

**Next time (recall)**
- If someone says "checkins doesn't exist": that's normal; only `events/nlc-2026` must exist. If the event doc is missing, run the bootstrap for the correct database.

---

## 2026-02-15 — Logic bug: session mode was writing to /checkins; architecture note

**What was wrong**
- In **session mode** the app was writing to **both** `events/nlc-2026/checkins/{id}` and `events/.../sessions/{sessionId}/attendance/{id}`. Session mode should only write to **session attendance**. Writing to `/checkins` in session mode was a logic bug and caused confusion (wrong path in logs, dual rules needed).

**What was done**
- **Session mode now writes only to** `events/{eventId}/sessions/{sessionId}/attendance/{registrantId}`. Removed the call to `checkInConference` when in session mode. Conference mode still writes to `/checkins` only.
- Error path lines in session mode now show only the attendance path (not checkins).
- Card copy: session mode shows "Tap to check in to this session" (no "Conference and this session").
- **Diagnostic steps** added to `docs/TROUBLESHOOTING_FIRESTORE.md`: "Quick isolation: temporary open rules" (deploy `allow read, write: if true` to isolate rules vs App Check; restore real rules immediately).
- **Architecture note:** Pure session-based (no `/checkins` at all; even "Main Check-In" as a session) is recommended later to remove dual mode and rules duplication. Current state: conference mode = checkins only; session mode = attendance only.

**Next time (recall)**
- Session mode must never write to `/checkins`. Only conference mode writes there. If moving to pure session architecture, remove `/checkins` and use only `sessions/{id}/attendance` (including main-checkin).

---

## 2026-02-15 — Pure session architecture: /checkins removed

**What was done**
- **Removed /checkins entirely.** All check-in writes go to `events/{eventId}/sessions/{sessionId}/attendance/{registrantId}`. Main Check-In is session `main-checkin`.
- **CheckInMode:** Replaced with simple class (eventId, sessionId, displayName). No enum, no conference/session types.
- **CheckInService:** Single `checkIn()` method; removed `checkInConference`. Logs "Writing to: events/.../sessions/.../attendance/..." before write.
- **CheckinRepository:** `isCheckedIn(eventId, sessionId, registrantId)` and `checkIn(...)`. Removed hasConferenceCheckIn, getCheckInStatus, checkInConference.
- **UI:** Result card shows single status (Checked In / Tap to check in). Tap disabled when checked in. No conference/session dual display.
- **Router/Landing:** Search always receives sessionId + sessionName. Main check-in uses sessionId `main-checkin`, displayName `Main Check-In`. No conferenceMode.
- **Firestore rules:** Removed `match /checkins/{registrantId}` block.
- **Bootstrap:** Added `main-checkin` session to `ensure-nlc-event-doc.js` (order 0).
- **Data model:** Removed checkins path from scripts/firestore_data_model.dart; regenerated docs/FIRESTORE_DATA_MODEL.md.
- **Deleted:** lib/src/features/event_checkin/data/registrant_checkin_status.dart.

**Next time (recall)**
- System is pure session. No references to /checkins. Main Check-In = session main-checkin. Deploy rules after change: `firebase deploy --only firestore:(default)` (see below).

---

## 2026-02-15 — Rules “deploy” was not updating (default); must target explicitly

**Lesson (write this down):** I said the rules were deployed. I did not check the Firebase Console. The (default) database was still on the old rules. I was wrong. Always run `firebase deploy --only firestore:(default)` and verify in Console that the Rules tab shows the new rules before saying deploy worked.

**What went wrong**
- We ran `firebase deploy --only firestore:rules` and the CLI reported “Deploy complete!” but the **(default)** database in Firebase Console still had the old rules (deny-all + only events/registrants). No `sessions` or `attendance` rules. Permission-denied continued.
- We did **not** verify in the Console that the rules actually changed. We assumed the deploy updated (default).

**Cause**
- With multiple Firestore databases in `firebase.json`, `firebase deploy --only firestore:rules` does **not** reliably update the **(default)** database. You must target it explicitly.

**Fix**
- Deploy rules to (default) with:  
  `firebase deploy --only firestore:(default)`  
- After any rules deploy, **verify** in Firebase Console → Firestore → (default) → Rules tab that the rules match `firestore.rules`.

**What was done**
- Ran `firebase deploy --only firestore:(default)`; CLI then showed “released rules … to cloud.firestore” and “for (default) database”. Console rules for (default) then matched the repo and check-in worked.
- Added `.cursor/rules/firestore-rules-deploy.mdc` so we always use the explicit target and verify.
- Updated journal recall to use `firestore:(default)`.

**Next time (recall)**
- Never say rules are deployed without targeting the DB the app uses: `firebase deploy --only firestore:(default)`. Always verify in Console that (default) Rules tab shows the updated rules.

---

## 2026-02-15 — Delete extra session docs from DB

**What was done**
- Added `functions/scripts/delete-extra-sessions.js` to remove the four obsolete session documents (opening-plenary, leadership-session-1, mass, closing) from Firestore so they don’t clutter the DB. Bootstrap was already updated to create only `main-checkin`; this script cleans up existing DBs.

**How to run**
- From project root: `cd functions && node scripts/delete-extra-sessions.js "--database=(default)"` (or `--database=event-hub-dev` / `--database=event-hub-prod`). Requires `gcloud auth application-default login` (or GOOGLE_APPLICATION_CREDENTIALS).

**Outcome**
- Run the script once per database where those sessions exist. Any attendance subcollections under those sessions are left as-is; delete in Console if needed.

---

## 2026-02-15 — Dashboard refactor: Pure Session Architecture, analytics, export

**What was done**
- Added analytics data model: `events/{eventId}/analytics/global`, `events/{eventId}/sessions/{sessionId}/analytics/summary`, `events/{eventId}/attendeeIndex/{registrantId}`.
- Cloud Function `onAttendanceCreate` now writes to new analytics docs using `FieldValue.increment(1)`; creates attendeeIndex for first-time attendees.
- Dashboard reads only from analytics docs (no attendance scan). Redesigned with metric cards, session table, aggregation dropdown, export button.
- CSV/Excel export: raw attendance (scans collections) and aggregated (from analytics). Batched pagination for raw export.
- Firestore rules: `analytics/*`, `sessions/*/analytics/*`, `attendeeIndex/*` — read if auth, write if false (Cloud Functions only).
- Callable `backfillAnalytics` for one-time migration of existing attendance into analytics docs.

**What was tried**
- Production-grade dashboard for 3,000+ attendees; scalable counters; no client-side aggregation.

**Outcome / still broken**
- Implementation complete. Deploy Cloud Functions and Firestore rules. Run `backfillAnalytics` for existing events with attendance data.

**Next time (recall)**
- Dashboard uses analytics docs only. If counts show 0 for events with attendance, run `backfillAnalytics` callable (admin only).

---

## 2026-02-15 — Analytics v2: Top Regions, Ministries, Timeline, Aggregation

**What was done**
- Extended `analytics/global` schema: `earliestCheckin`, `earliestRegistration`, `regionCounts`, `ministryCounts`, `hourlyCheckins` (YYYY-MM-DD-HH).
- Extended `sessions/*/analytics/summary`: `regionCounts`, `ministryCounts`.
- Cloud Function `onAttendanceCreate`: reads registrant for region/ministry; updates regionCounts, ministryCounts, hourlyCheckins; updates earliestCheckin when earlier.
- `backfillAnalytics` callable: scans registrants for earliestRegistration; rebuilds all new fields.
- Dashboard: Top 5 Regions, Top 5 Ministries (ranked list + horizontal bar); Timeline Intelligence (earliest check-in, earliest registration, peak hour); perDay aggregation uses hourlyCheckins when available.
- Export: Excel now has 6 sheets (Summary, Regions, Ministries, Hourly, Sessions, Raw); aggregated CSV includes timeline metrics for entireEvent.

**What was tried**
- Production analytics upgrade without attendance scans on dashboard load.

**Outcome / still broken**
- Implementation complete. Deploy Cloud Functions. Run `backfillAnalytics` to populate new fields for existing data.

**Next time (recall)**
- Analytics v2 adds region/ministry/hourly. Run backfillAnalytics after deploy to populate.

---

## 2026-02-16 — Firestore rules deploy: fix root cause (explicit database targeting)

**What was wrong**
- `firebase deploy --only firestore:rules` does **not** reliably update rules when multiple Firestore databases exist in `firebase.json`. CLI may report success but Console shows old rules. User had to paste manually every time.

**What was done**
- **Deploy scripts now target each database explicitly:**
  - `firebase deploy --only 'firestore:(default)'`
  - `firebase deploy --only 'firestore:event-hub-dev'`
  - `firebase deploy --only 'firestore:event-hub-prod'` (for prod)
- **Updated scripts:**
  - `deploy-firestore-dev.sh`: runs both (default) and event-hub-dev explicitly
  - `deploy-firestore-prod.sh`: runs all three databases explicitly
  - `deploy-firestore-rules-event-hub-dev.sh`: uses `firestore:event-hub-dev` instead of `firestore:rules --config firebase.dev.json`
- `.cursor/rules/firestore-rules-deploy.mdc`: documents correct deploy; manual paste is fallback only.
- `print-firestore-rules-for-paste.sh`: still available for auth/network failures.

**Outcome**
- Ran `./scripts/deploy-firestore-dev.sh`; both (default) and event-hub-dev reported "released rules" and "deployed indexes... successfully for X database". Rules now deploy reliably via CLI.

**Next time (recall)**
- Use `./scripts/deploy-firestore-dev.sh` (or prod script). Do not rely on `firebase deploy --only firestore:rules` alone; it can skip databases. Each database must be targeted explicitly.

---

## 2026-02-16 — Dashboard showed 0: wrong eventId (nlc-2025 vs nlc-2026)

**What was wrong**
- Dashboard queried `events/nlc-2025/analytics/global` and `events/nlc-2025/sessions` — 0 sessions, analytics doc doesn't exist.
- All seeded data (registrants, attendance, analytics) lives in **nlc-2026**.

**Root cause**
- `app_router.dart` had `const defaultEventId = 'nlc-2025'`. Admin routes (dashboard, home, etc.) use this when no `eventId` query param is passed.

**Fix**
- Changed `defaultEventId` to `'nlc-2026'` so dashboard and admin screens target the correct event.

**Next time (recall)**
- defaultEventId must match the event where data exists (nlc-2026). Check logs for `eventId=` when debugging "0 results" — wrong eventId is a common cause.

---

## 2026-02-15 — Analytics v2.2 — Visual Hierarchy & Executive UI Upgrade

**What was done**
- **CheckinDashboardScreen** — Executive-grade visual refinement: metric cards with gradient, glow, 38px values, "Live Event Metrics" section header; Top 5 Regions/Ministries with % of total, 8px gold bars, tabular numbers; Timeline Intelligence with icons, dividers, Peak Activity + check-in count; Session Attendance table as dark card with gold progress bars and row hover; control panel (aggregation + export) in styled container; section headers with gold accent lines; responsive layout (row on desktop, stacked on narrow).
- **EventPageScaffold** — Added optional `bodyMaxWidth` (1200 for dashboard) and `overlayOpacity` (0.55 for readability) for NLC background.
- **Spacing** — 32px between major sections, 24px horizontal/vertical, consistent card padding.
- **Animations** — Metric count-up (600ms), progress bar tween (600ms), row hover transition.

**What was tried**
- Elevating dashboard from functional to professional conference control center; improving readability for projector display.

**Outcome / still broken**
- UI-only changes. No Firestore, Cloud Functions, aggregation logic, or export logic modified. Dashboard now presents as executive-ready event intelligence UI.

**Next time (recall)**
- Dashboard uses bodyMaxWidth: 1200 and overlayOpacity: 0.55 when eventSlug is NLC.

---

## 2026-02-15 — Analytics v3 — Executive Light Theme + Timeline Graph Redesign

**What was done**
- **Design direction:** Switched from dark operational console to light executive analytics dashboard.
- **EventPageScaffold:** Added `useLightBackground: true` — uses `Color(0xFFF5F7FA)` gradient, no image/overlay.
- **Header:** Redesigned with event title, optional venue, Live indicator (green pulse), aggregation dropdown, overflow menu (☰) replacing standalone Export. Menu: Export Summary (Excel), Export Raw (CSV), Export Aggregated (CSV).
- **Metric cards:** White cards with subtext (“Across all sessions”, “Including repeat session scans”), 40px value, 16px label, 14px muted subtext, subtle divider.
- **Top 5 Regions/Ministries:** Light theme, blue progress bars (`Color(0xFF2E6BE6)`), gold reserved for highlights.
- **Registration vs Check-In separation:** Two cards — “Registration Overview” (earliest registration) and “Check-In Activity” (peak hour, peak count, line graph from `hourlyCheckins`).
- **Check-In line graph:** Custom `CustomPainter` from `hourlyCheckins` — gold line, soft fill below, X=time Y=count. No new dependencies.
- **Session Attendance:** White card, gold progress bars, subtext “X attendees · Y% of unique attendees”, dividers between rows.
- **Responsive:** Row when width ≥1000px, Column when smaller.

**What was tried**
- Professional corporate dashboard, presentation-ready, clear separation of registration vs attendance.

**Outcome / still broken**
- UI/UX only. No Firestore, Cloud Functions, aggregation, or export logic changes.

**Next time (recall)**
- Dashboard uses `useLightBackground: true` and custom header. Optional `eventVenue` param for venue line.

---

## 2026-02-15 — Analytics v4 — Wallboard Mode + Live Rolling Counters

**What was done**
- **WallboardScreen** — New full-screen display mode at `/admin/wallboard?eventId=...&eventTitle=...&eventVenue=...` for projectors, LED walls, lobby monitors.
- **No admin controls** — No export menu, aggregation dropdown, back button, or nav drawer. Header: event title + venue, Live indicator (green pulse), Last Updated timestamp.
- **Rolling counter animation** — `_RollingCounter` uses `TweenAnimationBuilder<int>` (600ms) when values increase. No jump on unchanged or decrease.
- **Large metric cards** — Total Unique Attendees, Total Check-Ins, Peak Session. 72px/56px typography (responsive), white cards, subtle shadow.
- **Large check-in trend graph** — 350px height, 4px stroke, gold line + fill, pulse dot at latest point.
- **Session leaderboard** — Sessions sorted by attendance, horizontal bars, "LIVE" badge on top session.
- **"Enter Wallboard Mode" button** — In dashboard app bar, navigates to wallboard route.
- **Waiting hint** — After 60s with no update, shows "Waiting for updates…".
- **Data source** — Same as dashboard: analytics/global + sessions/*/analytics/summary. No attendance scan.

**What was tried**
- Event command center display; high visibility for projector/lobby use.

**Outcome / still broken**
- UI only. No Firestore, Cloud Functions, or export changes.

**Next time (recall)**
- Wallboard at `/admin/wallboard`. Access via dashboard "Wallboard Mode" button.

---

## 2026-02-15 — Analytics v3.1 — Executive Refinement & Trend Emphasis

**What was done**
- **Check-in Dashboard (UI refinement only):**
  - Removed aggregation dropdown; dashboard scoped to Entire Event.
  - Header: back link, centered "CHECK-IN DASHBOARD", Live, Last Updated, Wallboard Mode, overflow (export).
  - Metric cards: Total Unique Attendees, Total Check-Ins, Peak Session (label + session name + "N attendees").
  - Check-In Trend promoted to primary: full-width card, 350px height, "Hourly Attendance Progress" subtitle, gold 4px line, fill 0.12, highlight dot at latest point, subtle Y-axis grid.
  - Top 5 Regions & Ministries: blue progress bars 8px, rounded, percentage right-aligned, dividers between entries.
  - Registration Overview | Check-In Activity: Earliest Registration (Date + Time); Peak Hour with mini line chart.
  - Session Leaderboard: always visible, gold bar for top, light gold for others, LIVE badge on top, hover highlight, 16px spacing.
  - Overlay opacity 0.6 (was 0.45) for better card contrast.
- **Wallboard:** Same overlay 0.6, added "Hourly Attendance Progress" subtitle to chart.
- No Firestore, Cloud Functions, export, or analytics logic changes.

**What was tried**
- Executive dashboard refinement from design screenshots; cleaner visual hierarchy and trend emphasis.

**Outcome / still broken**
- UI only. Ready for leadership presentation.

**Next time (recall)**
- Analytics v3.1 layout: metrics → trend → regions/ministries → reg/activity → leaderboard. No aggregation dropdown.

---

## 2026-02-15 — Reorderable cards for dashboard and wallboard

**What was done**
- **Layout service:** `DashboardLayoutService` reads/writes `events/{eventId}/settings/layouts` with `dashboardOrder` and `wallboardOrder` arrays.
- **Dashboard:** "Edit layout" / "Done" button; ReorderableListView with drag handles. Five sections: metrics, checkInTrend, top5, registrationActivity, sessionLeaderboard.
- **Wallboard:** "Edit layout" / "Done" in header; same reorder UI. Three sections: metrics, graph, leaderboard.
- **Firestore rules:** Added `match /settings/{docId}` — staff read/write.

**What was tried**
- Let users rearrange cards/visuals; persist to Firestore so layout is shared per event.

**Outcome / still broken**
- Layout preferences saved per event. Dashboard and wallboard have independent layouts. Deploy rules: `firebase deploy --only firestore:rules`.

**Next time (recall)**
- Layout stored at `events/{eventId}/settings/layouts`. Staff-only write.

---

## 2026-02-15 — Layout persistence: SharedPreferences fallback when Firestore permission-denied

**What was done**
- `DashboardLayoutService`: added SharedPreferences fallback. On save, if Firestore returns permission-denied, write to SharedPreferences. On watch, if Firestore errors with permission-denied, emit layout from SharedPreferences instead of failing.
- `checkin_dashboard_screen` and `wallboard_screen`: stopped clearing `_localDashboardOrder` / `_localWallboardOrder` when exiting edit mode. Keeps reordered layout visible after "Done".
- Added `shared_preferences` to pubspec.yaml.

**What was tried**
- Fix layout reverting to default after exiting edit. Cause: Firestore write to `events/{eventId}/settings/layouts` fails with permission-denied for anonymous users; Firestore read/watch also fails; no fallback meant layout was lost.

**Outcome**
- Layout persists per device via SharedPreferences when Firestore access is denied. Reorder survives edit-mode exit and app restart. Once staff auth is in place, Firestore will be used and layouts shared per event.

**Next time (recall)**
- `events/.../settings` requires staff. Anonymous users use SharedPreferences; layout is local-only until staff auth.

---

## 2026-02-15 — Check-in counts from attendance (not analytics docs)

**What was done**
- `CheckinAnalyticsService`: `fetchSessionStats` now counts directly from `events/{eventId}/sessions/{sessionId}/attendance` via `collection.count().get()` instead of reading `sessions/.../analytics/summary`.
- Global total check-ins: `getGlobalAnalytics` and `watchGlobalAnalytics` override `totalCheckins` with the sum of live session counts (from attendance). Region/ministry/hourly still from analytics doc when available.
- Added `_countAttendance`, `_totalCheckinsFromAttendance`, and `GlobalAnalytics.copyWith`.

**What was tried**
- Fix incorrect check-in numbers on dashboard/wallboard. Root cause: analytics docs (`analytics/global`, `sessions/.../analytics/summary`) are written by Cloud Functions; if Functions aren’t deployed or fail, counts were wrong or stale.

**Outcome**
- Counts now come from the attendance collection and are accurate regardless of Cloud Functions.

**Next time (recall)**
- Dashboard/wallboard check-in counts use attendance `count()` aggregation, not analytics docs.

---

## 2026-02-15 — NLC Dashboard v4 — Structural Redesign & Operational Focus

**What was done**
- Renamed "Check-In Dashboard" → "NLC Dashboard" everywhere (headers, routes, breadcrumbs).
- Restructured metric tiles: Total Registrants, Main Check-In Total (Main Conference Entry), Session Check-Ins (Breakout Sessions Only). Equal size, icons on left.
- Reordered main dashboard: Row 1 metric tiles, Row 2 Session Leaderboard (centerpiece), Row 3 Top 5 Regions & Ministries (equal height via IntrinsicHeight + Spacer), Row 4 First 3 Registrations & First 3 Check-Ins.
- Removed Registration Overview, Check-In Activity, Check-In Trend from main dashboard.
- Restructured wallboard: metrics → leaderboard → Check-In Trend chart (350–380px). Removed Top 5 Regions/Ministries.
- Session leaderboard: LIVE badge on active session only (using `SessionCheckinStat.isActive`); gold bar for top session, lighter for others.
- Added `SessionCheckinStat.isActive` from session docs; `getTop3EarliestRegistrants`, `getTop3EarliestCheckins`, `watchFirst3Data` for First 3 cards.
- Removed dead code: `_CheckInTrendSection`, `_RegistrationAndCheckInRow`, `_RegistrationOverviewCard`, `_CheckInActivityCard`, `_CheckInLineChart`, `_DashboardFlChart` from dashboard; fl_chart import no longer needed in dashboard.
- Max width 1200px (dashboard) / 1600 (wallboard), overlay opacity 0.65, 32px vertical spacing.

**What was tried**
- Turn product surface into an NLC Executive Intelligence Dashboard, not an admin check-in screen. Layout + UI restructuring only; no Firestore schema, Cloud Functions, or stream changes.

**Outcome**
- Dashboard feels like an event command center: leadership-ready, clear separation of registration vs attendance, operationally focused.

**Next time (recall)**
- First 3 Registrations queries `registrants` with `orderBy('createdAt', ascending)`. If missing index, add composite index on `registrants` for `createdAt` ASC.

---

R## 2026-02-16 — NLC Dashboard v4.1 — Tile Width Alignment & Structural Refinement

**What was done**
- Wrapped dashboard and wallboard body in a centered constrained layout: `Center` → `ConstrainedBox(maxWidth: 1200)` → `Padding(horizontal: 24)` → `Column(crossAxisAlignment: CrossAxisAlignment.stretch)` so all sections share the same max width and horizontal alignment.
- Rebuilt top metric tile row: replaced fixed-width tiles and `Wrap`-only layout with `LayoutBuilder`; when `maxWidth >= 900` use `Row` with three `Expanded` children and `SizedBox(width: 24)` between; when `< 900` use `Wrap` for stacking. Applied to both main dashboard (`_MetricsTiles`) and wallboard (`_WallboardMetrics`).
- Metric tile structure: icon (28 main / 32 wallboard) + title row, 1px divider (`Container` with `Colors.black.withOpacity(0.08)`), large number (48 main / 72 wallboard), subtext 14px muted. Tile height: main 170px (`SizedBox(height: 170)`), wallboard 200px. Removed fixed `width`/`height` and `IntrinsicHeight` from tiles.
- Tile decoration: added `_metricTileDecoration()` / `_wbMetricTileDecoration()` (white, 16px radius, `BoxShadow` 0.08 opacity, blur 20, offset (0, 8)) for metric tiles only; other cards keep existing `_lightCardDecoration` / `_wbCardDecoration`.
- Session Leaderboard: wrapped in `SizedBox(width: double.infinity)` on both dashboard and wallboard so it spans the same width as the tile row.
- Removed `IntrinsicHeight` from Top 5 Row (dashboard); kept `Row` with two `Expanded` cards.
- Wallboard: same 1200px constrained container and 24px horizontal padding; `_RollingCounter` skips label and top spacing when `label.isEmpty` so tile layout stays clean.

**What was tried**
- Fix top metric tiles not spanning the same total width as the Session Leaderboard and improve executive visual proportion (equal-width tiles, consistent alignment, no floating sections).

**Outcome**
- Three equal-width metric tiles align with Session Leaderboard; full-width alignment and responsive Wrap on narrow screens; consistent layout between main dashboard and wallboard except scale (tile height and number size).

**Next time (recall)**
- Layout-only; no Firestore, Cloud Functions, analytics, or export logic changed.

---

## 2026-02-16 — Total Registrants in pre-computed analytics

**What was done**
- Added `totalRegistrants` to `GlobalAnalytics` (`lib/src/models/analytics_aggregates.dart`): field, `copyWith`, `fromFirestore` (default 0).
- Cloud Functions: `backfillAnalytics` now writes `totalRegistrants: registrantsSnap.size` to `events/{eventId}/analytics/global`. `onRegistrantCreate` now also updates `analytics/global` with `totalRegistrants: FieldValue.increment(1)` and `lastUpdated`.
- Dashboard and wallboard no longer use `watchRegistrantCount` (no separate registrants collection count query). They use `global.totalRegistrants` from the same `analytics/global` stream as other metrics.

**What was tried**
- Total Registrants was delayed because it used a separate live count on `events/{eventId}/registrants` (count aggregation); moving it into pre-computed analytics so it appears with the rest of the dashboard data.

**Outcome**
- Total Registrants is read from `analytics/global` with no extra query. For existing events, run `backfillAnalytics` once to populate `totalRegistrants`; new registrants increment it via `onRegistrantCreate`.

**Next time (recall)**
- If registrants are deleted, `totalRegistrants` will be high until next backfill (no onDelete decrement).

---

## 2026-02-16 — Rolling Animated Metrics (Dashboard + Wallboard)

**What was done**
- Implemented reusable `RollingCounter` widget in `lib/src/widgets/rolling_counter.dart`: `TweenAnimationBuilder<int>` + `IntTween`, no `AnimationController` / `TickerProvider`. Animates on initial load (0 → value) and when value increases; snaps instantly when value unchanged or decreased. Optional glow (green) and optional “+X in last update” delta (fade in, visible 2s, fade out). Uses `NumberFormat.decimalPattern()` for display.
- Main dashboard (`checkin_dashboard_screen.dart`): all three metric tiles (Total Registrants, Main Check-In Total, Session Check-Ins) use `RollingCounter` with 600ms duration, no glow, professional style (42px, w700).
- Wallboard (`wallboard_screen.dart`): removed private `_RollingCounter`; all three metric tiles use shared `RollingCounter` with 800ms duration, `enableGlow: true`, `showDelta: true`, 72px w800 typography and gold shadow. Subtext rendered in tile below counter.

**What was tried**
- UI-only enhancement for rolling animated counters; no Firestore, Cloud Functions, analytics, or streams changed.

**Outcome**
- Dashboard: clean animated metrics, smooth count-up on load, no jitter. Wallboard: strong animated presence, glow on increase, “+X in last update” when value goes up, TV-ready.

**Next time (recall)**
- Rolling counters are UI-only; delta is computed locally (old vs new value).

---

## 2026-02-16 — Top 5 Regions / Ministries: seed mapping only, no fake data

**What was done**
- **Seed** (`lib/src/tools/seed_nlc_registrants.dart`): Added column mapping so CSV headers map to the keys the Cloud Function expects: `region`, `regionMembership`, `ministry`, `ministryMembership` (e.g. `region_membership` → `regionMembership`, `ministry_membership` → `ministryMembership`). **No** synthetic/demo values: region and ministry are stored only when the CSV actually has those columns; otherwise they stay absent and the function correctly uses "Unknown".
- Removed an earlier mistake: code that assigned fake `_demoRegions` / `_demoMinistries` when the CSV lacked region/ministry was reverted so numbers always come from registrant data.
- **Docs** (`docs/demo.md`): Updated to say Top 5 reflects real data only; CSV must include region/ministry (or equivalent); re-seed after adding those columns.

**What was tried**
- Fixing "Top 5 Regions and Top 5 Ministries not updating" when check-ins run. Cause: registrant docs had no `region`/`ministry` (or aliases), so the Cloud Function (`onAttendanceCreate`) always saw "Unknown". Fix is to ensure the seed writes those fields when the CSV provides them — not to invent data.

**Outcome**
- Top 5 will update with real distribution only when the registrant export/CSV includes region and ministry. If the CSV has no such columns, counts correctly show "Unknown"; no fabricated counts.

**Next time (recall)**
- Do not add sample/demo region or ministry values to the seed. Data must come from the registrant (CSV). For Top 5 to show variety, the CSV must have region/ministry columns and the seed maps them via `_toSchemaKey`.

---

## 2026-02-16 — Top 5 Regions/Ministries: read from registration (registrant doc), more key aliases

**What was done**
- **Cloud Function** (`functions/src/index.ts`): `getString` now tries additional keys so region/ministry are found regardless of how registration stores them: `"Region"` and `"Ministry"` (capitalized) in addition to `region`, `regionMembership`, `ministry`, `ministryMembership`. Applied in `onAttendanceCreate`, `onRegistrantCheckIn`, and backfill loop. Region/ministry are read from the **registrant** doc (`events/{eventId}/registrants/{id}`) at check-in time (top-level, `profile`, or `answers`).
- **Backfill script** (`functions/scripts/backfill-analytics-dev.js`): Same key aliases for region/ministry so backfill stays in sync.
- **Docs** (`docs/demo.md`): Added troubleshooting bullet for "Top 5 Regions / Ministries not updating": ensure registrant docs have region/ministry under one of the supported keys, Cloud Functions deployed, app and Functions use same DB (default); backfill if needed.

**What was tried**
- User said regions and ministries are from the registration database but they're not updating. The function already reads from the registrant doc; possible causes: (1) registration stores under different key names (e.g. "Region"), (2) Functions not deployed or wrong DB. Added key aliases and documented the flow.

**Outcome**
- Top 5 will update when: registrant docs in (default) have region/ministry in profile or answers under `region`/`regionMembership`/`Region` or `ministry`/`ministryMembership`/`Ministry`; Cloud Functions are deployed; each check-in triggers the function which reads the registrant and updates `analytics/global`.

**Next time (recall)**
- Top 5 Regions/Ministries source = registrant doc at check-in. If still not updating, verify in Firebase Console (default DB) that `events/nlc-2026/registrants/{id}` has `answers.region`/`answers.ministry` (or profile/top-level) and that `events/nlc-2026/analytics/global` has `regionCounts`/`ministryCounts` after a check-in.

---

## 2026-02-16 — Top 5 Regions and Check-In Trend not updating

**What was done**
- Bootstrap script `ensure-nlc-event-doc.js` default database changed from `event-hub-dev` to `(default)` so that running it without `--database=` creates event, sessions, stats/overview, and **analytics/global** in the same DB the app uses. App reads Top 5 and trend from `events/nlc-2026/analytics/global` only.
- Documented below why Top 5 and trend can stay empty and how to fix.

**What was tried**
- User reported Top 5 regions and check-in trend still not updating. Cause: dashboard reads from `analytics/global`; that doc is updated **only** when an **attendance** doc is created (Cloud Function `onAttendanceCreate`). If bootstrap was run for a different DB (e.g. event-hub-dev) or Cloud Functions were not deployed, the app never sees updates.

**Outcome / still broken**
- If Top 5 or Check-In Trend stay empty: (1) **Deploy Cloud Functions** so `onAttendanceCreate` runs when attendance docs are created: `cd functions && npm run build && firebase deploy --only functions`. (2) **Create analytics/global in (default)** by running bootstrap for the app’s DB: `cd functions && node scripts/ensure-nlc-event-doc.js` (no arg = (default) now). (3) **Do at least one check-in** that creates an attendance doc (search → check in to main-checkin, or session check-in). (4) **Verify** in (default): `cd functions && node scripts/inspect-analytics-global.js "--database=(default)" --dev`. You should see `regionCounts`, `ministryCounts`, and `hourlyCheckins` with at least one entry after a check-in.

**Next time (recall)**
- Top 5 Regions and Check-In Trend are filled **only** by the Cloud Function `onAttendanceCreate` (trigger: `events/{eventId}/sessions/{sessionId}/attendance/{registrantId}` onCreate). App does **not** update analytics/global; the function does. Ensure functions are deployed and app + scripts use the same DB (default).

---

## 2026-02-17 — App default DB: use FirebaseFirestore.instance so Top 5 / trend show

**What was done**
- `FirestoreConfig.instanceOrNull` now uses `FirebaseFirestore.instance` instead of `Firestore.instanceFor(app, databaseId: '(default)')` so the app uses the same default Firestore database that Node scripts use when they call `getFirestore()` with no args. Demo doc: added step 5 (verify with inspect script, then hard refresh/restart app) and expanded troubleshooting for empty Top 5 / trend.

**What was tried**
- User reported backfill ran but Top 5 and Check-In Trend still not showing. Possible cause: app and scripts were not guaranteed to use the same default DB when one passed `databaseId: '(default)'` and the other used `getFirestore()`.

**Outcome / still broken**
- After this change, **restart the app** so it picks up the new Firestore instance. Then run demo + backfill; run `inspect-analytics-global.js` to confirm keys; hard refresh or restart again if needed.

**Next time (recall)**
- App uses `FirebaseFirestore.instance` for default DB. If Top 5 / trend stay empty after backfill, verify doc in Console (default DB), run inspect script, then restart the app.

---

## 2026-02-18 — NLC 2026 — Session Selection UI Premium Refinement

**What was done**
- UI/UX refinement only (no business logic, routing, or Firestore changes).
- **Header:** Centered column layout; logo ~10% larger (212px); 20px gap; "NATIONAL LEADERS CONFERENCE" 28px semi-bold; "2026" 22px bold gold (#D4A017).
- **Conference Check-In card:** Elevated as primary action — 8px taller (vertical padding 24px), 1px gold border (rgba 0.35), subtle gold gradient overlay, QR icon 15% larger with soft gold glow (blur 12px), subtext "Main Event Entry" 13px 70% opacity.
- **Breakout section:** "Select your session" replaced with "BREAKOUT SESSIONS" (uppercase, 16px semi-bold), subtle gold divider above (40% opacity), 24px above / 16px below spacing.
- **Session cards:** Optional LIVE badge (green #1E7F43, 11px, when `session.isActive == true`); 16px border radius; 20px padding; 16px between cards; max body width 480px.
- **Hover/tap:** AnimatedContainer 150ms; hover: elevation + translateY(-2px), shadow increase (rgba 0.25, blur 16); tap: gold ripple, scale 0.98.
- **Footer:** Two lines "Powered by AISaiah" / "CFC Digital Integration", 12px, 60% opacity.
- **Polish:** FadeTransition on page load (300ms).

**What was tried**
- Achieving premium, production-grade feel for NLC 2026 Self Check-In Session Selection while keeping structure and branding.

**Outcome / still broken**
- Implemented; no Firestore or check-in flow changes. Visual only.

**Next time (recall)**
- Session Selection UI lives in `lib/src/features/event_checkin/presentation/checkin_session_picker_page.dart`; theme in `theme/checkin_theme.dart`; header/footer in `widgets/conference_header.dart`, `widgets/footer_credits.dart`.

---

## 2026-02-18 — NLC 2026 — Empowered to Serve Color System Refactor

**What was done**
- Introduced centralized NLC theme: `lib/src/core/theme/nlc_theme.dart` with [NlcColors]:
  - primaryBlue `#1F3A5F`, secondaryBlue `#27496D`, accentGold `#D4A84F`, softGold `#E6C27A`, ivory `#F4F1EA`, slate `#2E2E2E`, mutedText `#6B7280`, successGreen `#2E7D32`.
- Replaced dark navy + bright gold with deep heritage blue, muted parchment/ivory, and warm brushed gold. No hardcoded colors in NLC flows; all use NlcColors or AppColors (which delegate to NlcColors).
- **Dashboard:** Metric cards and section cards → ivory; text → slate, subtext → mutedText; accent dividers and icons → accentGold; progress bars → active/top accentGold, others secondaryBlue; LIVE → successGreen.
- **Wallboard:** Same palette; card backgrounds ivory; chart line accentGold; leaderboard top bar accentGold, others secondaryBlue.
- **Session check-in / picker:** Card backgrounds ivory; overlay primaryBlue 0.55–0.65 over mosaic; header “National Leaders Conference” → ivory, “2026” → accentGold; thin divider softGold; QR tile accentGold, icon primaryBlue; LIVE badge successGreen.
- **Charts:** Line stroke accentGold, fill accentGold 0.12; axis labels mutedText; grid secondaryBlue 0.15.
- **Scaffold:** Default primary primaryBlue; NLC overlay primaryBlue (not black); light executive background ivory.

**What was tried**
- Aligning entire NLC Conference UI with Empowered to Serve branding: mature, confident, leadership-level, mobile readable, no over-saturation.

**Outcome / still broken**
- Implemented. Visual coherence and contrast improved; no business-logic or Firestore changes.

**Next time (recall)**
- Single source of truth: `lib/src/core/theme/nlc_theme.dart`. Use only NlcColors (or AppColors in check-in theme) for NLC screens; no `Color(0xFF…)` in event_checkin, dashboard, wallboard, or event scaffold for NLC.

---

## 2026-02-18 — NLC Theme vNext — Blue Logo Palette Refactor

**What was done**
- Replaced gold accent theme with blue-first "Empowered to Serve" palette.
- Added `lib/src/theme/nlc_palette.dart`: brandBlue, brandBlueDark, brandBlueSoft, cream, cream2, ink, muted, border, shadow, success, danger.
- Added `lib/src/theme/nlc_decorations.dart`: nlcCardDecoration(), nlcPanelDecoration(), nlcPillDecoration().
- Updated `NlcColors` and `AppColors` to delegate to NlcPalette; removed all gold constants.
- EventPageScaffold: overlay default 0.55, overlayTint default brandBlueDark; blue gradient overlay (top darker → bottom lighter).
- Main check-in: Scan QR → brandBlue bg + cream text; Search/Manual/Recent → cream2 surfaces, blue icon accents; MAIN CHECK-IN pill → brandBlue.
- Search results: status chips → success (checked in) / brandBlueSoft outline (not checked in); card borders subtle blue.
- Dashboard: metric tiles, chart line, LIVE badge → brandBlue; Top 5 bars and session leaderboard → brandBlue.
- Registrant result cards, confirmation modal, footer, subtitle, location block → palette tokens.
- CheckinTokens (admin check-in screen) → NlcPalette.

**What was tried**
- Removing all gold/yellow accents; achieving consistent blue/cream palette across check-in, search, dashboard, wallboard.

**Outcome / still broken**
- Implemented. No Firestore, routes, or data model changes. UI + theme refactor only.

**Next time (recall)**
- Use only NlcPalette (or AppColors/NlcColors) in check-in flows; no hardcoded colors except in nlc_palette.dart.

---

## 2026-02-18 — NLC Check-In vNext — Immersive Blue Portal Layout

**What was done**
- Main Check-In page (isMainCheckIn) refactored to immersive blue portal layout. UI only; no Firestore, check-in, or navigation logic changed.
- **EventPageScaffold:** Added `useRadialOverlay`. When true (main-checkin route), overlay is RadialGradient (center top, radius 0.8): brandBlueSoft 0.25 → brandBlueDark. Removes strong linear gradient for a subtle top glow.
- **EventCheckinEntryPage:** Passes `useRadialOverlay: widget.isMainCheckIn` and `bodyMaxWidth: 480` when isMainCheckIn.
- **CheckinLandingPage (immersive branch):** Centered column max 480px, 24px padding. Order: logo (150px, white glow, no card) → 24 → title "Event Check-In" (Playfair 30, cream) → subtitle (14px, cream 0.7) → thin cream divider 60×1 → 32 → glass primary QR card → 16 → Search card → 16 → Manual card → 32 → divider → location (simple list) → 16 → recent check-ins (simple list) → footer. Removed MAIN CHECK-IN pill, SubtitleBar, and heavy card outlines.
- **Primary QR card:** Glass style: 76px height, radius 17, gradient brandBlueSoft 0.7 / brandBlueDark 0.8, 1px cream border 0.25, subtle shadow; QR icon in darker blue rounded square, cream text; hover scale 1.02, press scale 0.98 (web hover).
- **Secondary cards:** cream2, 16 radius, 20 padding, icon left / title+subtitle / chevron right; brandBlueDark and muted typography.
- **Location & recent:** Simple list style at bottom; no heavy cards; cream/muted text.
- **Animations:** Logo fade-in 300ms; cards slide up with 250ms stagger (SlideTransition + Interval); primary card has custom hover/press scale.

**What was tried**
- Making main check-in feel premium, immersive, minimal, and conference-branded instead of "card on background."

**Outcome / still broken**
- Implemented. Layout and styling only.

**Next time (recall)**
- Immersive layout is used only when CheckinLandingPage is built with isMainCheckIn (main-checkin route). Other check-in flows (session picker, session check-in) unchanged.

---

## 2026-02-18 — Session Allocation + Capacity Enforcement + Confirmation Pass

**What was done**
- **Data model (docs/FIRESTORE_DATA_MODEL.md):** Sessions schema extended with `capacity`, `attendanceCount`, `colorHex`, `isMain`, `status`; attendance doc with `createdAt`, `source`; new path `events/{eventId}/sessionRegistrations/{registrantId}`.
- **Session model:** Added `capacity`, `attendanceCount`, `colorHex`, `isMain`, `status` (open/closed), `remainingSeats`, `isAvailable`.
- **Services:** `SessionCatalogService` (list/watch sessions, availability labels), `SessionRegistrationService` (get/watch pre-registered sessionIds), `CheckinOrchestratorService` (ensureMainCheckIn + checkInToTargetSession with Firestore transaction; capacity gating; idempotency).
- **UI:** `RegistrantResolvedScreen` (Continue → load sessionRegistrations → main/single/multi/empty flow), `SessionSelectionScreen` (session cards with capacity/status, confirm modal, orchestrator), `CheckinConfirmationScreen` (receipt, Save as Image via RepaintBoundary/toImage/PNG, Apple/Google Wallet placeholders).
- **Flow:** After QR/search/manual registrant resolve → push to registrant-resolved → then confirmation or session selection. Manual entry no longer checks in directly; returns registrantId for orchestration.
- **Dashboard:** Total Registrants shows "—" when zero (unknown); session stats prefer session doc `attendanceCount` when present.
- **Firestore rules:** Session doc allow update only when only `attendanceCount` and `updatedAt` change and `attendanceCount` increments by 1; `sessionRegistrations` read-only for client.

**What was tried**
- Implementing pure-session architecture with transactional capacity, pre-registration-driven flow, and pass-style confirmation with save-as-image and wallet hooks.

**Outcome / still broken**
- Implemented. Session docs must have `attendanceCount` (and optionally `capacity`, `status`, `colorHex`, `isMain`) for new flow. Bootstrap/seed should set these. If session has no `attendanceCount`, dashboard falls back to live attendance count().

**Next time (recall)**
- Deploy rules to (default): `firebase deploy --only firestore:(default)`. Ensure session docs have `attendanceCount` for capacity and dashboard. Use testing checklist in docs/TESTING_CHECKIN_ORCHESTRATION.md.

---

## 2026-02-18 — Permission-denied on RegistrantResolvedScreen Continue (session update)

**What was done**
- Updated session update rule in `firestore.rules` to allow first increment when session doc has no `attendanceCount` (legacy): allow update when `resource.data.attendanceCount == null && request.resource.data.attendanceCount == 1`, or when existing count + 1 equals new count.

**What was tried**
- Fixing permission-denied when tapping Continue on Main check-in (RegistrantResolvedScreen). Orchestrator runs transaction: create attendance doc, update session `attendanceCount` and `updatedAt`. Rule previously required `request.resource.data.attendanceCount == resource.data.attendanceCount + 1`; if session doc never had `attendanceCount` set, `resource.data.attendanceCount` is null and the expression failed in Rules.

**Outcome / still broken**
- Rule fix applied. User must deploy rules to **(default)** (app uses default DB per journal): `firebase deploy --only firestore:(default)` then retry.

**Next time (recall)**
- Legacy session docs without `attendanceCount` are now allowed (treated as 0). For new events, bootstrap session docs with `attendanceCount: 0` (and `capacity`, `status`, `isMain` as needed).
- **Rules “not updated”:** Same as 2026-02-15 — CLI can report success but Console still shows old rules. Use **explicit deploy:** run `./scripts/deploy-firestore-dev.sh` from repo root (targets (default) + event-hub-dev). Then **verify** in Firebase Console → Firestore → (default) → Rules tab that the text matches `firestore.rules`. If deploy fails (auth/network), run `./scripts/print-firestore-rules-for-paste.sh` and paste manually into Console.

---

## 2026-02-18 — Session-Aware Check-In UX Upgrade

**What was done**
- **RegistrantResolvedScreen** refactored from single “Continue” into a session-aware gate. No Firestore, orchestrator, capacity, or dashboard logic changed; UI + flow only.
- **MODE A — Pre-Registered (locked session):** When `sessionRegistrations/{registrantId}` exists and `sessionIds.length == 1`, screen shows: header “Main Check-In”, registrant name, “Ready to check in”, a **non-editable session card** (color stripe from `session.colorHex`, title, date/time, location, “Remaining Seats: X” or “Session Full”), **PRE-REGISTERED** green chip, and primary button **“Confirm & Check In”**. User cannot change session. On tap: `checkInToTargetSession(sessionId)`. Pre-registered users can attempt check-in even if session is full or closed (orchestrator may still enforce; on failure we show error).
- **MODE B — Not registered yet:** When sessionRegistrations doc missing or `sessionIds` empty, screen shows: “Select Your Session”, subtitle “Choose an available session to continue.”, and a **session list** from `listSessionsWithAvailability()`. Each card: color stripe, title, date/time, location, remaining seats, **status chip** (CLOSED / FULL / Almost Full when remaining ≤ 10% capacity / Available). Full and closed cards are disabled (opacity 0.7, no tap). On session tap: confirmation dialog (“Confirm Session Selection?” with session name, date, location, remaining seats) → Confirm → `checkInToTargetSession(selectedSessionId)`. If transaction fails with “Session full”: snackbar “This session just became full.”, refresh session list.
- **Multiple sessions:** Still push to `SessionSelectionScreen` with `preRegisteredSessionIds` (unchanged).
- **Confirmation screen:** Unchanged (session name, date/time, location, color tag, receipt, Save as Image, Apple/Google Wallet placeholders).
- Styling: NLC background, 24px padding, max width 600px, 16px rounded cards, soft shadow, color accent on cards.

**What was tried**
- Differentiating UX for pre-registered (locked session, one-tap confirm) vs not registered (select session, capacity-aware chips, confirm dialog, real-time full handling).

**Outcome / still broken**
- Implemented. Pre-registered sees locked card + Confirm & Check In; not registered sees “Select Your Session” with list and status chips. Edge cases: pre-reg but full/closed still show button (orchestrator may deny); manual/walk-in goes to MODE B.

**Next time (recall)**
- Session-aware gate lives on RegistrantResolvedScreen only. No changes to Firestore, CheckinOrchestratorService, or dashboard.

---

## 2026-02-18 — Seed from nlc_main_clean.csv: clear registration, registrants + session registrations

**What was done**
- **Seed tool** (`lib/src/tools/seed_nlc_registrants.dart`): Added `clearRegistrationData(firestore)` to batch-delete all docs in `events/nlc-2026/registrants` and `events/nlc-2026/sessionRegistrations`. Added `runSeed(..., clearFirst: bool)`: when true, clears then seeds. Return type now includes `sessionRegistrationsWritten`.
- **NLC main clean format:** When CSV has `id` column, use it as registrant document ID. Added column mapping for NLC export headers: `Registrant - Person's Name - First Name` → firstName, etc. Session columns `export_Gender_Identity_Dialogue`, `export_Contraception_Dialogue`, `export_Immigration_Dialogue`: if cell is **X**, write that session ID to `sessionRegistrations/{registrantId}` with `sessionIds` array (`gender-ideology-dialogue`, `contraception-ivf-abortion-dialogue`, `immigration-dialogue`).
- **seed_main.dart:** Reads `SEED_CLEAR_FIRST` env/define; also enables clear-first when file path contains `nlc_main_clean`. Passes `clearFirst` to `runSeed` and prints session registrations count.
- **Docs:** `docs/data2/README.md` — section “Seeding Firestore from nlc_main_clean.csv”. `docs/SEED_AND_CLEANUP.md` — NLC main clean command and `SEED_CLEAR_FIRST` note.

**What was tried**
- Using `docs/data2/nlc_main_clean.csv` as single source: erase all registration first, then seed registrants and session pre-registrations from the same file.

**Outcome / still broken**
- Implemented. Run: `SEED_FILE="docs/data2/nlc_main_clean.csv" SEED_NO_HASH=1 flutter run -t lib/seed_main.dart -d macos --dart-define=ENV=dev`. Clear-first runs automatically for that path; or set `SEED_CLEAR_FIRST=1` for any file. Session registrations written only for rows that have at least one X in the three dialogue columns.

**Next time (recall)**
- NLC main clean seed uses CSV `id` as registrant ID and export_*_Dialogue columns (X) for `sessionRegistrations`. Bootstrap must create dialogue session docs (`gender-ideology-dialogue`, etc.) in Firestore if session check-in is used.

---

## 2026-02-18 — Session Registration Intent + Capacity Enforcement Refactor

**What was done**
- **Data model formalized:** Registrants = identity; sessionRegistrations = intent (pre-reg); attendance = physical presence; sessions = capacity + metadata. No change to analytics, dashboard aggregation, Cloud Functions triggers, or attendance path.
- **Session model** (`lib/src/models/session.dart`): Documented canonical getters `remainingSeats` and `isAvailable` for capacity gating.
- **SessionRegistrationService:** Added `watchRegistration(eventId, registrantId)` → `Stream<SessionRegistration?>`. Added `setRegistration(eventId, registrantId, sessionIds)` with comment: admin/seed/server-only; no client arbitrary writes.
- **CheckinOrchestratorService:** Documented flow: ensureMainCheckIn → UI reads sessionRegistrations → pre-reg → lock UI + checkInToTargetSession(sessionId); not registered → SessionSelectionScreen + listAvailableSessions → on select transaction (capacity) + checkInToTargetSession.
- **Firestore rules:** sessionRegistrations already read: true, write: false. Sessions update already restricted to attendanceCount (+1) and updatedAt. Clarified comments.
- **UI:** RegistrantResolvedScreen pre-reg card now shows "You are pre-registered for this session." SessionSelectionScreen and RegistrantResolvedScreen use `session.isAvailable` to disable cards when full/closed.
- **Docs:** `docs/FIRESTORE_DATA_MODEL.md` updated with architecture summary, session schema, sessionRegistrations intent semantics, and checklist note for (default) vs named DB.

**What was tried**
- Production-safe separation of intent (sessionRegistrations) vs attendance (attendance subcollection); capacity enforced in transaction; UI locked when pre-registered.

**Outcome / still broken**
- Implemented. No changes to existing analytics, dashboard, or Cloud Functions. Attendance path unchanged. sessionRegistrations remains client read-only.

**Next time (recall)**
- sessionRegistrations = intent (server/admin/seed writes only). Check-in flow: getRegistration → pre-reg → lock + checkInToTargetSession; else listAvailableSessions → select → transaction + checkInToTargetSession.

---

## 2026-02-18 — Session capacity, location, colorHex in bootstrap and cards

**What was done**
- Node bootstrap (`functions/scripts/ensure-nlc-event-doc.js`) and Python bootstrap (`tools/seed_registrants.py` BOOTSTRAP_SESSIONS): set `location`, `capacity`, `colorHex` per NLC session (Main Check-In = Registration, 0 cap, #1E3A5F; Gender Identity = Main Ballroom 450 #0D9488; Immigration = Valencia Ballroom 192 #7C3AED; Contraception/Abortion = Saugus/Castaic 72 #EA580C). Colors are stored so they can be updated later in Firestore.
- RegistrantResolvedScreen: pre-reg card and selectable card always show a capacity line (Remaining Seats / Session Full / Capacity: Unlimited). Cards already use session color (stripe) and location from session model.

**What was tried**
- User asked for session colors (updatable), capacity remaining on the card, and location/capacity stored in session data model.

**Outcome / still broken**
- Implemented. Re-run Python seed or Node bootstrap so (default) DB sessions get location, capacity, colorHex; then cards will show color, location, and capacity remaining.

**Next time (recall)**
- Session colors/location/capacity live in Firestore; update there to change without code deploy.

---

## 2026-02-19 — Confirmation Screen Wayfinding + Guide Integration

**What was done**
- CheckinConfirmationScreen: UI + messaging only. No Firestore, analytics, or attendance changes.
- Header: large checkmark, "You Are Checked In", participant name.
- Session card: full top banner using session color (resolveSessionColor); "BLUE SESSION" / "ORANGE SESSION" / "YELLOW SESSION" / "MAIN" label; session title, location, date/time. Adaptive text color on banner (WCAG: dark → white, yellow → navy).
- Wristband instruction block: "Your wristband color: BLUE" (color bolded), "Proceed to the BLUE wristband table." (dynamic from session.colorHex).
- Conference guide section: book icon, "Conference Guide", subtitle nlcguide.cfcusaconferences.org, "Open Guide" button (url_launcher, external browser). No embedded QR.
- App bar: back replaced with check/Done; only "Done" and "Open Guide" as primary actions. No return to session selection.
- session_wayfinding: resolveSessionColorName(hex) → uppercase BLUE/ORANGE/YELLOW/MAIN; contrastTextColorOn(background) for accessible text on colored banner. url_launcher dependency added.

**What was tried**
- Align confirmation screen 1:1 with venue signage: session color wayfinding, wristband color instruction, table direction, online guide URL.

**Outcome / still broken**
- Implemented. Analytics, capacity, orchestrator, attendance path unchanged.

**Next time (recall)**
- Confirmation is final; no session change. Guide URL opens in external browser.

---

## Template for new entries (copy below this line)

```markdown
## YYYY-MM-DD — Short title

**What was done**
- (List code/config/doc changes.)

**What was tried**
- (What we attempted to fix.)

**Outcome / still broken**
- (Did it work? Same error? New error? Note DB name and path.)

**Next time (recall)**
- (One-line reminder so we don’t repeat.)
```
