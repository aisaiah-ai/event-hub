# Events Hub Repo: API Service Implementation Plan (App-First)

A practical implementation plan to add a clean, versioned API service (Cloud Functions HTTP) that supports the Spiritual App: events, RSVP/register, check-in (main + session), schedule, announcements, and deep-link landing.

---

## Goals

- Expose a **stable `/v1` API** for the Spiritual App.
- **Centralize business rules:** registration rules, check-in rules, idempotency, capacity limits.
- **Keep existing Event Hub UI/Admin flows working.**
- Support **deep links:** QR opens app (or fallback page).

---

## Phase 0 — Repo Prep & Standards (Foundation)

### 0.1 Add an API module inside Cloud Functions

Create structure:

```
functions/src/
  api/
    v1/
      routes.ts
      events.routes.ts
      registrations.routes.ts
      checkin.routes.ts
      schedule.routes.ts
      announcements.routes.ts
  middleware/
    auth.ts
    validate.ts
    rateLimit.ts
  services/
    events.service.ts
    registrations.service.ts
    checkin.service.ts
    schedule.service.ts
    announcements.service.ts
  models/
    dto.ts
    errors.ts
  utils/
    now.ts
    firestore.ts
    idempotency.ts
  index.ts
```

### 0.2 Choose runtime + framework

- Use **Express** inside Cloud Functions:
  - `exports.api = onRequest(app)`
- Put versioning in code:
  - Mount under **`/v1`**

### 0.3 Add consistent response + error patterns

- Standard JSON shape:
  - Success: `{ ok: true, data: ... }`
  - Error: `{ ok: false, error: { code, message } }`
- Ensure all endpoints return predictable errors.

---

## Phase 1 — Auth & Security (Must-have for “My Registrations”)

### 1.1 Implement Firebase Auth middleware

**`middleware/auth.ts`**

- Validate `Authorization: Bearer <idToken>`
- Attach `req.user = { uid, email, name? }`

### 1.2 Define access levels

| Level | Endpoints |
|-------|-----------|
| **Public** | Event listing, event details, schedule, announcements (optional public) |
| **Member** | Register, my registrations, check-in |
| **Staff/Admin** (future) | Admin check-in overrides, exports, analytics endpoints |

Keep staff/admin in Event Hub UI separate; this plan focuses on **member API**.

---

## Phase 2 — Firestore Data Contract (Minimal changes, maximum stability)

### 2.1 Confirm/standardize these collections

| Path | Key fields |
|------|------------|
| `events/{eventId}` | `title`, `chapter`, `region`, `startAt`, `endAt`, `venue`, `visibility`, `registrationSettings` |
| `events/{eventId}/sessions/{sessionId}` | `title`, `startAt`, `endAt`, `room`, `capacity` (optional), `tags` |
| `events/{eventId}/announcements/{announcementId}` | `title`, `body`, `pinned`, `priority`, `createdAt` |
| `events/{eventId}/registrations/{registrationId}` | `uid`, `status` (registered \| canceled), `createdAt`, profile snapshot (name/email optional), `meta` (chapter/cluster optional) |
| `events/{eventId}/checkins/{checkinId}` | `uid`, `type` (main \| session), `sessionId?`, `createdAt`, `source` (app \| staff \| web), `idempotencyKey` |

### 2.2 Add an index-friendly “my registrations” path (recommended)

To avoid heavy queries, write a lightweight mirror doc:

**`users/{uid}/registrations/{eventId}`**

- `eventId`, `registrationId`, `status`, `createdAt`, `eventStartAt` (for sorting)

This makes the “My Registrations” endpoint fast.

---

## Phase 3 — Build the /v1 API Endpoints (Core)

### 3.1 Events

| Endpoint | Description |
|----------|-------------|
| `GET /v1/events?from&to&chapter&region` | List events with filters |
| `GET /v1/events/:eventId` | Event details |

**Implementation:** Query Firestore events with filters; enforce visibility (public/private).

---

### 3.2 Schedule + Sessions

| Endpoint | Description |
|----------|-------------|
| `GET /v1/events/:eventId/schedule` (or sessions list) | Ordered schedule |
| `GET /v1/events/:eventId/sessions` | Sessions list |

Return ordered sessions by start time.

---

### 3.3 Announcements

| Endpoint | Description |
|----------|-------------|
| `GET /v1/events/:eventId/announcements` | Announcements for event |

Return pinned first, then newest.

---

### 3.4 RSVP / Registration

| Endpoint | Auth | Description |
|----------|------|-------------|
| `POST /v1/events/:eventId/register` | Required | Register for event |
| `GET /v1/me/registrations` | Required | My registrations across events |
| `GET /v1/events/:eventId/my-registration` | Required | My registration for this event |
| `POST /v1/events/:eventId/cancel` | Optional | Cancel registration |

**Rules (recommended)**

- One active registration per `uid` per event.
- If capacity enforced: transaction check capacity counter.

**Implementation notes**

- Use Firestore transaction:
  - If existing registration exists → return it (idempotent register).
  - Else create registration and mirror `users/{uid}/registrations/{eventId}`.

---

### 3.5 App-First Check-in (No QR scanning inside app)

| Endpoint | Auth | Description |
|----------|------|-------------|
| `POST /v1/events/:eventId/checkin/main` | Required | Main (event) check-in |
| `POST /v1/events/:eventId/checkin/sessions/:sessionId` | Required | Session check-in |
| `GET /v1/events/:eventId/checkin/status` | Required | Check-in status for user |

**Required behaviors**

1. **Idempotent**
   - Same user checking in multiple times must not double count.
   - Use deterministic `checkinId`:
     - Main: `main_${uid}`
     - Session: `session_${sessionId}_${uid}`

2. **Auto main check-in**
   - If session check-in is called and main is missing: create main check-in first (same transaction if desired).

3. **Optional: Require registration**
   - Either:
     - Require registration first (cleaner), or
     - “Auto-register on check-in” (more flexible).
   - Pick one and enforce in API only.

4. **Rate limiting**
   - Basic: per `uid` per event per minute.

---

## Phase 4 — Deep Link Landing (QR opens app)

Even if QR isn’t required, it’s useful for quick navigation.

### 4.1 Add a lightweight HTTP function (or Hosting rewrite)

**`GET /e/:eventId`**

Returns:

- If user agent supports universal links → let OS open app.
- Otherwise show fallback HTML:
  - “Open in App”
  - App Store / Play Store links
  - “Continue in browser” (optional)

**Implementation options**

- Firebase Hosting + rewrites to a Cloud Function.
- Or static HTML page with dynamic redirect logic.

---

## Phase 5 — Observability, Safety, and Backward Compatibility

### 5.1 Logging & audit fields

Every write should include:

- `createdAt` (server timestamp)
- `source`: `app` | `web` | `staff`
- `uid`

### 5.2 Backward compatibility

- Do **not** break existing Event Hub admin flows.
- Keep existing Firestore paths the same.
- If new paths are needed (e.g. `users/{uid}/registrations`), add them **in addition**.

### 5.3 Versioning discipline

- Freeze `/v1`.
- Future changes go to `/v2`.

---

## Phase 6 — QA Checklist (Conference-grade)

### Registration

- [ ] Duplicate register returns same record (idempotent).
- [ ] Capacity full returns clean error.
- [ ] Cancel then register works (if allowed).

### Check-in

- [ ] Main check-in twice doesn’t double count.
- [ ] Session check-in triggers main automatically (when main missing).
- [ ] Session check-in twice doesn’t double count.
- [ ] “Status” endpoint is accurate.

### Security

- [ ] No auth → blocked for check-in / register / my registrations.
- [ ] Event visibility respected.

### Load

- [ ] Burst test main check-in endpoint (e.g. simulate 1,000 taps).

---

## Deliverables

What you’ll have in the Event Hub repo:

1. A **`/v1` API** deployed in Cloud Functions.
2. **Structured codebase** (middleware / services / routes).
3. **Stable contract** for the Spiritual App.
4. **Deep link landing** endpoint for QR → app open.
5. **Idempotent and safe** check-in logic.
6. **Unit tests** for the API (Jest + Supertest, mocked Firebase): `functions/src/__tests__/api.test.ts`; run with `npm test` in `functions/`.

---

## Next step: Cursor-ready implementation prompt

A follow-up implementation prompt can:

- Create the folder structure.
- Add Express + middleware.
- Scaffold all routes.
- Include Firestore transaction logic templates for register / check-in / status.

So dev can paste it into Cursor and implement with fewer misses.
