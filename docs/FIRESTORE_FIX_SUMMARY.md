# Firestore Permission Fix – Summary

---

## 🔴 Fix “permission-denied” on event-hub-dev (do this once)

If the app shows **permission-denied** when you search (database **event-hub-dev**), the rules on that database are wrong. Fix it in one of two ways:

### Option A – Deploy via CLI (recommended)

1. **Re-auth** (needed if you ever see “credentials are no longer valid”):
   ```bash
   firebase login --reauth
   ```
2. **Deploy rules to event-hub-dev only**:
   ```bash
   ./scripts/deploy-firestore-rules-event-hub-dev.sh
   ```
3. Reload the app and try search again.

### Option B – Paste rules in Firebase Console (no CLI auth)

1. Run:
   ```bash
   ./scripts/print-firestore-rules-for-paste.sh
   ```
2. Copy the rules it prints (between the “COPY FROM/HERE” lines).
3. Open [Firestore in Firebase Console](https://console.firebase.google.com/project/aisaiah-event-hub/firestore).
4. Use the **database** dropdown at the top → select **event-hub-dev**.
5. Open the **Rules** tab → select all → delete → paste the copied rules → **Publish**.
6. Reload the app; search should work.

---

## ✅ Dev uses (default) so the app works now

In **dev**, the app uses the **(default)** database by default so check-in search works without deploying rules to event-hub-dev. To use **event-hub-dev** in dev (e.g. after you've fixed its rules), set in `lib/src/config/firestore_config.dart`:

```dart
static const bool useEventHubDevInDev = true;
```

### If search works but check-in fails on (default) (permission-denied)

The **(default)** database must have the event document `events/nlc-2026` with `metadata.selfCheckinEnabled: true` so unauthenticated check-in is allowed. Run the bootstrap script once for (default):

```bash
cd functions && node scripts/ensure-nlc-event-doc.js "--database=(default)"
```

Requires `gcloud auth application-default login`. This creates the event doc, 4 sessions, and stats/overview in (default). Then try check-in again.

---

## ✅ Completed

### 1. Firestore rules

**File:** `firestore.rules`

- **Registrants read:** Public read for `eventId == 'nlc-2026'` (check-in search)
- **Registrants update:** Staff **or** unauthenticated when `selfCheckinEnabled(eventId)` (see §5 below)
- **Other collections:** Unchanged (RSVP, sessions, checkins, etc.)

**Deployed:**
- **event-hub-dev** and **(default):** `firebase deploy --only firestore:rules` (uses `firebase.json`; both databases use `firestore.rules`).
- **event-hub-prod:** `firebase deploy --config firebase.prod.json --only firestore:rules`.

**Why event-hub-dev was denying:** Rules on **event-hub-dev** were not updated by CLI deploys (Console showed different/stricter rules). **If event-hub-dev still returns permission-denied after deploy:** paste rules manually: Firebase Console → Firestore → database **event-hub-dev** → Rules tab → paste contents of `firestore.rules` → Publish. See `docs/FIRESTORE_DEV_TROUBLESHOOTING.md` for step-by-step. **firebase.prod.json** now includes event-hub-dev so `firebase deploy --only firestore:rules --config firebase.prod.json` deploys to (default), event-hub-dev, and event-hub-prod.

### 2. Project ID check

**Location:** `lib/main.dart`

```dart
print('Firebase Project: ${Firebase.app().options.projectId}');
```

**Expected:** `aisaiah-event-hub` (same as in Firebase Console)

### 3. App Check

**Status:** Enforcement is OFF for Firestore (via `./scripts/disable-app-check-firestore.sh`).

- App Check activation in code is still commented out.
- If you turn enforcement back on later, configure:
  - `ReCaptchaV3Provider` for web
  - reCAPTCHA site key from Firebase Console → App Check

### 4. No query changes

Flutter query logic is unchanged.

### 5. Event document for self-check-in (fixes permission-denied on check-in)

**Symptom:** Check-in fails with `[cloud_firestore/permission-denied]` even though search works. Log shows `database: event-hub-dev` (or event-hub-prod).

**Cause:** Unauthenticated registrant update and checkins create are allowed only when `selfCheckinEnabled(eventId)` is true. That requires the **event document** `events/nlc-2026` to **exist** in the same database and have `metadata.selfCheckinEnabled == true`. If the event doc is missing or lacks that field, the rule denies the write.

**Fix:** The app does not create event/sessions/stats. Run the bootstrap script once (or add in Console). Script command:
`cd functions && node scripts/ensure-nlc-event-doc.js`

**Where to look in Firestore:** In the Data tab, use the **database dropdown at the top**. The app uses **event-hub-dev** (dev) and **event-hub-prod** (prod) — never (default). See `docs/DATABASE_NAMES.md`. Event, sessions, and stats must exist in the database the app is using (event-hub-dev when ENV=dev).

**Where each document is created (same script/callable creates all three):**

| What you see in Console | Full path | Created by |
|-------------------------|-----------|------------|
| **Event document** (name, venue, metadata) | `events` → document **`nlc-2026`** | `ensure-nlc-event-doc.js` or `initializeNlc2026` callable |
| **Sessions** (4 docs) | `events` → `nlc-2026` → subcollection **`sessions`** | Same script/callable |
| **Stats overview** | `events` → `nlc-2026` → subcollection **`stats`** → document **`overview`** | Same script/callable |

All three are written in one batch. If only sessions appear, run the script again so event doc and `stats/overview` exist.

**Option A – Script**

Requires Application Default Credentials (`gcloud auth application-default login`). From repo root:

```bash
cd functions && node scripts/ensure-nlc-event-doc.js
```

Writes to **event-hub-dev** by default. For prod: `node scripts/ensure-nlc-event-doc.js --database=event-hub-prod`.

Creates: event doc (name, venue, createdAt, isActive, metadata), 4 sessions (opening-plenary, leadership-session-1, mass, closing), and stats/overview.

**Option B – Firebase Console (manual, no script needed)**

1. Open [Firebase Console → Firestore](https://console.firebase.google.com/project/aisaiah-event-hub/firestore).
2. At the top, open the **database** dropdown and select **event-hub-dev** (for local/dev) or **event-hub-prod** (for prod). The app never uses (default).
3. **Event document** — create or edit `events` → `nlc-2026`:
   - If the `events` collection or `nlc-2026` doc doesn’t exist: **Start collection** → collection ID `events` → Document ID `nlc-2026`.
   - Add a map field **`metadata`**. Inside it add:
     - **`selfCheckinEnabled`** (boolean): `true`
     - **`sessionsEnabled`** (boolean): `true`
   - Save.
4. **Sessions (optional)** — 4 docs under `events` → `nlc-2026` → `sessions` with Document IDs: `opening-plenary`, `leadership-session-1`, `mass`, `closing`. Each: `name` (string), `location` (string), `order` (number), `isActive` (true).

---

## Verify

1. **Search works:** NLC 2026 check-in search returns registrants.
2. **Self-check-in works:** With `events/nlc-2026` and `metadata.selfCheckinEnabled: true` in event-hub-dev (or event-hub-prod), unauthenticated check-in succeeds.
3. **Authenticated write works:** Staff with valid auth can write.
4. **Console output:** `Firebase Project: aisaiah-event-hub`, `database=event-hub-dev` (or event-hub-prod).
