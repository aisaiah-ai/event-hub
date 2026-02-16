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
   flutter run -d chrome
   ```
   In dev, the app opens at `/events/nlc/checkin`. If direct URLs (e.g. `/events/nlc/checkin`) return 404, use the root URL `http://localhost:PORT/` or run `./tools/serve_web.sh` after building.

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

## Routing

The app uses **path-based URLs** (no hash):

- `https://events.aisaiah.org/events/march-cluster-2026/rsvp`
- Old hash URLs (`#/events/...`) redirect to clean paths for backward compatibility.

Requires SPA rewrites: `web/_redirects` and `firebase.json` serve all paths to `index.html`.

## CI/CD

- **CI** (`.github/workflows/ci.yml`): Analyze, test, build Android/Web on push/PR
- **Deploy** (`.github/workflows/deploy.yml`): Build and deploy web to Cloudflare Pages on `main`

Configure `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` secrets.

## Tests

```bash
flutter test
```
