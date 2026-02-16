# Manual Seed: Add NLC Registrants via Firebase Console

If the seed script fails with permission-denied, add registrants manually in Firebase Console.

## Steps

1. Open [Firebase Console](https://console.firebase.google.com/project/aisaiah-event-hub/firestore)
2. Select database: **event-hub-dev** (dropdown at top; create it if missing)
3. Create path: `events` → `nlc-2026` → `registrants`
4. Add documents with these IDs and fields:

### Document 1
- **Document ID:** `john-doe-cfc001` (or auto-generate)
- **Fields:**
  - `profile` (map): `firstName`: "John", `lastName`: "Doe", `email`: "john.doe@example.com", `cfcId`: "CFC001", `phone`: "555-1234", `unit`: "Tampa", `role`: "Leader"
  - `answers` (map): same as profile
  - `source` (string): "import"
  - `registrationStatus` (string): "registered"
  - `eventAttendance` (map): `checkedIn`: false
  - `flags` (map): `isWalkIn`: false, `hasValidationWarnings`: false
  - `createdAt`, `updatedAt`, `registeredAt`: (timestamp) now

### Document 2
- **Document ID:** `jane-smith-cfc002`
- **Fields:** Same structure, `firstName`: "Jane", `lastName`: "Smith", `email`: "jane.smith@example.com", `cfcId`: "CFC002", `phone`: "555-5678", `unit`: "Orlando", `role`: "Member"

### Document 3
- **Document ID:** `bob-johnson-cfc003`
- **Fields:** Same structure, `firstName`: "Bob", `lastName`: "Johnson", `email`: "bob.j@example.com", `cfcId`: "CFC003", `unit`: "Port Charlotte", `role`: "Couple"

## Verify event-hub-dev Exists

If you don't see **event-hub-dev** in the database dropdown:
1. Firestore → Create database
2. Database ID: **event-hub-dev**
3. Location: same as project (e.g. us-central1)
4. Deploy rules: `./scripts/deploy-firestore-dev.sh`

## Check Which Database the App Uses

The app uses `event-hub-dev` when `ENV=dev`. Verify in Firebase Console → Firestore → select **event-hub-dev** from the dropdown.
