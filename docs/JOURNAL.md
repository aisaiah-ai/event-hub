# Dev Journal — Firestore, Check-In, Permissions

**Purpose:** Log every significant change and outcome so we don’t repeat the same fixes. **Before** changing Firestore/check-in/permission logic, **read this file**. **After** any change that touches DB, rules, or check-in, **append a new entry** with date, what was done, and result.

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
