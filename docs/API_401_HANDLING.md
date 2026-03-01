# Events Hub API — 401 handling and backend auth

This doc records how the **app** should handle 401s from the Events Hub API (so the UI doesn’t error or retry in a loop) and how to **fix 401 at the backend** so registration/check-in actually work.

**Scope:** This repo (event-hub) does not define `events_hub_registration_service.dart` or `events_hub_checkin_service.dart`; those names and behavior refer to the **consumer app** (e.g. aisaiah_spiritual_fitness_app) that calls the Events Hub API. The doc applies to **any client** of the Events Hub API. If you add registration/check-in client code in this repo later, implement it to follow the behavior below (treat 401 as “not authenticated” and return null/empty defaults).

---

## What was changed in the app (consumer side)

401 is now treated as **“not authenticated for Events Hub”** so the event detail page doesn’t error and doesn’t retry in a loop.

### events_hub_registration_service.dart

- **getMyRegistration(eventId):** On 401 / unauthenticated, return `null` instead of throwing.
- **getMyRegistrations():** On 401, return `[]` instead of throwing.

### events_hub_checkin_service.dart

- **getCheckInStatus(eventId):** On 401, return an empty `EventsHubCheckInStatus()` instead of throwing.

### Result

- The event detail page no longer goes into a permanent error state for registration/check-in.
- At most one 401 log per request (from the API client), then a single warning like `getMyRegistration ... -> 401, treating as not registered`.
- The UI behaves as “not registered” and “not checked in” (Register and Check In stay available; no repeated refetches).
- Register and Check In still call the same auth endpoints; if the token is still invalid there, the user gets the normal “Please sign in again” (or similar) message **once per tap**, not a loop.

---

## Fixing the 401 itself (backend / token)

To get registration and check-in actually working, the **Events Hub API must accept the app’s Firebase token**.

### Same Firebase project

The Events Hub Cloud Functions project must be the **same as** (or trust) the project that issues the app’s Firebase Auth tokens. If the app uses a different project, 401 is expected.

### Token freshness

If the backend only accepts very fresh tokens, ensure the app is sending a current ID token (e.g. no long-lived cached token). The client should use `user.getIdToken()`; if the backend has very strict expiry checks, confirm its validation logic.

### Backend auth middleware

In this repo, auth is in **`functions/src/middleware/auth.ts`**:

- Reads `Authorization: Bearer <idToken>`.
- Calls `admin.auth().verifyIdToken(idToken)` (Firebase Admin SDK).
- That validates: **project ID**, issuer, audience, expiry — all against the Firebase project that initialized `firebase-admin` in this Cloud Functions app.

**To fix 401:**

1. Ensure the **app’s Firebase project** is the same as the project used by `firebase-admin` in these Cloud Functions (same `firebase.json` / same project when deploying functions).
2. Ensure the app sends a **fresh ID token** (e.g. `FirebaseAuth.instance.currentUser?.getIdToken(true)` before each request if needed).
3. After aligning the backend with the app’s Firebase project and token, 401s should stop and registration/check-in will work without any further change to the app code.

---

## Reference

- API routes using `requireAuth`: `functions/src/api/v1/routes.ts` (e.g. `/events/:eventId/my-registration`, `/me/registrations`, `/events/:eventId/checkin/status`).
- Auth middleware: `functions/src/middleware/auth.ts`.
