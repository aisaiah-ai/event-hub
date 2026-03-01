# What data is available via the Events Hub API

Reference for consumers: which fields come from which endpoints.

| Item | Via API? | Where |
|------|----------|--------|
| Event description | Yes | `GET /v1/events/{eventId}` → `data.description` |
| Event address | Yes | `GET /v1/events/{eventId}` → `data.address` |
| Session description | Yes | `GET /v1/events/{eventId}/sessions` → each item has `description` |
| Session speaker name/title | Yes | Same sessions response → `speaker`, `speakerTitle` |
| Dedicated speakers (list/detail, bio, photo) | No | No speakers endpoints in the API |

**Note:** Dedicated speaker entities (list, detail page, bio, photo) would require new API endpoints and data model if needed in the future.
