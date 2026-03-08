# Event Images API

Event Moments — photo gallery for events with approval workflow. Supports uploads from both the Flutter app and web (QR code flow).

## Approval Workflow

1. User uploads image → status set to **`pending`**
2. Admin reviews via `/images/review` endpoint
3. Admin approves or rejects via `PATCH` (single or bulk)
4. Only **`approved`** images appear in the public gallery

## Endpoints

### List Approved Images (public)

```
GET /v1/events/:eventId/images
```

Returns only images with `status: "approved"`.

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
        "status": "approved",
        "createdAt": "2026-03-08T12:00:00.000Z"
      }
    ],
    "hasMore": false
  }
}
```

### List My Uploads (auth required)

```
GET /v1/events/:eventId/images/mine
Authorization: Bearer <idToken>
```

Returns the authenticated user's uploads (any status: pending, approved, rejected).
Lets uploaders see their pending submissions.

### List All for Review (auth required, admin)

```
GET /v1/events/:eventId/images/review
Authorization: Bearer <idToken>
```

Returns all images regardless of status. For admin review dashboard.

**Query parameters:**
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `limit` | number | 20 | Max images to return (max 100) |
| `startAfter` | string | — | Image ID cursor for pagination |
| `status` | string | — | Filter by status: `pending`, `approved`, `rejected` |

### Get Single Image (public)

```
GET /v1/events/:eventId/images/:imageId
```

### Upload Image (auth required)

```
POST /v1/events/:eventId/images
Authorization: Bearer <idToken>
```

Uploaded images start with `status: "pending"` and must be approved before appearing in the public gallery.

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
    "status": "pending",
    "createdAt": "2026-03-08T12:00:00.000Z"
  }
}
```

### Approve / Reject Image (auth required, admin)

```
PATCH /v1/events/:eventId/images/:imageId
Authorization: Bearer <idToken>
Content-Type: application/json
```

**Body:**
```json
{
  "status": "approved"
}
```

Status must be `"approved"` or `"rejected"`.

### Bulk Approve / Reject (auth required, admin)

```
PATCH /v1/events/:eventId/images/bulk-status
Authorization: Bearer <idToken>
Content-Type: application/json
```

**Body:**
```json
{
  "status": "approved",
  "imageIds": ["abc123", "def456", "ghi789"]
}
```

Max 50 images per bulk operation.

**Response:**
```json
{
  "ok": true,
  "data": {
    "updated": 3
  }
}
```

### Delete Image (auth required)

```
DELETE /v1/events/:eventId/images/:imageId
Authorization: Bearer <idToken>
```

Regular users can only delete their own images. Deletes from both Storage and Firestore.

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
  status: "pending" | "approved" | "rejected",
  reviewedBy: string | null,    // Admin UID who approved/rejected
  reviewedAt: Timestamp | null, // When reviewed
  createdAt: Timestamp          // Server timestamp, ordered DESC
}
```

**Indexes required:**
- `status` + `createdAt` DESC — for public list (approved images)
- `uploadedBy` + `createdAt` DESC — for "my images" list

## Firebase Storage Structure

```
events/{eventId}/images/{imageId}.{ext}
```

Example: `events/march-assembly/images/abc123.jpg`

Files are made publicly readable via `makePublic()`. The URL is always accessible, but the gallery only shows approved images. This is acceptable since individual URLs are not discoverable.

## QR Code Web Upload Flow

1. Event page displays QR code linking to: `https://events.aisaiah.org/events/{eventId}/upload`
2. Web page authenticates user (Firebase Auth)
3. User selects photo → POST multipart to `/v1/events/:eventId/images`
4. Upload returns `status: "pending"` — user sees confirmation
5. Admin reviews and approves → photo appears in gallery

## Error Codes

| Status | Code | When |
|--------|------|------|
| 400 | `invalid_argument` | Missing file, file too large, wrong type, invalid status |
| 401 | `unauthenticated` | No/invalid auth token |
| 403 | `forbidden` | Deleting someone else's image |
| 404 | `not_found` | Event or image not found |
| 500 | `internal` | Storage/Firestore failure |
