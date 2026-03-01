# Events Hub API v1

HTTP API for the Spiritual App: events, RSVP, check-in (main + session), schedule, and announcements. Served by Firebase Cloud Functions.

## Base URL

```
https://<region>-<project>.cloudfunctions.net/api
```

Example: `https://us-central1-aisaiah-event-hub.cloudfunctions.net/api`

## Versioning

All stable endpoints live under **`/v1`**. The root path `GET /` returns a short discovery JSON with endpoint hints.

## Authentication

- **Public:** `GET /v1/events`, `GET /v1/events/:eventId`, `GET /v1/events/:eventId/sessions`, `GET /v1/events/:eventId/announcements`
- **Member (auth required):** Register, my registrations, check-in. Send a Firebase ID token:

  ```
  Authorization: Bearer <idToken>
  ```

  Obtain the token from the Firebase Auth SDK in the client (e.g. `user.getIdToken()`).

## Response format

- **Success:** `{ "ok": true, "data": <payload> }`
- **Error:** `{ "ok": false, "error": { "code": "<code>", "message": "<message>" } }`

## Data availability

Which fields (event description, address, session description, speaker, etc.) come from which endpoints: [DATA_VIA_API.md](./DATA_VIA_API.md).

## Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/v1/events` | No | List events (query: from, to, chapter, region) |
| GET | `/v1/events/:eventId` | No | Get event |
| GET | `/v1/events/:eventId/sessions` | No | List sessions |
| GET | `/v1/events/:eventId/schedule` | No | Alias for sessions |
| GET | `/v1/events/:eventId/announcements` | No | List announcements |
| POST | `/v1/events/:eventId/register` | Yes | Register for event |
| GET | `/v1/me/registrations` | Yes | My registrations |
| GET | `/v1/events/:eventId/my-registration` | Yes | My registration for event |
| POST | `/v1/events/:eventId/checkin/main` | Yes | Main check-in |
| POST | `/v1/events/:eventId/checkin/sessions/:sessionId` | Yes | Session check-in |
| GET | `/v1/events/:eventId/checkin/status` | Yes | Check-in status |

## Error codes

| code | HTTP | Meaning |
|------|------|--------|
| unauthenticated | 401 | Missing or invalid token |
| forbidden | 403 | Not allowed |
| not_found | 404 | Resource not found |
| invalid_argument | 400 | Bad request |
| conflict | 409 | Conflict |
| capacity_exceeded | 409 | Event at capacity |
| rate_limited | 429 | Too many requests |
| internal | 500 | Server error |

## Deep link

**GET** `/e/:eventId` is a separate HTTP function for QR / deep links. It returns a simple HTML page with “Continue in browser” or can redirect; the app can be opened when the user-agent supports it.

## OpenAPI

An OpenAPI (Swagger) spec is available: [openapi.yaml](./openapi.yaml). Use it in Swagger UI, Postman, or code generators.

## Repo

- Implementation: `functions/src/api/`
- Plan: [API_SERVICE_IMPLEMENTATION_PLAN.md](../API_SERVICE_IMPLEMENTATION_PLAN.md)
- Confluence-style doc: [API_V1_CONFLUENCE.md](./API_V1_CONFLUENCE.md)
- Architecture: [ARCHITECTURE.md](./ARCHITECTURE.md)
