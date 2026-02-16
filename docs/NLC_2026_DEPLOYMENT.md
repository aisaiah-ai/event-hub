# NLC 2026 – Deployment Steps (Section 8)

**Single event:** `eventId = nlc-2026`. Do not assume any document exists. Follow in order.

---

## 1. Firestore index (sessions order)

If you use `orderBy('order')` on `events/nlc-2026/sessions`, ensure an index exists. Either:

- Run the app and follow the link in the Firestore error to create the index, or
- Add to `firestore.indexes.json` and deploy:

```json
{
  "collectionGroup": "sessions",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "order", "order": "ASCENDING" }
  ]
}
```

Deploy indexes:

```bash
firebase deploy --config firebase.prod.json --only firestore:indexes
```

---

## 2. Deploy Firestore rules

```bash
firebase deploy --config firebase.prod.json --only firestore:rules
```

Targets: `(default)` and `event-hub-prod` (per firebase.prod.json). For staff-only production see `docs/NLC_2026_FIRESTORE_RULES.md`.

---

## 3. Deploy Cloud Functions

```bash
cd functions
npm ci
npm run build
cd ..
firebase deploy --config firebase.prod.json --only functions
```

This deploys:

- `onRegistrantCheckIn` (registrant onUpdate → stats)
- `onRegistrantCreate` (registrant onCreate → totalRegistrations, earlyBird)
- `onAttendanceCreate` (attendance onCreate → sessionTotals)
- `initializeNlc2026` (callable: create event, sessions, stats/overview)
- `backfillStats` (callable: ensure stats doc)

---

## 4. Initialize NLC 2026 (required before use)

**Do not assume event, sessions, or stats exist.** Run the bootstrap once (and after any DB reset):

1. **Option A – Callable from app (admin only)**  
   From an authenticated **admin** user (email in `events/nlc-2026/admins/{email}` with role ADMIN or STAFF), call the callable:

   ```dart
   final callable = FirebaseFunctions.instance.httpsCallable('initializeNlc2026');
   final result = await callable.call();
   ```

2. **Option B – curl (with auth token)**  
   Get an ID token for an admin user, then:

   ```bash
   curl -X POST 'https://us-central1-aisaiah-event-hub.cloudfunctions.net/initializeNlc2026' \
     -H 'Authorization: Bearer YOUR_ID_TOKEN' \
     -H 'Content-Type: application/json' \
     -d '{}'
   ```

3. **Option C – Firebase Console**  
   Create manually per `docs/NLC_2026_DATA_MODEL.md`: event doc, sessions subcollection, `stats/overview` doc.

After this, the event doc, default sessions (opening-plenary, leadership-session-1, mass, closing), and `stats/overview` exist. Flutter will load sessions from Firestore; if they were missing, "Event not initialized. Contact admin." is shown until bootstrap runs.

---

## 5. Add admin/staff for initializeNlc2026

To run `initializeNlc2026`, the user must be in `events/nlc-2026/admins/{email}` with role `ADMIN` or `STAFF`. Create that document in Firestore (e.g. via Console) or via your admin flow.

---

## 6. Flutter app

- **Database:** App uses `FirestoreConfig` (dev: `(default)` when `_useDefaultDbForDev` is true; prod: `event-hub-prod`). Ensure the database you use has been initialized (step 4) and has rules deployed (step 2).
- **Background:** NLC check-in uses local asset `assets/images/nlc_background.png` and the Stack layout (image, overlay 0.45, SafeArea, ConstrainedBox maxWidth 520). No network images for weekend-safe.
- **Sessions:** Loaded from `events/nlc-2026/sessions` with `orderBy('order')`. No hardcoded session lists.

---

## 7. Success criteria (Section 8)

System is correct only if:

1. Sessions load from Firestore (no hardcoded lists).
2. Registrant check-in updates Firestore (eventAttendance, checkInSource, sessionsCheckedIn, optional attendance doc).
3. `totalCheckedIn` in `stats/overview` increments by 1 after a check-in.
4. Double check-in does **not** increment (transaction reads registrant first).
5. Session attendance doc created once per session check-in; count in `sessionTotals` increments only once.
6. Dashboard (if any) updates in real time from `stats/overview`.
7. Background image renders (local asset, no network).
8. No hardcoded session lists in Flutter.
9. No missing-document errors when event/sessions/stats have been initialized via `initializeNlc2026`.

---

## 8. Verify

1. Run `initializeNlc2026` as admin.
2. Open check-in screen; confirm sessions appear (from Firestore).
3. Check in a registrant; confirm `events/nlc-2026/registrants/{id}` has `eventAttendance.checkedInAt` and `checkInSource`.
4. Confirm `events/nlc-2026/stats/overview` has `totalCheckedIn` incremented.
5. Try checking in the same registrant again; confirm it fails (already checked in).
6. Confirm `events/nlc-2026/sessions/{sessionId}/attendance/{registrantId}` exists when a session was selected.
