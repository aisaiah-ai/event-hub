# Firestore Permission-Denied Troubleshooting

If you see `[cloud_firestore/permission-denied] Missing or insufficient permissions` (or not-found) in the app, follow these steps.

## 0. Check the data model first (avoid going in circles)

**Before** assuming it’s rules or App Check: ensure the path you’re writing to (and its **parent**) exists in the database the app uses (e.g. **(default)** or event-hub-dev). See JOURNAL.md.

1. Export the data model: from project root run  
   `dart scripts/firestore_data_model.dart` or `./scripts/export_firestore_data_model.sh`
2. Open **docs/FIRESTORE_DATA_MODEL.md** and find the path that’s failing (e.g. `events/…/checkins/…` or `…/sessions/…/attendance/…`).
3. Check **Parent must exist** for that path. Create the parent document in the named DB if it’s missing (event doc, session doc, etc.).

See **docs/FIRESTORE_ERROR_FIRST_STEPS.md** for a short checklist.

---

## 0b. Quick isolation: temporary open rules (diagnostic only)

To confirm that the failure is rules (or App Check), temporarily deploy **open** rules and retry:

1. In Firebase Console → Firestore → select the database the app uses (e.g. **(default)**) → **Rules** tab. Copy current rules somewhere safe.
2. Replace with:
   ```text
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if true;
       }
     }
   }
   ```
3. Deploy: `firebase deploy --only firestore:rules` (or deploy from Console).
4. Try check-in again.
   - **If it works** → 100% rules or App Check. Restore your real rules and fix the rule that was denying (or disable App Check enforcement for Firestore temporarily).
   - **If it still fails** → Likely App Check enforcement or wrong database. Check App Check → Firestore (unenforce to test) and confirm the app’s database matches Console.
5. **Restore your real rules immediately.** Do not leave rules open in production.

---

## 1. App Check (most common cause)

**When App Check enforcement is ON**, Firestore rejects any request that does not include a valid App Check token. Your app has App Check disabled/comment-out, so no token is sent. Result: permission-denied even with `allow read, write: if true` in rules.

### Fix: Disable App Check enforcement for Firestore

1. Open [Firebase Console](https://console.firebase.google.com) → **aisaiah-event-hub**
2. Go to **App Check** (left sidebar)
3. If you see **Cloud Firestore** listed with "Enforced" or a shield icon, click it
4. Click **Unenforce** / disable enforcement
5. Wait 5–15 minutes for propagation

**If App Check shows "Get started"** – it may not be the cause. Check API key restrictions next.

### Alternative: Enable App Check properly for web

1. In Firebase Console → App Check, add ReCaptcha v3 for web
2. Register your domain (e.g. `localhost` for local dev)
3. Update `main.dart` to use `ReCaptchaV3Provider` for web when activating App Check

---

## 2. Web API key restrictions

If the Firebase Web API key has HTTP referrer restrictions that exclude `localhost`, requests may fail.

1. Open [Google Cloud Console](https://console.cloud.google.com) → **aisaiah-event-hub**
2. Go to **APIs & credentials** → **Credentials**
3. Find the **Web API key** (starts with `AIzaSy...` used in `firebase_options.dart` web)
4. Edit it → under **Application restrictions**, ensure either:
   - **None**, or
   - **HTTP referrers** includes `localhost:*` and `127.0.0.1:*`

---

## 3. Test in browser console (isolate Flutter vs Firebase)

Run this in Chrome DevTools Console while the app is loaded:

```javascript
// Uses the already-initialized Firebase from the Flutter app
const db = firebase.firestore();
db.collection('events/nlc-2026/registrants').limit(1).get()
  .then(snap => console.log('OK:', snap.size, 'docs'))
  .catch(e => console.error('FAIL:', e));
```

- If **OK** → Firebase works; issue may be in Flutter/cloud_firestore.
- If **FAIL** → Firebase itself is blocking; focus on App Check, rules, API key.

---

## 4. Local Dev: macOS & Web Specifics

### macOS: LevelDB Lock Error
If running the **seed script** (`flutter run -d macos ...`) while the main **app** (`flutter run -d macos`) is also running, you may see:
`LevelDB error: IO error: lock ... Resource temporarily unavailable`

**Fix:** The seed script now disables persistence to avoid this conflict. If you still see it, ensure no other instance of the app is writing to the same local cache file, or stop the main app before seeding.

### Web: App Check `ArgumentError`
If you see `App Check activate failed: TypeError: Instance of 'ArgumentError'...` on web:
This means `webProvider` was missing in `activate()`.
**Fix:** Ensure `main.dart` initializes App Check with `ReCaptchaV3Provider` (or similar) on web.
For local debug:
1. Set `self.FIREBASE_APPCHECK_DEBUG_TOKEN = true;` in `web/index.html`.
2. Run the app. Open Chrome DevTools Console.
3. Look for the debug token (e.g. `App Check debug token: '...'`).
4. Add it to Firebase Console > App Check > Manage debug tokens.

---

## 5. Firestore rules

Check that your rules allow reads for the path in question.

- Path: `events/{eventId}/registrants`
- Dev rules in `firestore.dev.rules` should include `allow read` for the event (e.g. `eventId == 'nlc-2026'`)

Deploy rules:

```bash
./scripts/deploy-firestore-dev.sh
```

---

## 6. Database and project

Confirm the app is using the correct Firestore database:

- **Dev:** `event-hub-dev` (see `FirestoreConfig.databaseId`)
- **Prod:** `event-hub-prod`

Project ID: `aisaiah-event-hub` (from `firebase_options.dart`)

Check logs at startup for:

```
[FirestoreConfig] Connected: project=aisaiah-event-hub, database=event-hub-dev
[RegistrantService] listRegistrants: path=events/nlc-2026/registrants, db=event-hub-dev
```

---

## 7. Verify rules are deployed

1. Firebase Console → Firestore Database
2. Select the **event-hub-dev** database (if using named DB)
3. Go to **Rules** tab and confirm your rules are present
4. Test rules with the Rules Playground

---

## Quick fix: Disable App Check (run this)

App Check enforcement blocks Firestore. Disable it:

**Option A – Script (run in your terminal):**
```bash
gcloud auth application-default login   # if needed
./scripts/disable-app-check-firestore.sh
```

**Option B – Firebase Console:**
1. Open https://console.firebase.google.com/project/aisaiah-event-hub/appcheck
2. Find **Cloud Firestore** → click **Manage**
3. Click **Unenforce**
4. Wait 1–2 minutes

Then refresh the app or test page.

---

## Quick checklist

| Step | Action |
|------|--------|
| 1 | Disable App Check enforcement (script or Console) |
| 2 | Deploy rules: `./scripts/deploy-firestore-dev.sh` |
| 3 | Confirm project/database in logs |
| 4 | Verify data exists in `events/nlc-2026/registrants` |
