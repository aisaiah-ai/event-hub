# When You Get a Firestore Check-In Error

**Do this first** — don’t assume it’s only rules or the wrong database.

## 1. Export and open the data model

From the project root:

```bash
dart scripts/firestore_data_model.dart
# or
./scripts/export_firestore_data_model.sh
```

Open **docs/FIRESTORE_DATA_MODEL.md**. It lists every path the app uses, what **parent must exist**, and who creates it.

## 2. Match the error path to the model

- Error mentions `events/nlc-2026/checkins/...`  
  → In the doc, see **events/{eventId}/checkins/{registrantId}**.  
  **Parent must exist:** `events/{eventId}`. So `events/nlc-2026` must exist in the database the app uses (see JOURNAL.md).

- Error mentions `events/nlc-2026/sessions/.../attendance/...`  
  → See **events/{eventId}/sessions/{sessionId}/attendance/...**.  
  **Parent must exist:** `events/{eventId}/sessions/{sessionId}`. So the **session document** (e.g. `events/nlc-2026/sessions/main-checkin`) must exist before any attendance write.

## 3. Check the right database

The app may use **(default)** or a named database (e.g. **event-hub-dev**). See **docs/JOURNAL.md** for the current choice. Ensure the event and session docs exist in the **same** database the app uses. If they were created in a different database, either run bootstrap in the app’s DB or point the app at the DB where they already exist.

## 4. Create missing parents

- Missing **event** doc: create `events/nlc-2026` (or your eventId) in the named DB (Console or bootstrap script).
- Missing **session** doc: create e.g. `events/nlc-2026/sessions/main-checkin` and `events/nlc-2026/sessions/gender-ideology-dialogue` in the named DB.

Then retry the check-in.

## 5. Then check rules

Only after confirming the path and its parent exist in the correct database, (re)deploy rules for that database:

```bash
firebase deploy --only firestore:rules
```

---

**Summary:** On error → export data model → open FIRESTORE_DATA_MODEL.md → find the failing path → ensure its **parent** exists in the database the app uses (see JOURNAL.md) → deploy rules to that database → then check App Check if you use it.
