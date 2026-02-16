# Analytics Stats Backfill

The stats document (`events/{eventId}/stats/overview`) is created automatically when:
- The first registrant is created (onRegistrantCreate)
- The first check-in occurs (onRegistrantCheckIn transaction merges)

For events with **existing registrants** before Cloud Functions were deployed, run the backfill.

## Callable: backfillStats

**Endpoint:** `backfillStats`
**Auth:** Required (any authenticated user; restrict to admins in production)
**Payload:** `{ "eventId": "nlc-2026" }`

Creates the stats doc with zeroed counters. Does **not** recompute from existing registrants.

### From Flutter (admin screen)

```dart
final result = await FirebaseFunctions.instance.httpsCallable('backfillStats').call({
  'eventId': eventId,
});
```

### From curl (requires Firebase Auth token)

```bash
# Get ID token first, then:
curl -X POST "https://us-central1-YOUR_PROJECT.cloudfunctions.net/backfillStats" \
  -H "Authorization: Bearer YOUR_ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"data":{"eventId":"nlc-2026"}}'
```

## Full backfill (count from existing data)

For a complete recompute from existing registrants, use a one-off script with Admin SDK:

1. Query all registrants for the event
2. Compute totalRegistrations, earlyBirdCount, firstEarlyBird*
3. For each checked-in registrant, compute region/ministry/service counts, sessionTotals
4. Write to stats/overview in a single transaction

This is not included; implement as needed for migration.
