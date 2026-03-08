# Event Images API

Event Moments — photo gallery for events. Supports uploads from both the Flutter app and web (QR code flow).

## Endpoints

### List Images (public)

```
GET /v1/events/:eventId/images
```

**Query parameters:**
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `limit` | number | 20 | Max images to return (max 100) |
| `startAfter` | string | — | Image ID cursor for pagination |

**Response:**
```json
{
  "ok": true,
  "data": {
    "images": [
      {
        "id": "abc123",
        "eventId": "march-assembly",
        "url": "https://storage.googleapis.com/...",
        "thumbnailUrl": null,
        "uploadedBy": "uid123",
        "uploaderName": "Hope Dajao",
        "createdAt": "2026-03-08T12:00:00.000Z"
      }
    ],
    "hasMore": false
  }
}
```

### Get Single Image (public)

```
GET /v1/events/:eventId/images/:imageId
```

### Upload Image (auth required)

```
POST /v1/events/:eventId/images
Authorization: Bearer <idToken>
```

**Option A — Multipart form data (web/QR uploads):**
```
Content-Type: multipart/form-data
Field: "image" (file)
```

**Option B — JSON with base64 (app uploads):**
```json
{
  "image": "<base64-encoded-image>",
  "mimetype": "image/jpeg",
  "filename": "photo.jpg"
}
```

**Constraints:**
- Max file size: 10 MB
- Allowed types: `image/jpeg`, `image/png`, `image/webp`, `image/heic`, `image/heif`

**Response (201):**
```json
{
  "ok": true,
  "data": {
    "id": "abc123",
    "eventId": "march-assembly",
    "url": "https://storage.googleapis.com/...",
    "uploadedBy": "uid123",
    "uploaderName": "Hope Dajao",
    "createdAt": "2026-03-08T12:00:00.000Z"
  }
}
```

### Delete Image (auth required, owner only)

```
DELETE /v1/events/:eventId/images/:imageId
Authorization: Bearer <idToken>
```

Only the uploader can delete their own images.

## Firestore Data Model

**Collection:** `events/{eventId}/images/{imageId}`

```
{
  eventId: string,
  url: string,                  // Public Firebase Storage URL
  storagePath: string,          // Internal path for deletion
  uploadedBy: string,           // User UID
  uploaderName: string | null,  // Display name
  mimetype: string,             // e.g. "image/jpeg"
  sizeBytes: number,
  createdAt: Timestamp          // Server timestamp, ordered DESC
}
```

## Firebase Storage Structure

```
events/{eventId}/images/{imageId}.{ext}
```

Example: `events/march-assembly/images/abc123.jpg`

Files are made publicly readable via `makePublic()`.

## QR Code Web Upload Flow

1. Event page displays QR code linking to: `https://events.aisaiah.org/events/{eventId}/upload`
2. Web page authenticates user (Firebase Auth)
3. User selects photo → POST multipart to `/v1/events/:eventId/images`
4. Photo appears in gallery for all users

## Error Codes

| Status | Code | When |
|--------|------|------|
| 400 | `invalid_argument` | Missing file, file too large, wrong type |
| 401 | `unauthenticated` | No/invalid auth token |
| 403 | `forbidden` | Deleting someone else's image |
| 404 | `not_found` | Event or image not found |
| 500 | `internal` | Storage/Firestore failure |
