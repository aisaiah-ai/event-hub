# Firestore Database Names (Permanent)

**Do not change these.** The Event Hub project uses named Firestore databases:

| Environment | Database ID |
|-------------|-------------|
| DEV | `event-hub-dev` |
| PROD | `event-hub-prod` |

## Rules

- **Never use** the `(default)` database for Event Hub data
- All code, config, and docs must reference `event-hub-dev` and `event-hub-prod`
- `FirestoreConfig` (`lib/src/config/firestore_config.dart`) maps `AppEnvironment.dev` → `event-hub-dev`, `AppEnvironment.prod` → `event-hub-prod`

## No GCP service accounts

- Deploy uses Cloudflare (no Firebase/GCP service accounts)
- Firestore seed (dev → prod) runs locally with `gcloud auth login` — no service account keys

## References

- `firebase.json` — Firestore rules/indexes for these databases
- `lib/src/config/firestore_config.dart` — `databaseId` getter
- `.cursor/rules/firestore-databases.mdc` — Cursor rule enforcing this
