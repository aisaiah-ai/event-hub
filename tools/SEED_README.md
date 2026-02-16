# NLC Registrants Seed

Seeds NLC registrants from Excel/CSV to the Firebase **dev** database (`event-hub-dev`). All PII (names, email, phone, address, etc.) is **hashed** before storage.

## Supported formats

- `.csv`
- `.xlsx`
- `.xls` (Excel 97-2003; if parsing fails, export to CSV or XLSX in Excel)

## Usage

### Option 1: Environment variable

```bash
SEED_FILE="/path/to/2-5-2026-2026_NLC (1).xlsx" flutter run -t lib/seed_main.dart -d macos --dart-define=ENV=dev
```

### Option 2: Input file

```bash
echo "/path/to/your/file.xlsx" > tools/seed_input.txt
flutter run -t lib/seed_main.dart -d macos --dart-define=ENV=dev
```

### Option 3: Sample CSV (for testing)

```bash
SEED_FILE="tools/sample_nlc_registrants.csv" flutter run -t lib/seed_main.dart -d macos --dart-define=ENV=dev
```

### Option 4: No hashing (for local testing – search will work)

```bash
SEED_FILE="/path/to/file.csv" SEED_NO_HASH=1 flutter run -t lib/seed_main.dart -d macos --dart-define=ENV=dev
```

## If seed fails with permission-denied

The seed runs unauthenticated but uses App Check (Debug Provider) to verify the app identity.
If you see `permission-denied` errors:

1. **Check for App Check Debug Token:**
   - Look in the console output for a debug token (e.g., `Enter this debug secret into the allow list in the Firebase Console: ...`).
   - Add this token to your project's **App Check** settings in the Firebase Console.
   
   *Note: The token usually persists across runs. If you see the same token, you only need to add it once.*

2. **Check Firestore Rules:**
   - If App Check is configured but writes still fail, check if Firestore rules allow unauthenticated writes or if the database is in strict mode.

**Note on "LevelDB Lock" errors:**
The seed script automatically disables persistence to avoid conflicts with the running main app. You can safe run the seed script while the app is running on macOS.

If the seed still fails, add registrants manually:

1. See **docs/MANUAL_SEED_REGISTRANTS.md** for step-by-step instructions.
2. Ensure **event-hub-dev** database exists in Firebase Console.
3. Deploy dev rules: `./scripts/deploy-firestore-dev.sh`

## Column mapping

Common columns are auto-mapped:

| Spreadsheet column | Registrant field |
|--------------------|------------------|
| firstName, first_name | profile.firstName |
| lastName, last_name | profile.lastName |
| email | profile.email |
| cfcId, cfc_id | profile.cfcId |
| phone, mobile | profile.phone |
| chapter, unit, affiliation | profile.unit |
| role | answers.role |

## PII hashing

By default, these fields are hashed (SHA256, first 16 chars) before storage:

- firstName, lastName, name, fullName
- email, phone, mobile
- address, city, state, zip, country
- chapter, unit, affiliation

Use `SEED_NO_HASH=1` to skip hashing (for local testing; enables search by name/email).

## Target

- **Database:** `event-hub-dev`
- **Collection:** `events/nlc-2026/registrants`

Ensure the `nlc-2026` event exists in Firestore and has `metadata.selfCheckinEnabled: true` for check-in to work.
