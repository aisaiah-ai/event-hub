# Event Hub

A generic Event Hub platform in Flutter supporting dynamic registration schemas, event/session check-in, manual entry, CSV import, and formation signals.

**First deployment:** NLC (CFC National Leaders Conference)

## Features

- **Dynamic Registration Schema** – Define fields per event in Firestore, no code changes
- **Event & Session Check-in** – Event-level first, then session-level attendance
- **Manual Entry** – Walk-ins with admin/staff flows
- **CSV Import** – Map headers to schema, preview, import with ADMIN validation
- **Formation Signals** – Derived tags for AIsaiah consumption
- **Admin Schema Editor** – Add, edit, reorder fields; preview forms

## Setup

1. **Flutter**
   ```bash
   flutter pub get
   ```

2. **Firebase**
   ```bash
   flutterfire configure
   ```
   Creates `lib/firebase_options.dart` and configures iOS/Android/Web.

3. **Run**
   ```bash
   flutter run
   ```

## Routes

| Route | Purpose |
|-------|---------|
| `/` | Home (admin links) |
| `/admin/schema/registration` | Schema Editor |
| `/admin/registrants/new` | New registrant (walk-in) |
| `/admin/registrants/:id/edit` | Edit registrant |
| `/admin/import/registrants` | CSV import |
| `/admin/sessions/:sessionId/manual-checkin` | Manual session check-in |

Add `?eventId=xxx` to override default event.

## Schema Evolution

See [docs/README_SCHEMA_EVOLUTION.md](docs/README_SCHEMA_EVOLUTION.md).

## CI/CD

- **CI** (`.github/workflows/ci.yml`): Analyze, test, build Android/Web on push/PR
- **Deploy** (`.github/workflows/deploy.yml`): Build and deploy web to Firebase Hosting on `main`

Configure `FIREBASE_TOKEN` secret for deploy.

## Tests

```bash
flutter test
```
