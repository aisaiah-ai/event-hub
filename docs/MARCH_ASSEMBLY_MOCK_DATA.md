# March Assembly — Mock Data (Test for National Youth Conference Portland)

Mock event data for **March Cluster Assembly** — same branding and schedule style as the flier, with sessions, PDF materials, and speaker profiles. Used to test the app before the larger National Youth Conference in Portland.

## What Gets Created

| Path | Description |
|------|--------------|
| `events/march-assembly` | Event doc: name, slug `march-cluster-2026`, venue, dates (March 14, 2026), **branding** (primary `#0E3A5D`, accent `#F4A340`, mock logo URL), metadata (rallyTime, dinnerTime, **rsvpDeadline: March 7**) |
| `events/march-assembly/sessions/{id}` | **main-checkin**, **evangelization-rally**, **birthdays-anniversaries** — each with name, description, location, order, startAt, endAt, **materials** (array of `{ title, url, type: 'pdf' }`) |
| `events/march-assembly/speakers/{id}` | Mock speakers: name, title, bio, **photoUrl** (placeholder), order |
| `events/march-assembly/stats/overview` | Stats structure (zeros) for analytics |

## Branding (Matches Flier)

- **Primary:** `#0E3A5D` (EventTokens.primaryBlue)
- **Accent:** `#F4A340` (EventTokens.accentGold)
- **Mock logo:** placeholder image URL; replace with real asset when ready.
- **Organization:** Couples for Christ

## Schedule (Matches Actual Invite)

- **Evangelization Rally:** 3:00 – 6:00 PM — *A time of worship, inspiration, and renewal as we recommit ourselves to the call to evangelize.*
- **Birthdays & Anniversaries Celebration:** 6:00 PM – 9:00 PM — *Dinner, fellowship, and dancing as we celebrate milestones, relationships, and the joy of community life.*
- **Location:** St. Michael's Hall, Incarnation Catholic Church, Tampa, FL
- **RSVP by March 7** | rsvp.aisaiah.org

## Session Materials (PDFs)

- **Evangelization Rally:** Rally Program & Reflections, Small Group Discussion Guide, Worship Song Sheet (mock URLs).
- **Birthdays & Anniversaries Celebration:** Birthdays & Anniversaries Program, Fellowship Night Agenda (mock URLs).

Replace `https://example.com/march-assembly/...` with real PDF URLs (e.g. Firebase Storage or your CDN) when you have them.

## Mock Speakers

- **Maria Santos** — Guest Speaker, Evangelization Rally
- **Fr. James Rivera** — Spiritual Director
- **David & Lisa Chen** — Fellowship Night Hosts

Each has a placeholder **photoUrl** (e.g. `https://placehold.co/300x300/0E3A5D/F4A340?text=MS`). Replace with real profile images when ready.

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

## How the App Finds This Event

- **RSVP / landing:** `EventRepository.getEventBySlug('march-cluster-2026')` queries `events` where `slug == 'march-cluster-2026'`. The seeded document has `slug: 'march-cluster-2026'` and `id: 'march-assembly'`, so it is returned.
- **Fallback:** If Firestore is unavailable or the doc is missing, the app uses the in-code fallback `_marchCluster2026Fallback` (see `lib/src/features/events/data/event_repository.dart`).

## Firestore Rules

- **Speakers:** `events/{eventId}/speakers/{speakerId}` — `allow read: if true`; `allow write: if isStaff(eventId)`. Deploy rules after adding the speakers rule: `firebase deploy --only firestore:(default)` (and/or your named DB per `docs/.cursor/rules/firestore-rules-deploy.mdc`).

## Data Model Reference

- **Event:** See `EventModel.fromFirestore` in `lib/src/features/events/data/event_model.dart` (name, slug, startDate, endDate, locationName, address, branding, metadata).
- **Sessions:** Standard session fields (name, title, **description**, location, order, startAt, endAt, isActive) plus **materials** array and **speakerIds** (array of speaker doc IDs) to show speaker profile(s) on each session card.
- **Speakers:** Custom subcollection; fields used: name, title, bio, photoUrl, order. Linked to sessions via `session.speakerIds`.
