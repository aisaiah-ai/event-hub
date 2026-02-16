# Permission-Denied: Action Plan

The Flutter app and `test_firestore.html` both fail with `Missing or insufficient permissions` when reading `events/nlc-2026/registrants`. This doc lists the most likely causes and exact steps to fix them.

## What We Know

- **Project:** aisaiah-event-hub
- **Databases:** `(default)` and `event-hub-dev` both fail
- **Dev rules:** `allow read, write: if true` (firestore.dev.rules)
- **App Check:** Disabled in code; script exists to turn off enforcement
- **test_firestore.html:** Uses raw Firebase JS SDK, no App Check → also fails

When both the Flutter app and a minimal JS test fail, the issue is almost always **Firebase backend config** (App Check or API key), not app code.

---

## 1. App Check (Most Likely)

When App Check enforcement is ON, Firestore rejects requests without a valid App Check token. Your app and test page do not send one.

### Check status
```bash
./scripts/check-app-check-status.sh
```

### Disable enforcement
```bash
gcloud auth login   # NOT application-default
./scripts/disable-app-check-firestore.sh
```

Then wait 1–2 minutes and retry.

### Verify in Firebase Console
1. Open [Firebase Console → App Check](https://console.firebase.google.com/project/aisaiah-event-hub/appcheck)
2. Find **Cloud Firestore** → **Manage**
3. Ensure it shows **Unenforced** or **Off**
4. If it shows **Enforced**, click **Unenforce**

---

## 2. Web API Key Restrictions

If the web API key restricts HTTP referrers and excludes `localhost`, requests can fail.

1. Open [Google Cloud Console → Credentials](https://console.cloud.google.com/apis/credentials?project=aisaiah-event-hub)
2. Find the Web API key (the one in `firebase_options.dart` / `test_firestore.html`: `AIzaSyDEcxBJLcsLKPtduEMwjvbqJJP15BbslZw`)
3. Edit the key
4. Under **Application restrictions**:
   - Choose **None**, **or**
   - Choose **HTTP referrers** and add:
     - `http://localhost:*`
     - `http://127.0.0.1:*`
     - `http://localhost:*/*`
     - `http://127.0.0.1:*/*`

---

## 3. Firestore Rules Deployed Correctly

1. Redeploy rules:
   ```bash
   ./scripts/deploy-firestore-dev.sh
   ```
2. In [Firebase Console → Firestore](https://console.firebase.google.com/project/aisaiah-event-hub/firestore):
   - Select the `(default)` database
   - Open the **Rules** tab and confirm they match `firestore.dev.rules`
   - Repeat for `event-hub-dev` if you use it

---

## 4. Enable App Check (If You Must Keep Enforcement On)

If you need App Check enforced:

1. Create a reCAPTCHA v3 key at [reCAPTCHA Admin](https://www.google.com/recaptcha/admin)
2. In [Firebase Console → App Check](https://console.firebase.google.com/project/aisaiah-event-hub/appcheck):
   - Add **reCAPTCHA v3** for the web app
   - Use the site key from step 1 and register the secret key
3. In `lib/main.dart`, uncomment App Check activation and use a real key:
   ```dart
   await FirebaseAppCheck.instance.activate(
     webProvider: ReCaptchaV3Provider('YOUR_RECAPTCHA_V3_SITE_KEY'),
   );
   ```
4. For localhost, set `self.FIREBASE_APPCHECK_DEBUG_TOKEN = true` in `web/index.html`, get the debug token from the browser console, and register it in App Check.

---

## Quick Order of Operations

1. Disable App Check enforcement (script or Console)
2. Check API key referrer restrictions
3. Redeploy rules
4. Retry `test_firestore.html`; if it works, the Flutter app should work too
