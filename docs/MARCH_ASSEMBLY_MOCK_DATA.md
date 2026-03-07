# March Assembly — Mock Data (Test for National Youth Conference Portland)

Mock event data for **March Cluster Assembly** — same branding and schedule style as the flier, with sessions, PDF materials, and speaker profiles. Used to test the app before the larger National Youth Conference in Portland.

## What Gets Created

| Path | Description |
|------|--------------|
| `events/march-assembly` | Event doc: name, slug `march-cluster-2026`, venue, dates (March 14, 2026), **shortDescription**, **branding** (primary `#0E3A5D`, accent `#F4A340`, logo URL), metadata (rallyTime, dinnerTime **7:00 PM – 9:00 PM**, **rsvpDeadline: March 14**) |
| `events/march-assembly/sessions/{id}` | **main-checkin** (1:30 PM), **evangelization-rally** (3–6 PM), **dinner-fellowship** (7–9 PM, name "Birthdays & Anniversaries Celebration") — each with name, description, location, order, startAt, endAt, **speakerIds**, **materials** |
| `events/march-assembly/speakers/{id}` | **rommel-dolar** (Bro Rommel Dolar, House Hold Head), **mike-suela** (Bro. Mike Suela, Unit Head) — photoUrl: `assets/images/speakers/rommel_dolar.png`, `mike_suela.png` |
| `events/march-assembly/stats/overview` | Stats structure (zeros) for analytics |

## Branding (Matches Flier)

- **Primary:** `#0E3A5D` (EventTokens.primaryBlue)
- **Accent:** `#F4A340` (EventTokens.accentGold)
- **Mock logo:** placeholder image URL; replace with real asset when ready.
- **Organization:** Couples for Christ

## Schedule (Matches Actual Invite)

- **Main Check-In:** 1:30 PM
- **Evangelization Rally:** 3:00 – 6:00 PM — *A time of worship, inspiration, and renewal as we recommit ourselves to the call to evangelize.*
- **Birthdays & Anniversaries Celebration:** 7:00 PM – 9:00 PM — *Dinner, fellowship, and dancing as we celebrate milestones, relationships, and the joy of community life.*
- **Location:** St. Michael's Hall, Incarnation Catholic Church, Tampa, FL
- **RSVP by March 14** | rsvp.aisaiah.org

## Session Materials (PDFs)

- **Evangelization Rally:** Rally Program & Reflections, Small Group Discussion Guide, Worship Song Sheet (mock URLs).
- **Birthdays & Anniversaries Celebration:** Birthdays & Anniversaries Program, Fellowship Night Agenda (mock URLs).

Replace `https://example.com/march-assembly/...` with real PDF URLs (e.g. Firebase Storage or your CDN) when you have them.

## Speakers

- **Bro Rommel Dolar** — House Hold Head (Evangelization Rally); photoUrl: `assets/images/speakers/rommel_dolar.png`
- **Bro. Mike Suela** — Unit Head (Birthdays & Anniversaries Celebration); photoUrl: `assets/images/speakers/mike_suela.png`

Speaker assets live in `assets/images/speakers/`. The app uses the in-code fallback for March Cluster so these asset paths load correctly.

## How to Run the Seed

**Prerequisites:** `gcloud auth application-default login` (or `GOOGLE_APPLICATION_CREDENTIALS`).

From project root:

```bash
cd functions && node scripts/seed-march-assembly.js
```

To target a specific database:

```bash
cd functions && node scripts/seed-march-assembly.js "--database=(default)"
cd functions && node scripts/seed-march-assembly.js --database=event-hub-dev
cd functions && node scripts/seed-march-assembly.js --database=event-hub-prod
```

Use the same database the app uses (see `docs/JOURNAL.md` and `lib/src/config/firestore_config.dart` — often `(default)`).

**If the script fails with a Google auth error** (e.g. `invalid_grant`, `invalid_rapt`), it will print:
- Instructions to run `gcloud auth application-default login`
- Manual steps to add **shortDescription** in Firebase Console → Firestore → `events` → `march-assembly` so the event detail page still shows the short description.

## How the App Finds This Event

- **RSVP / landing:** `EventRepository.getEventBySlug('march-cluster-2026')` queries `events` where `slug == 'march-cluster-2026'`. The seeded document has `slug: 'march-cluster-2026'` and `id: 'march-assembly'`, so it is returned.
- **Fallback:** If Firestore is unavailable or the doc is missing, the app uses the in-code fallback `_marchCluster2026Fallback` (see `lib/src/features/events/data/event_repository.dart`).

## Firestore Rules

- **Speakers:** `events/{eventId}/speakers/{speakerId}` — `allow read: if true`; `allow write: if isStaff(eventId)`. Deploy rules after adding the speakers rule: `firebase deploy --only firestore:(default)` (and/or your named DB per `docs/.cursor/rules/firestore-rules-deploy.mdc`).

## Data Model Reference

- **Event:** See `EventModel.fromFirestore` in `lib/src/features/events/data/event_model.dart` (name, slug, startDate, endDate, locationName, address, **venue**, **shortDescription**, branding including **cardBackgroundColor**, **checkInButtonColor**, metadata). Optional **isRegistered**, **registrationStatus** for the Register button state.
- **Venue:** Optional structured `venue` (name, street, city, state, zip) for display and "Get Directions" (Google Maps). When absent, derived from locationName/address.
- **Sessions:** Standard session fields (name, title, **description**, location, order, startAt, endAt, isActive) plus **materials** array and **speakerIds**. Optional **sessionCheckedIn** (bool) for "Checked In ✓" on the schedule card.
- **Speakers:** Subcollection `events/{eventId}/speakers/{id}`; fields: name, title, bio, photoUrl, order. Linked to sessions via `session.speakerIds`. March Cluster uses in-code fallback (Bro Rommel Dolar, Bro. Mike Suela) so asset photo paths work.
