# Seed Event: March Cluster Central B Assembly

## Fix "permission-denied" Error

If you see `cloud_firestore/permission-denied`, deploy the Firestore rules:

```bash
firebase deploy --only firestore
```

This deploys rules to all databases (default, event-hub-dev, event-hub-prod). The rules allow:
- **Public read** on `events` collection (for landing/RSVP pages)
- **Public create** on `events/{eventId}/rsvps` (for RSVP submissions)

In **debug mode**, the app uses fallback data when Firestore fails, so the RSVP page still loads. RSVP submission will fail until rules are deployed.

---

## Add Event Document

To use Firestore (and for production), add this document to your `events` collection.

## Firestore Document

**Database:** `(default)` (production uses the default Firestore database)  
**Collection:** `events`  
**Document ID:** `march-cluster-2026`

```json
{
  "slug": "march-cluster-2026",
  "name": "March Cluster Central B (BBS, Tampa, Port Charlotte) Assembly, Evangelization Rally & Fellowship night",
  "startDate": "2026-03-14T00:00:00.000Z",
  "endDate": "2026-03-14T00:00:00.000Z",
  "locationName": "St. Michael's Hall",
  "address": "Incarnation Catholic Church, 8220 W Hillsborough Ave, Tampa, FL 33615",
  "isActive": true,
  "allowRsvp": true,
  "allowCheckin": false,
  "metadata": {
    "rallyTime": "3:00 PM - 6:00 PM",
    "dinnerTime": "6:00 PM - 9:00 PM",
    "rsvpDeadline": "March 10"
  },
  "branding": {
    "logoUrl": "assets/checkin/IntheOne.svg",
    "backgroundPatternUrl": "assets/checkin/mossaic.svg",
    "organizationName": "Couples for Christ"
  }
}
```

## Note on Timestamps

Firestore expects `Timestamp` values. When adding via the Firebase Console, use the date picker or enter:
- **startDate:** March 14, 2026
- **endDate:** March 14, 2026

## Development Fallback

In debug mode, if this document does not exist, the app uses built-in fallback data so the RSVP page renders. RSVP submissions will still be written to `events/march-cluster-2026/rsvps` (Firestore creates the subcollection even if the parent doc is absent in some cases—ensure your rules allow it).

## QR Code URL

Use this URL for your poster QR code:

```
https://events.aisaiah.org/events/march-cluster-2026/rsvp?rsvpSource=poster
```

For local testing:

```
http://127.0.0.1:8080/events/march-cluster-2026/rsvp?rsvpSource=poster
```
