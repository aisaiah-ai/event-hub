# Events Hub API v1 — Confluence

*Confluence-ready markdown for the Spiritual App / Events Hub HTTP API.*

---

## Overview

| Item | Description |
|------|--------------|
| **Base URL** | `https://<region>-<project>.cloudfunctions.net/api` |
| **Version** | `/v1` |
| **Auth** | Firebase ID token: `Authorization: Bearer <idToken>` |
| **Response** | Success: `{ "ok": true, "data": ... }` · Error: `{ "ok": false, "error": { "code": "...", "message": "..." } }` |

---

## Endpoints Summary

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/v1/events` | No | List events (optional: from, to, chapter, region) |
| GET | `/v1/events/{eventId}` | No | Get event by ID |
| GET | `/v1/events/{eventId}/sessions` | No | List sessions (schedule) |
| GET | `/v1/events/{eventId}/schedule` | No | Alias for sessions |
| GET | `/v1/events/{eventId}/announcements` | No | List announcements (pinned first) |
| POST | `/v1/events/{eventId}/register` | Yes | Register for event (idempotent) |
| GET | `/v1/me/registrations` | Yes | My registrations across events |
| GET | `/v1/events/{eventId}/my-registration` | Yes | My registration for this event |
| POST | `/v1/events/{eventId}/checkin/main` | Yes | Main (event) check-in |
| POST | `/v1/events/{eventId}/checkin/sessions/{sessionId}` | Yes | Session check-in |
| GET | `/v1/events/{eventId}/checkin/status` | Yes | Check-in status for current user |

---

## Public Endpoints (no auth)

### GET /v1/events

List events. Query parameters: `from`, `to`, `chapter`, `region` (all optional).

**Response:** `{ "ok": true, "data": [ { "id", "title", "chapter", "region", "startAt", "endAt", "venue", "visibility" }, ... ] }`

---

### GET /v1/events/{eventId}

Get a single event. Returns 404 if not found or private.

**Response:** `{ "ok": true, "data": { "id", "title", "chapter", "region", "startAt", "endAt", "venue", "visibility", "registrationSettings" } }`

---

### GET /v1/events/{eventId}/sessions

List sessions for the event, ordered by start time.

**Response:** `{ "ok": true, "data": [ { "id", "title", "startAt", "endAt", "room", "capacity", "tags" }, ... ] }`

---

### GET /v1/events/{eventId}/announcements

List announcements. Pinned first, then by newest.

**Response:** `{ "ok": true, "data": [ { "id", "title", "body", "pinned", "priority", "createdAt" }, ... ] }`

---

## Member Endpoints (auth required)

All member endpoints require header: **Authorization: Bearer &lt;Firebase ID token&gt;**. Missing or invalid token returns **401** with `error.code: "unauthenticated"`.

---

### POST /v1/events/{eventId}/register

Register the current user for the event. One registration per user per event; duplicate calls return the existing registration (idempotent). Returns **409** with `capacity_exceeded` if event is at capacity.

**Response (201):** `{ "ok": true, "data": { "eventId", "registrationId", "status": "registered", "createdAt", "eventStartAt", "profile": { "name", "email" } } }`

---

### GET /v1/me/registrations

List the current user’s registrations across all events.

**Response:** `{ "ok": true, "data": [ { "eventId", "registrationId", "status", "createdAt", "eventStartAt", "profile" }, ... ] }`

---

### GET /v1/events/{eventId}/my-registration

Get the current user’s registration for this event. Returns **404** if not registered.

**Response:** `{ "ok": true, "data": { "eventId", "registrationId", "status", "createdAt", "eventStartAt", "profile" } }`

---

### POST /v1/events/{eventId}/checkin/main

Main (event-level) check-in. Idempotent; repeated calls do not double-count.

**Response (201):** `{ "ok": true, "data": { "already": true | false } }`

---

### POST /v1/events/{eventId}/checkin/sessions/{sessionId}

Session check-in. If main check-in is missing, it is created automatically. Idempotent. Rate-limited per user per event.

**Response (201):** `{ "ok": true, "data": { "mainCreated": true | false, "already": true | false } }`

---

### GET /v1/events/{eventId}/checkin/status

Get the current user’s check-in status for this event.

**Response:** `{ "ok": true, "data": { "eventId", "mainCheckedIn", "mainCheckedInAt", "sessionIds": [ ... ] } }`

---

## Error Codes

| HTTP | code | When |
|------|------|------|
| 400 | invalid_argument | Missing or invalid parameter |
| 401 | unauthenticated | Missing or invalid token |
| 403 | forbidden | Not allowed |
| 404 | not_found | Event/session/registration not found |
| 409 | conflict | Business rule conflict |
| 409 | capacity_exceeded | Event at capacity |
| 429 | rate_limited | Too many check-in requests |
| 500 | internal | Server error |

---

## Deep Link

**GET** `/e/{eventId}` (separate Cloud Function) — QR / deep-link landing. Returns HTML with “Continue in browser” or redirects; user-agent can open app when supported.

---

*Last updated from Events Hub repo API v1 implementation.*
