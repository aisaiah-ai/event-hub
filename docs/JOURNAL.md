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
