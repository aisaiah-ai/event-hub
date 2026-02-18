# Seed Data and Cleanup Scripts

Copy-paste commands for **event-hub-dev** (or `(default)` if your app uses that). For prod, use `--database=event-hub-prod` where noted; **never** run delete/seed-attendance on prod without review.

**Prereq:** `gcloud auth application-default login` (and `cd functions && npm install` if needed).

If you see **`invalid_grant`** or **`reauth related error (invalid_rapt)`** when running a script, your Application Default Credentials have expired or need re-auth (common with Google Workspace). Run:

```bash
gcloud auth application-default login
```

If that still fails, try:

```bash
gcloud auth login
gcloud auth application-default login
```

---

## 1. Clean up (dev only)

### Delete all seeded attendance (keeps event, sessions, registrants)

```bash
cd functions && node scripts/delete-seed-attendance-dev.js --database=event-hub-dev --dev
```

For default database:

```bash
cd functions && node scripts/delete-seed-attendance-dev.js "--database=(default)" --dev
```

### Delete obsolete session documents only (optional)

Removes old session docs: `opening-plenary`, `leadership-session-1`, `mass`, `closing`. Use if you only want `main-checkin` (and dialogue sessions).

```bash
cd functions && node scripts/delete-extra-sessions.js --database=event-hub-dev
```

For default database:

```bash
cd functions && node scripts/delete-extra-sessions.js "--database=(default)"
```

---

## 2. Bootstrap event + sessions + stats (required before app works)

Creates `events/nlc-2026`, `events/nlc-2026/sessions/main-checkin`, and `events/nlc-2026/stats/overview`. Safe to run multiple times (merge).

**Dev database (event-hub-dev):**

```bash
cd functions && node scripts/ensure-nlc-event-doc.js
```

**Default database:**

```bash
cd functions && node scripts/ensure-nlc-event-doc.js "--database=(default)"
```

**Prod (use with care):**

```bash
cd functions && node scripts/ensure-nlc-event-doc.js --database=event-hub-prod
```

---

## 3. Seed data

### 3a. Seed registrants (Flutter — dev)

Writes to **event-hub-dev**, collection `events/nlc-2026/registrants`. PII is hashed unless `SEED_NO_HASH=1`.

```bash
SEED_FILE="tools/sample_nlc_registrants.csv" flutter run -t lib/seed_main.dart -d macos --dart-define=ENV=dev
```

With your own file:

```bash
SEED_FILE="/path/to/registrants.xlsx" flutter run -t lib/seed_main.dart -d macos --dart-define=ENV=dev
```

No hashing (for local search testing):

```bash
SEED_FILE="/path/to/file.csv" SEED_NO_HASH=1 flutter run -t lib/seed_main.dart -d macos --dart-define=ENV=dev
```

See **tools/SEED_README.md** for column mapping and permission tips.

### 3b. Seed attendance (Node — dev only)

Seeds check-ins for dashboard/chart testing. **Requires registrants to exist.** Run after 3a.

```bash
cd functions && node scripts/seed-attendance-dev.js --database=event-hub-dev --dev
```

For default database:

```bash
cd functions && node scripts/seed-attendance-dev.js "--database=(default)" --dev
```

### 3b-alt. Live demo: simulate manual check-ins (dashboard updates in real time)

**Purpose:** Run this script while the dashboard is open; it writes check-ins one-by-one over a short window (default 2 minutes) with a gradually increasing rate so you can **demo live updates**. Max 90% of participants; each write triggers Cloud Functions so stats and dashboard update as it runs. No backfill needed.

1. Open the NLC dashboard in your browser (e.g. `/admin/dashboard?eventId=nlc-2026`).
2. In a terminal, run:

```bash
cd functions && node scripts/seed-gradual-checkins-dev.js --database=event-hub-dev --dev
```

Options (all optional):

- `--duration=120` — demo length in seconds (default 120 = 2 min)
- `--max-pct=0.9` — max fraction of registrants to check in (default 90%)
- `--power=2` — ramp curve (higher = more gradual start, more check-ins toward the end)

Example: 1-minute demo, 80% of registrants:

```bash
cd functions && node scripts/seed-gradual-checkins-dev.js --database=event-hub-dev --dev --duration=60 --max-pct=0.8
```

### 3c. Backfill analytics after seeding attendance

Updates `stats/overview` and hourly aggregates so the dashboard shows correct numbers.

```bash
cd functions && node scripts/backfill-analytics-dev.js --database=event-hub-dev --dev
```

For default database:

```bash
cd functions && node scripts/backfill-analytics-dev.js "--database=(default)" --dev
```

---

## Typical “clean + reseed” flow (dev)

```bash
# 1. Clean attendance only (optional; keeps registrants)
cd functions && node scripts/delete-seed-attendance-dev.js --database=event-hub-dev --dev

# 2. Ensure event/sessions/stats exist
cd functions && node scripts/ensure-nlc-event-doc.js --database=event-hub-dev

# 3. Seed registrants (if needed)
SEED_FILE="tools/sample_nlc_registrants.csv" flutter run -t lib/seed_main.dart -d macos --dart-define=ENV=dev

# 4. Seed attendance
cd functions && node scripts/seed-attendance-dev.js --database=event-hub-dev --dev

# 5. Backfill analytics
cd functions && node scripts/backfill-analytics-dev.js --database=event-hub-dev --dev
```

Replace `--database=event-hub-dev` with `"--database=(default)"` if your app uses the default Firestore database.
