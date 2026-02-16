# Check-In Module Gap Analysis

**Spec:** checkin-platform-nlc.md  
**Target:** NLC self-check-in at events-dev.aisaiah.org/events/nlc/checkin  
**Scope:** Harden check-in first; keep RSVP intact.

---

## Current vs Spec

| Area | Current | Spec | Gap |
|------|---------|------|-----|
| **Route** | `/events/:slug/checkin` → "Staff Login Required" → redirects to `/checkin` | Single public landing at `/events/:slug/checkin` | Entry page is placeholder; no self-check-in |
| **Session model** | `Session`: title, startAt, endAt, type | name, code, isActive (unlimited) | No `code`, `isActive`; spec expects active filter |
| **Check-in storage** | `registrants/{id}/eventAttendance` + `sessions/{id}/attendance` | `events/{eventId}/checkins` flat collection | Different structure; spec uses flat checkins |
| **Event config** | `allowCheckin` only | `checkinEnabled`, `selfCheckinEnabled`, `sessionsEnabled` | Need selfCheckin + sessions flags |
| **Branding** | EventModel has logoUrl, backgroundImageUrl, backgroundPatternUrl, primaryColorHex, accentColorHex | Same + event-specific | ✅ Already in DB; EventPageScaffold uses it |
| **CheckinScreen** | Hardcoded navy gradient, mosaic.svg; eventId from query; admin routes | Event-driven branding; public self-check-in | No event branding; staff-only flow |
| **QR flow** | Simulated only | Scan CFC QR → lookup by cfcId/email → check-in | Need real QR + lookup |
| **Search flow** | ManualCheckinScreen (admin) – full list search | Public search with prefix, limit 20 | Need restricted public search |
| **Manual entry** | Admin "Add Registrant" | Public form → checkin record only (no registrant) | Need public manual check-in |
| **Duplicate check** | Via eventAttendance | Query checkins by registrantId+sessionId | New logic |
| **Success page** | CheckinStatusCard inline | Dedicated success page, auto-return 3s | Need success page |

---

## What Exists (Keep)

- **EventModel** — branding fields already in Firestore (`branding` or top-level)
- **EventPageScaffold** — dynamic background, pattern, logo from event
- **EventRepository** — getEventBySlug; add getEventById
- **Registrant** — profile (firstName, lastName, email, cfcId, role, unit)
- **Session** — extend with code, isActive
- **Firestore** — events, registrants, sessions; add checkins

---

## Migration Path

1. **Phase 1 (this work):** Implement self-check-in at `/events/:slug/checkin`
   - Use EventPageScaffold (event branding)
   - Add checkins collection
   - Add selfCheckinEnabled, sessionsEnabled to EventModel (metadata or fields)
   - Session selector, QR, search, manual entry, success page

2. **Phase 2:** Keep `/checkin` (staff) as-is for now
   - EventCheckinEntryPage becomes the new self-check-in landing
   - Staff flow continues via "Go to Check-in" → `/checkin` (unchanged)

3. **Phase 3 (future):** Staff/Admin auth, RBAC, dashboard per phase2 doc

---

## Firestore Adaptations

| Spec | Implementation | Notes |
|------|----------------|-------|
| events/{id} checkinEnabled | `allowCheckin` (existing) | Use for "check-in available" |
| selfCheckinEnabled | `metadata.selfCheckinEnabled` or new field | Add to EventModel |
| sessionsEnabled | `metadata.sessionsEnabled` or new field | Add to EventModel |
| sessions: name, code, isActive | Extend Session model | Add code, isActive; fallback for existing |
| checkins collection | New `events/{eventId}/checkins` | AutoId, eventId, registrantId?, sessionId, method, manualPayload?, timestamp, source |

## Implemented (NLC hardening)

- **Event branding:** `EventPageScaffold` uses `event.logoUrl`, `event.backgroundImageUrl`, `event.backgroundPatternUrl`, `event.primaryColor`, `event.accentColor` from `EventModel` (Firestore `branding` or top-level fields. Per-event branding in Firestore).
- **Checkins Firestore rules:** Public can create when `metadata.selfCheckinEnabled == true`; staff can read/write. Fields: eventId, sessionId, method, source, registrantId?, manualPayload?.
- **CheckinRecord:** `eventId`, `manualPayload` added; `toFirestore(eventId)` required.
- **Sessions fallback:** When `sessionsEnabled` but no sessions in Firestore, use default session.

---

## Registrant Lookup

Spec: firstName, lastName, email, cfcId.

Current: `profile` + `answers` maps. Use:
- `profile['firstName']` / `answers['firstName']`
- `profile['lastName']` / `answers['lastName']`
- `profile['email']` / `answers['email']`
- `profile['cfcId']` / `answers['cfcId']`

Search: query registrants with composite index or prefix on normalized fields.

---

## Troubleshooting: Search Permission Denied

If you see `[cloud_firestore/permission-denied] Missing or insufficient permissions` when searching:

1. **Re-authenticate Firebase CLI**
   ```bash
   firebase login --reauth
   ```

2. **Deploy Firestore rules to dev** (does not touch prod)
   ```bash
   ./scripts/deploy-firestore-dev.sh
   ```
   Rules allow read on `events/nlc-2026/registrants` for unauthenticated users.

3. **Verify database exists**
   - Firebase Console → aisaiah-event-hub → Firestore Database
   - Ensure `event-hub-dev` exists (create if needed)

4. **Verify data**
   - Registrants must be at `events/nlc-2026/registrants`
   - Seed with: `SEED_FILE=path/to.csv SEED_NO_HASH=1 flutter run -t lib/seed_main.dart -d macos --dart-define=ENV=dev`

5. **Hot restart** the app after deploying rules.

6. **If seed still fails:** Add registrants manually. See **docs/MANUAL_SEED_REGISTRANTS.md**.
